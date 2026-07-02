import { sequelize } from "../db";
import { doseRepository } from "../repositories/dose.repository";
import { medicineRepository } from "../repositories/medicine.repository";
import { familyRepository } from "../repositories/family.repository";
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from "../errors/AppError";
import { DoseStatus } from "../types";

const VALID_STATUSES: DoseStatus[] = [
  "pending",
  "due",
  "taken",
  "missed",
  "skipped",
  "needs_confirmation",
  "disabled",
];

// Load a medicine and assert it belongs to the caller's family.
async function requireOwnedMedicine(userId: string, medicineId: string) {
  const membership = await familyRepository.getMembershipByUserId(userId);
  if (!membership) throw new ForbiddenError("You are not a member of any family");

  const medicine = await medicineRepository.findById(medicineId);
  if (!medicine || medicine.status === "deleted")
    throw new NotFoundError("Medicine not found");
  if (medicine.familyId !== membership.familyId)
    throw new ForbiddenError("Medicine does not belong to your family");
  return medicine;
}

// Load a dose and the medicine it belongs to, asserting family ownership.
async function requireOwnedDose(userId: string, doseId: string) {
  const dose = await doseRepository.findById(doseId);
  if (!dose) throw new NotFoundError("Dose not found");
  const medicine = await requireOwnedMedicine(userId, dose.medicineId);
  return { dose, medicine };
}

export const doseService = {
  // GET /medicines/:id/doses — chronological doses for a medicine, optionally
  // filtered by one or more comma-separated statuses (e.g. "pending,due").
  async listDoses(userId: string, medicineId: string, statusParam?: string) {
    await requireOwnedMedicine(userId, medicineId);

    let statuses: DoseStatus[] | undefined;
    if (statusParam) {
      const requested = statusParam
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      const invalid = requested.filter(
        (s) => !VALID_STATUSES.includes(s as DoseStatus)
      );
      if (invalid.length > 0) {
        throw new BadRequestError(`Invalid dose status: ${invalid.join(", ")}`);
      }
      statuses = requested as DoseStatus[];
    }

    return doseRepository.findByMedicine(medicineId, statuses);
  },

  // POST /doses/:id/mark-taken — manually confirm a dose was taken.
  // Sets the dose taken, decrements the medicine's remaining quantity, and logs it.
  async markTaken(userId: string, doseId: string) {
    const { dose, medicine } = await requireOwnedDose(userId, doseId);

    if (dose.status === "taken") {
      throw new ConflictError("Dose is already marked as taken");
    }
    if (dose.status === "disabled") {
      throw new BadRequestError("Cannot mark a disabled dose as taken");
    }

    const now = new Date();
    const previousStatus = dose.status;
    const newRemaining = Math.max(0, medicine.remainingQuantity - dose.doseAmount);

    const result = await sequelize.transaction(async (tx) => {
      const updatedDose = await doseRepository.update(
        dose.id,
        { status: "taken", actualTakenAt: now, takenSource: "manual" },
        tx
      );

      await medicineRepository.updateMedicine(
        medicine.id,
        { remainingQuantity: newRemaining },
        tx
      );

      await doseRepository.createLog(
        {
          doseId: dose.id,
          userId,
          eventType: "taken",
          source: "manual",
          metadata: { previousStatus },
        },
        tx
      );

      return updatedDose ?? dose;
    });

    return { dose: result, remainingQuantity: newRemaining };
  },
};
