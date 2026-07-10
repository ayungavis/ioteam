import { Op, Transaction } from "sequelize";
import { Dose } from "../db/models/Dose";
import { DoseLog } from "../db/models/DoseLog";
import { Medicine } from "../db/models/Medicine";
import { DeviceEvent } from "../db/models/DeviceEvent";
import { DoseStatus, DoseLogEventType } from "../types";
import { matchOpenEvents } from "../services/dose-window";

// Doses joined to their medicine (family + device).
type DoseWithMedicine = Dose & {
  medicine?: { id: string; name: string; familyId: string; deviceId: string | null };
};

export const doseRepository = {
  // All doses for a medicine, chronological, optionally filtered by status.
  findByMedicine(medicineId: string, statuses?: DoseStatus[]) {
    const where: { medicineId: string; status?: { [Op.in]: DoseStatus[] } } = {
      medicineId,
    };
    if (statuses && statuses.length > 0) {
      where.status = { [Op.in]: statuses };
    }
    return Dose.findAll({ where, order: [["scheduledAt", "ASC"]] });
  },

  findById(id: string) {
    return Dose.findByPk(id);
  },

  async update(
    id: string,
    data: Partial<Pick<Dose, "status" | "actualTakenAt" | "takenSource">>,
    transaction?: Transaction
  ) {
    const [, rows] = await Dose.update(data, {
      where: { id },
      returning: true,
      transaction,
    });
    return rows[0] ?? null;
  },

  createLog(
    data: {
      doseId: string;
      userId: string | null;
      eventType: DoseLogEventType;
      source: "device_event" | "manual" | "system";
      metadata?: object | null;
    },
    transaction?: Transaction
  ) {
    return DoseLog.create(data, { transaction });
  },

  // ─── Lifecycle sweeps (dose scheduler cron) ─────────────────────────────────
  // State-based dose lifecycle sweeps. Every query is idempotent: it only touches
  // rows still in the source state, so a late/skipped/duplicated tick self-heals
  // and never double-processes a dose. Each returns the ids it transitioned.

  // pending -> due: grace window is open right now.
  async transitionDue(now: Date): Promise<string[]> {
    const [, rows] = await Dose.update(
      { status: "due" },
      {
        where: {
          status: "pending",
          windowStartAt: { [Op.lte]: now },
          windowEndAt: { [Op.gte]: now },
        },
        returning: ["id"],
      }
    );
    return rows.map((r) => r.id);
  },

  // pending|due -> missed: grace window closed and nobody confirmed. Includes
  // `pending` because a dose whose whole window falls between two ticks never
  // passes through `due`. `needs_confirmation` is deliberately excluded — an
  // opened box waits for a human, no timeout.
  async transitionMissed(now: Date): Promise<string[]> {
    const [, rows] = await Dose.update(
      { status: "missed" },
      {
        where: {
          status: { [Op.in]: ["pending", "due"] },
          windowEndAt: { [Op.lt]: now },
        },
        returning: ["id"],
      }
    );
    return rows.map((r) => r.id);
  },

  // pending|due -> needs_confirmation: the medicine's device reported an `open`
  // event inside the dose window (ambiguous — box opened, but taken? refill?).
  //
  // `ingestDeviceEvent` now does this instantly via `correlateOpenEvent`; this is the
  // polling backstop for events that landed while the push path was down. It cannot
  // double-notify: the status guard below matches zero rows once ingest has run.
  async transitionNeedsConfirmation(now: Date): Promise<string[]> {
    const candidates = (await Dose.findAll({
      where: {
        status: { [Op.in]: ["pending", "due"] },
        windowStartAt: { [Op.lte]: now },
      },
      include: [{ model: Medicine, as: "medicine", attributes: ["id", "deviceId"] }],
    })) as DoseWithMedicine[];

    const withDevice = candidates.filter((d) => d.medicine?.deviceId);
    if (withDevice.length === 0) return [];

    const deviceIds = [...new Set(withDevice.map((d) => d.medicine!.deviceId as string))];
    const earliestWindow = withDevice.reduce(
      (min, d) => (d.windowStartAt < min ? d.windowStartAt : min),
      withDevice[0].windowStartAt
    );

    const openEvents = await DeviceEvent.findAll({
      where: {
        deviceId: { [Op.in]: deviceIds },
        eventType: "open",
        deviceTimestamp: { [Op.gte]: earliestWindow, [Op.lte]: now },
      },
      attributes: ["deviceId", "deviceTimestamp"],
    });

    const matchedIds = matchOpenEvents(
      withDevice.map((d) => ({
        id: d.id,
        deviceId: d.medicine!.deviceId,
        windowStartAt: d.windowStartAt,
        windowEndAt: d.windowEndAt,
      })),
      openEvents.map((e) => ({ deviceId: e.deviceId, deviceTimestamp: e.deviceTimestamp }))
    );

    if (matchedIds.length === 0) return [];

    const [, rows] = await Dose.update(
      { status: "needs_confirmation" },
      {
        where: { id: { [Op.in]: matchedIds }, status: { [Op.in]: ["pending", "due"] } },
        returning: ["id"],
      }
    );
    return rows.map((r) => r.id);
  },

  // ─── Event-driven correlation (device event ingest) ─────────────────────────
  // A single `open` event from one device, correlated against that device's dose
  // windows. The instant path for what `transitionNeedsConfirmation` does on a timer.
  //
  // `insideWindow` separates "no dose scheduled right now" from "a dose is already
  // awaiting confirmation" — the caller must not raise a box-opened alert for the
  // latter. It is true whenever the event lands in any dose window, regardless of
  // whether anything transitioned.
  //
  // ponytail: `at` is the device's clock, matching the sweep backstop. Both share
  // the same clock-skew ceiling; move both to `server_received_at` together.
  async correlateOpenEvent(
    deviceId: string,
    at: Date
  ): Promise<{ insideWindow: boolean; transitionedIds: string[] }> {
    const none = { insideWindow: false, transitionedIds: [] };

    const medicines = await Medicine.findAll({
      where: { deviceId },
      attributes: ["id"],
    });
    if (medicines.length === 0) return none;

    const inWindow = await Dose.findAll({
      where: {
        medicineId: { [Op.in]: medicines.map((m) => m.id) },
        windowStartAt: { [Op.lte]: at },
        windowEndAt: { [Op.gte]: at },
      },
      attributes: ["id", "status"],
    });
    if (inWindow.length === 0) return none;

    const candidateIds = inWindow
      .filter((d) => d.status === "pending" || d.status === "due")
      .map((d) => d.id);
    if (candidateIds.length === 0) return { insideWindow: true, transitionedIds: [] };

    // Re-assert the status guard in the UPDATE: the sweep may have raced us here.
    const [, rows] = await Dose.update(
      { status: "needs_confirmation" },
      {
        where: { id: { [Op.in]: candidateIds }, status: { [Op.in]: ["pending", "due"] } },
        returning: ["id"],
      }
    );
    return { insideWindow: true, transitionedIds: rows.map((r) => r.id) };
  },

  // Doses joined to their medicine (family + device) — recipients for a notification.
  findByIdsWithMedicine(ids: string[]): Promise<DoseWithMedicine[]> {
    if (ids.length === 0) return Promise.resolve([]);
    return Dose.findAll({
      where: { id: { [Op.in]: ids } },
      include: [
        { model: Medicine, as: "medicine", attributes: ["id", "name", "familyId", "deviceId"] },
      ],
    }) as Promise<DoseWithMedicine[]>;
  },

  // Audit trail for auto-missed doses (schema intent: source 'system').
  logMissed(doseIds: string[]): Promise<DoseLog[]> {
    if (doseIds.length === 0) return Promise.resolve([]);
    return DoseLog.bulkCreate(
      doseIds.map((doseId) => ({
        doseId,
        userId: null,
        eventType: "missed" as const,
        source: "system" as const,
      }))
    );
  },
};

export type { DoseWithMedicine };
