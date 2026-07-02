import { Op, Transaction } from "sequelize";
import { Dose } from "../db/models/Dose";
import { DoseLog } from "../db/models/DoseLog";
import { DoseStatus, DoseLogEventType, TakenSource } from "../types";

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
    data: Partial<
      Pick<Dose, "status" | "actualTakenAt" | "takenSource">
    >,
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
};
