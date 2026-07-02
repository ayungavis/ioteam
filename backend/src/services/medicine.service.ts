import { sequelize } from "../db";
import { medicineRepository } from "../repositories/medicine.repository";
import { familyRepository } from "../repositories/family.repository";
import { deviceRepository } from "../repositories/device.repository";
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
} from "../errors/AppError";
import { FrequencyType } from "../types";
import { ScheduleConfig } from "../db/models/Schedule";
import { generateDoses, GeneratedDose } from "./dose.generator";

// Shape the frontend sends for a schedule (in both preview and create).
export interface ScheduleInput {
  frequencyType: FrequencyType;
  scheduleConfig: ScheduleConfig;
  timezone: string;
  graceBeforeMinutes?: number;
  graceAfterMinutes?: number;
  startAt: string;
  endAt?: string | null;
}

interface NormalizedSchedule {
  frequencyType: FrequencyType;
  scheduleConfig: ScheduleConfig;
  timezone: string;
  graceBeforeMinutes: number;
  graceAfterMinutes: number;
  startAt: Date;
  endAt: Date | null;
}

// A timezone is valid if Intl accepts it as an IANA identifier.
function isValidTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

function isValidTimes(times: unknown): times is string[] {
  return (
    Array.isArray(times) &&
    times.length > 0 &&
    times.every((t) => typeof t === "string" && HHMM.test(t))
  );
}

// Validate and coerce the raw schedule payload into typed, defaulted values.
function normalizeSchedule(schedule: ScheduleInput): NormalizedSchedule {
  if (!schedule || typeof schedule !== "object") {
    throw new BadRequestError("schedule is required");
  }
  const { frequencyType, scheduleConfig } = schedule;
  if (!scheduleConfig || typeof scheduleConfig !== "object") {
    throw new BadRequestError("scheduleConfig is required");
  }

  if (!schedule.timezone || typeof schedule.timezone !== "string") {
    throw new BadRequestError("timezone is required (IANA name, e.g. Asia/Singapore)");
  }
  if (!isValidTimeZone(schedule.timezone)) {
    throw new BadRequestError(`Invalid timezone: ${schedule.timezone}`);
  }

  if (!["daily", "weekly", "hourly"].includes(frequencyType)) {
    throw new BadRequestError("frequencyType must be daily, weekly, or hourly");
  }

  if (frequencyType === "daily") {
    if (
      !isValidTimes((scheduleConfig as { timesOfDay?: unknown }).timesOfDay)
    ) {
      throw new BadRequestError(
        "daily schedule requires timesOfDay as an array of HH:MM strings",
      );
    }
  } else if (frequencyType === "weekly") {
    const weekdays = (scheduleConfig as { weekdays?: unknown }).weekdays;
    if (
      !Array.isArray(weekdays) ||
      weekdays.length === 0 ||
      !weekdays.every((d) => Number.isInteger(d) && d >= 0 && d <= 6)
    ) {
      throw new BadRequestError(
        "weekly schedule requires weekdays as an array of integers 0-6",
      );
    }
    if (
      !isValidTimes((scheduleConfig as { timesOfDay?: unknown }).timesOfDay)
    ) {
      throw new BadRequestError(
        "weekly schedule requires timesOfDay as an array of HH:MM strings",
      );
    }
  } else {
    const intervalHours = (scheduleConfig as { intervalHours?: unknown })
      .intervalHours;
    if (typeof intervalHours !== "number" || intervalHours <= 0) {
      throw new BadRequestError(
        "hourly schedule requires a positive intervalHours",
      );
    }
  }

  const startAt = new Date(schedule.startAt);
  if (Number.isNaN(startAt.getTime()))
    throw new BadRequestError("startAt is not a valid date");

  let endAt: Date | null = null;
  if (schedule.endAt) {
    endAt = new Date(schedule.endAt);
    if (Number.isNaN(endAt.getTime()))
      throw new BadRequestError("endAt is not a valid date");
    if (endAt <= startAt)
      throw new BadRequestError("endAt must be later than startAt");
  }

  const graceBeforeMinutes = schedule.graceBeforeMinutes ?? 0;
  const graceAfterMinutes = schedule.graceAfterMinutes ?? 30;
  if (graceBeforeMinutes < 0 || graceAfterMinutes < 0) {
    throw new BadRequestError("grace minutes cannot be negative");
  }

  return {
    frequencyType,
    scheduleConfig,
    timezone: schedule.timezone,
    graceBeforeMinutes,
    graceAfterMinutes,
    startAt,
    endAt,
  };
}

