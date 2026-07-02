import { Op, Transaction, fn, col } from "sequelize";
import { Medicine } from "../db/models/Medicine";
import { Schedule, ScheduleConfig } from "../db/models/Schedule";
import { Dose } from "../db/models/Dose";
import { FrequencyType } from "../types";
import { GeneratedDose } from "../services/dose.generator";

export const medicineRepository = {
  findById(id: string) {
    return Medicine.findByPk(id);
  },

  findByFamily(familyId: string) {
    return Medicine.findAll({
      where: { familyId, status: { [Op.ne]: "deleted" } },
      order: [["createdAt", "ASC"]],
    });
  },

  // Earliest upcoming pending dose per medicine — the "next dose" shown in the UI.
  getNextDosesForMedicines(medicineIds: string[], now: Date) {
    if (medicineIds.length === 0) return Promise.resolve([]);
    return Dose.findAll({
      where: { medicineId: { [Op.in]: medicineIds }, status: "pending", scheduledAt: { [Op.gt]: now } },
      order: [["scheduledAt", "ASC"]],
    });
  },

  getNextDose(medicineId: string, now: Date) {
    return Dose.findOne({
      where: { medicineId, status: "pending", scheduledAt: { [Op.gt]: now } },
      order: [["scheduledAt", "ASC"]],
    });
  },

  async getDoseStatusCounts(medicineId: string): Promise<Record<string, number>> {
    const rows = (await Dose.findAll({
      where: { medicineId },
      attributes: ["status", [fn("COUNT", col("id")), "count"]],
      group: ["status"],
      raw: true,
    })) as unknown as { status: string; count: string }[];
    return rows.reduce<Record<string, number>>((acc, r) => {
      acc[r.status] = Number(r.count);
      return acc;
    }, {});
  },

  async updateMedicine(
    id: string,
    data: Partial<Pick<Medicine, "name" | "status" | "deviceId" | "totalQuantity" | "remainingQuantity">>,
    transaction?: Transaction
  ) {
    const [, rows] = await Medicine.update(data, { where: { id }, returning: true, transaction });
    return rows[0] ?? null;
  },

  getActiveSchedule(medicineId: string, transaction?: Transaction) {
    return Schedule.findOne({ where: { medicineId, status: "active" }, transaction });
  },

  supersedeSchedule(scheduleId: string, transaction?: Transaction) {
    return Schedule.update({ status: "superseded" }, { where: { id: scheduleId }, transaction });
  },

  // Replaceable doses on a reschedule: pending and still in the future.
  deleteFuturePendingDoses(medicineId: string, now: Date, transaction?: Transaction) {
    return Dose.destroy({
      where: { medicineId, status: "pending", scheduledAt: { [Op.gt]: now } },
      transaction,
    });
  },

  // Pending doses scheduled after `now` — the ones that "reserve" future pills.
  countPendingFutureDoses(scheduleId: string, now: Date, transaction?: Transaction) {
    return Dose.count({
      where: { scheduleId, status: "pending", scheduledAt: { [Op.gt]: now } },
      transaction,
    });
  },

  // Latest dose overall (any status) — anchor for chaining appended doses.
  getLatestDose(scheduleId: string, transaction?: Transaction) {
    return Dose.findOne({
      where: { scheduleId },
      order: [["scheduledAt", "DESC"]],
      transaction,
    });
  },

  // Ids of the `limit` latest pending future doses — the tail we trim on decrease.
  async getLatestPendingFutureDoseIds(
    scheduleId: string,
    now: Date,
    limit: number,
    transaction?: Transaction
  ): Promise<string[]> {
    if (limit <= 0) return [];
    const doses = await Dose.findAll({
      where: { scheduleId, status: "pending", scheduledAt: { [Op.gt]: now } },
      order: [["scheduledAt", "DESC"]],
      limit,
      attributes: ["id"],
      transaction,
    });
    return doses.map((d) => d.id);
  },

  deleteDosesByIds(ids: string[], transaction?: Transaction) {
    if (ids.length === 0) return Promise.resolve(0);
    return Dose.destroy({ where: { id: { [Op.in]: ids } }, transaction });
  },

  createMedicine(
    data: {
      familyId: string;
      deviceId: string | null;
      name: string;
      totalQuantity: number;
      pillPerDose: number;
      remainingQuantity: number;
    },
    transaction?: Transaction
  ) {
    return Medicine.create(data, { transaction });
  },

  createSchedule(
    data: {
      medicineId: string;
      frequencyType: FrequencyType;
      scheduleConfig: ScheduleConfig;
      graceBeforeMinutes: number;
      graceAfterMinutes: number;
      startAt: Date;
      endAt: Date | null;
    },
    transaction?: Transaction
  ) {
    return Schedule.create(data, { transaction });
  },

  bulkCreateDoses(
    scheduleId: string,
    medicineId: string,
    doses: GeneratedDose[],
    transaction?: Transaction
  ) {
    if (doses.length === 0) return Promise.resolve([]);
    return Dose.bulkCreate(
      doses.map((d) => ({
        scheduleId,
        medicineId,
        scheduledAt: d.scheduledAt,
        windowStartAt: d.windowStartAt,
        windowEndAt: d.windowEndAt,
        doseAmount: d.doseAmount,
      })),
      { transaction }
    );
  },
};