function assertQuantity(quantity: unknown, pillPerDose: number): number {
  if (
    typeof quantity !== "number" ||
    !Number.isInteger(quantity) ||
    quantity <= 0
  ) {
    throw new BadRequestError("quantity must be a positive integer");
  }
  if (pillPerDose <= 0 || !Number.isInteger(pillPerDose)) {
    throw new BadRequestError("pillPerDose must be a positive integer");
  }
  return quantity;
}

async function requireFamilyId(userId: string): Promise<string> {
  const membership = await familyRepository.getMembershipByUserId(userId);
  if (!membership)
    throw new ForbiddenError("You are not a member of any family");
  return membership.familyId;
}

async function requireDeviceInFamily(
  deviceId: string,
  familyId: string,
): Promise<void> {
  const device = await deviceRepository.findById(deviceId);
  if (!device || device.status === "deleted")
    throw new NotFoundError("Device not found");
  if (device.familyId !== familyId)
    throw new ForbiddenError("Device does not belong to your family");
}

// Load a medicine and assert it belongs to the caller's family.
async function requireOwnedMedicine(userId: string, medicineId: string) {
  const familyId = await requireFamilyId(userId);
  const medicine = await medicineRepository.findById(medicineId);
  if (!medicine || medicine.status === "deleted")
    throw new NotFoundError("Medicine not found");
  if (medicine.familyId !== familyId)
    throw new ForbiddenError("Medicine does not belong to your family");
  return medicine;
}

function summarize(doses: GeneratedDose[]) {
  return {
    totalDoses: doses.length,
    firstDoseAt: doses[0]?.scheduledAt ?? null,
    lastDoseAt: doses[doses.length - 1]?.scheduledAt ?? null,
    pillsUsed: doses.reduce((sum, d) => sum + d.doseAmount, 0),
  };
}

export const medicineService = {
  // GET /medicines — list the family's medicines with linked device and next dose time.
  async listMedicines(userId: string) {
    const familyId = await requireFamilyId(userId);
    const medicines = await medicineRepository.findByFamily(familyId);
    const now = new Date();

    const devices = await deviceRepository.findByFamily(familyId);
    const deviceMap = new Map(devices.map((d) => [d.id, d]));

    const nextDoses = await medicineRepository.getNextDosesForMedicines(
      medicines.map((m) => m.id),
      now,
    );
    const nextDoseByMedicine = new Map<string, Date>();
    for (const dose of nextDoses) {
      if (!nextDoseByMedicine.has(dose.medicineId)) {
        nextDoseByMedicine.set(dose.medicineId, dose.scheduledAt);
      }
    }

    return medicines.map((m) => {
      const device = m.deviceId ? deviceMap.get(m.deviceId) : null;
      return {
        id: m.id,
        name: m.name,
        status: m.status,
        totalQuantity: m.totalQuantity,
        remainingQuantity: m.remainingQuantity,
        pillPerDose: m.pillPerDose,
        device: device ? { id: device.id, name: device.name, status: device.status } : null,
        nextDoseAt: nextDoseByMedicine.get(m.id) ?? null,
      };
    });
  },

  // GET /medicines/:id — full detail: device, active schedule, dose counts, next dose.
  async getMedicine(userId: string, medicineId: string) {
    const medicine = await requireOwnedMedicine(userId, medicineId);
    const now = new Date();

    const device = medicine.deviceId
      ? await deviceRepository.findById(medicine.deviceId)
      : null;
    const schedule = await medicineRepository.getActiveSchedule(medicine.id);
    const doseCounts = await medicineRepository.getDoseStatusCounts(medicine.id);
    const nextDose = await medicineRepository.getNextDose(medicine.id, now);

    return {
      id: medicine.id,
      name: medicine.name,
      status: medicine.status,
      totalQuantity: medicine.totalQuantity,
      remainingQuantity: medicine.remainingQuantity,
      pillPerDose: medicine.pillPerDose,
      device: device ? { id: device.id, name: device.name, status: device.status } : null,
      schedule: schedule
        ? {
            id: schedule.id,
            frequencyType: schedule.frequencyType,
            scheduleConfig: schedule.scheduleConfig,
            timezone: schedule.timezone,
            graceBeforeMinutes: schedule.graceBeforeMinutes,
            graceAfterMinutes: schedule.graceAfterMinutes,
            startAt: schedule.startAt,
            endAt: schedule.endAt,
            status: schedule.status,
          }
        : null,
      doseCounts,
      nextDoseAt: nextDose?.scheduledAt ?? null,
    };
  },

  // DELETE /medicines/:id — soft-delete; supersede the schedule and drop future
  // pending doses, but keep historical doses/logs intact (DOSE-009).
  async deleteMedicine(userId: string, medicineId: string) {
    const medicine = await requireOwnedMedicine(userId, medicineId);
    const now = new Date();

    return sequelize.transaction(async (tx) => {
      const active = await medicineRepository.getActiveSchedule(medicine.id, tx);
      if (active) await medicineRepository.supersedeSchedule(active.id, tx);

      const dosesRemoved = await medicineRepository.deleteFuturePendingDoses(
        medicine.id,
        now,
        tx,
      );
      await medicineRepository.updateMedicine(medicine.id, { status: "deleted" }, tx);

      return { dosesRemoved };
    });
  },

  // POST /medicines/preview-doses — generate the dose list without persisting.
  async previewDoses(
    userId: string,
    input: { quantity: number; pillPerDose?: number; schedule: ScheduleInput },
  ) {
    await requireFamilyId(userId);

    const pillPerDose = input.pillPerDose ?? 1;
    const quantity = assertQuantity(input.quantity, pillPerDose);
    const schedule = normalizeSchedule(input.schedule);

    const doses = generateDoses({
      ...schedule,
      pillPerDose,
      availablePills: quantity, // fresh medicine: nothing reserved yet
    });

    return { doses, summary: summarize(doses) };
  },

  // PATCH /medicines/:id — update metadata and/or adjust quantity by a signed delta.
  //   adjustQuantity > 0 (refill): append new doses chaining from the last dose.
  //   adjustQuantity < 0 (correction): trim pending future doses from the tail.
  // Schedule structure is never touched here — that lives in /reschedule.
  async updateMedicine(
    userId: string,
    medicineId: string,
    input: {
      name?: string;
      status?: "active" | "disabled";
      deviceId?: string;
      adjustQuantity?: number;
    },
  ) {
    const familyId = await requireFamilyId(userId);

    const medicine = await medicineRepository.findById(medicineId);
    if (!medicine || medicine.status === "deleted")
      throw new NotFoundError("Medicine not found");
    if (medicine.familyId !== familyId)
      throw new ForbiddenError("Medicine does not belong to your family");

    // Validate input
    const hasAdjust =
      typeof input.adjustQuantity === "number" && input.adjustQuantity !== 0;
    if (!input.name && !input.status && !input.deviceId && !hasAdjust) {
      throw new BadRequestError("Provide at least one field to update");
    }
    if (
      input.status &&
      input.status !== "active" &&
      input.status !== "disabled"
    ) {
      throw new BadRequestError("status must be active or disabled");
    }
    if (
      typeof input.adjustQuantity === "number" &&
      !Number.isInteger(input.adjustQuantity)
    ) {
      throw new BadRequestError("adjustQuantity must be an integer");
    }
    if (input.deviceId) await requireDeviceInFamily(input.deviceId, familyId);

    const result = await sequelize.transaction(async (tx) => {
      const fields: Parameters<typeof medicineRepository.updateMedicine>[1] =
        {};
      if (input.name) fields.name = input.name;
      if (input.status) fields.status = input.status;
      if (input.deviceId) fields.deviceId = input.deviceId;

      let dosesAdded = 0;
      let dosesRemoved = 0;

      if (hasAdjust) {
        const delta = input.adjustQuantity as number;
        const now = new Date();
        const schedule = await medicineRepository.getActiveSchedule(
          medicine.id,
        );

        const newRemaining = Math.max(0, medicine.remainingQuantity + delta);
        fields.remainingQuantity = newRemaining;
        // totalQuantity tracks lifetime pills loaded — only grows on refill.
        if (delta > 0) fields.totalQuantity = medicine.totalQuantity + delta;

        // Only reconcile doses when there is an active schedule to generate against.
        if (schedule) {
          const pendingFutureCount =
            await medicineRepository.countPendingFutureDoses(
              schedule.id,
              now,
              tx,
            );
          const reserved = pendingFutureCount * medicine.pillPerDose;

          if (delta > 0) {
            // Refill: materialize doses for pills not yet reserved by pending doses.
            const availablePills = newRemaining - reserved;
            const latest = await medicineRepository.getLatestDose(
              schedule.id,
              tx,
            );
            const generated = generateDoses({
              frequencyType: schedule.frequencyType,
              scheduleConfig: schedule.scheduleConfig,
              timezone: schedule.timezone,
              startAt: schedule.startAt,
              endAt: schedule.endAt,
              graceBeforeMinutes: schedule.graceBeforeMinutes,
              graceAfterMinutes: schedule.graceAfterMinutes,
              pillPerDose: medicine.pillPerDose,
              availablePills,
              lastDoseAt: latest?.scheduledAt ?? null,
            });
            await medicineRepository.bulkCreateDoses(
              schedule.id,
              medicine.id,
              generated,
              tx,
            );
            dosesAdded = generated.length;
          } else {
            // Correction downward: trim latest pending future doses until reserved <= remaining.
            const keepCount = Math.floor(newRemaining / medicine.pillPerDose);
            const numToDelete = Math.max(0, pendingFutureCount - keepCount);
            const ids = await medicineRepository.getLatestPendingFutureDoseIds(
              schedule.id,
              now,
              numToDelete,
              tx,
            );
            await medicineRepository.deleteDosesByIds(ids, tx);
            dosesRemoved = ids.length;
          }
        }
      }

      const updated = await medicineRepository.updateMedicine(
        medicine.id,
        fields,
        tx,
      );
      return { medicine: updated ?? medicine, dosesAdded, dosesRemoved };
    });

    return result;
  },

  // POST /medicines/:id/reschedule-preview — future doses a schedule change would
  // produce, without writing anything. Uses remaining quantity as the pill budget.
  async reschedulePreview(
    userId: string,
    medicineId: string,
    input: { schedule: ScheduleInput },
  ) {
    const medicine = await requireOwnedMedicine(userId, medicineId);
    const schedule = normalizeSchedule(input.schedule);

    const doses = generateDoses({
      ...schedule,
      pillPerDose: medicine.pillPerDose,
      availablePills: medicine.remainingQuantity,
      notBefore: new Date(),
    });

    return { doses, summary: summarize(doses) };
  },

  // POST /medicines/:id/reschedule — supersede the active schedule, delete future
  // pending doses, and regenerate future doses under a new schedule. History is kept.
  async reschedule(
    userId: string,
    medicineId: string,
    input: { schedule: ScheduleInput },
  ) {
    const medicine = await requireOwnedMedicine(userId, medicineId);
    const schedule = normalizeSchedule(input.schedule);
    const now = new Date();

    const generated = generateDoses({
      ...schedule,
      pillPerDose: medicine.pillPerDose,
      availablePills: medicine.remainingQuantity,
      notBefore: now,
    });

    const result = await sequelize.transaction(async (tx) => {
      const oldActive = await medicineRepository.getActiveSchedule(medicine.id, tx);
      if (oldActive) await medicineRepository.supersedeSchedule(oldActive.id, tx);

      const dosesRemoved = await medicineRepository.deleteFuturePendingDoses(
        medicine.id,
        now,
        tx,
      );

      const newSchedule = await medicineRepository.createSchedule(
        {
          medicineId: medicine.id,
          frequencyType: schedule.frequencyType,
          scheduleConfig: schedule.scheduleConfig,
          timezone: schedule.timezone,
          graceBeforeMinutes: schedule.graceBeforeMinutes,
          graceAfterMinutes: schedule.graceAfterMinutes,
          startAt: schedule.startAt,
          endAt: schedule.endAt,
        },
        tx,
      );

      const doses = await medicineRepository.bulkCreateDoses(
        newSchedule.id,
        medicine.id,
        generated,
        tx,
      );

      return { schedule: newSchedule, doses, dosesRemoved, dosesCreated: doses.length };
    });

    return { ...result, summary: summarize(generated) };
  },

  // POST /medicines — create medicine + schedule + generated doses in one transaction.
  async createMedicine(
    userId: string,
    input: {
      name: string;
      deviceId: string;
      quantity: number;
      pillPerDose?: number;
      schedule: ScheduleInput;
    },
  ) {
    if (!input.name) throw new BadRequestError("name is required");
    if (!input.deviceId) throw new BadRequestError("deviceId is required");

    const familyId = await requireFamilyId(userId);
    await requireDeviceInFamily(input.deviceId, familyId);

    const pillPerDose = input.pillPerDose ?? 1;
    const quantity = assertQuantity(input.quantity, pillPerDose);
    const schedule = normalizeSchedule(input.schedule);

    const generated = generateDoses({
      ...schedule,
      pillPerDose,
      availablePills: quantity,
    });

    const result = await sequelize.transaction(async (tx) => {
      const medicine = await medicineRepository.createMedicine(
        {
          familyId,
          deviceId: input.deviceId,
          name: input.name,
          totalQuantity: quantity,
          pillPerDose,
          remainingQuantity: quantity,
        },
        tx,
      );

      const createdSchedule = await medicineRepository.createSchedule(
        {
          medicineId: medicine.id,
          frequencyType: schedule.frequencyType,
          scheduleConfig: schedule.scheduleConfig,
          timezone: schedule.timezone,
          graceBeforeMinutes: schedule.graceBeforeMinutes,
          graceAfterMinutes: schedule.graceAfterMinutes,
          startAt: schedule.startAt,
          endAt: schedule.endAt,
        },
        tx,
      );

      const doses = await medicineRepository.bulkCreateDoses(
        createdSchedule.id,
        medicine.id,
        generated,
        tx,
      );

      return { medicine, schedule: createdSchedule, doses };
    });

    return { ...result, summary: summarize(generated) };
  },
};
