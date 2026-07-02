import { Response } from "express";
import { AuthenticatedRequest } from "../types";
import { medicineService, ScheduleInput } from "../services/medicine.service";

// GET /medicines
export async function listMedicines(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const medicines = await medicineService.listMedicines(req.userId);
  res.json({ success: true, data: medicines });
}

// POST /medicines/preview-doses
// Returns generated dose list without saving — used for the review screen.
export async function previewDoses(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { quantity, pillPerDose, schedule } = req.body as {
    quantity: number;
    pillPerDose?: number;
    schedule: ScheduleInput;
  };

  const result = await medicineService.previewDoses(req.userId, {
    quantity,
    pillPerDose,
    schedule,
  });

  res.json({ success: true, data: result });
}

// POST /medicines
export async function createMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { name, deviceId, quantity, pillPerDose, schedule } = req.body as {
    name: string;
    deviceId: string;
    quantity: number;
    pillPerDose?: number;
    schedule: ScheduleInput;
  };

  const result = await medicineService.createMedicine(req.userId, {
    name,
    deviceId,
    quantity,
    pillPerDose,
    schedule,
  });

  res.status(201).json({ success: true, data: result });
}

// GET /medicines/:id
export async function getMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const medicine = await medicineService.getMedicine(req.userId, id);
  res.json({ success: true, data: medicine });
}

// PATCH /medicines/:id
// Updates metadata (name/status/device) and/or adjusts quantity by a signed delta.
export async function updateMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const { name, status, deviceId, adjustQuantity } = req.body as {
    name?: string;
    status?: "active" | "disabled";
    deviceId?: string;
    adjustQuantity?: number;
  };

  const result = await medicineService.updateMedicine(req.userId, id, {
    name,
    status,
    deviceId,
    adjustQuantity,
  });

  res.json({ success: true, data: result });
}

// POST /medicines/:id/reschedule-preview
// Returns future doses that would be generated after a schedule change.
export async function reschedulePreview(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const { schedule } = req.body as { schedule: ScheduleInput };

  const result = await medicineService.reschedulePreview(req.userId, id, {
    schedule,
  });

  res.json({ success: true, data: result });
}

// POST /medicines/:id/reschedule
// Replaces future pending doses with newly generated ones.
export async function reschedule(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const { schedule } = req.body as { schedule: ScheduleInput };

  const result = await medicineService.reschedule(req.userId, id, { schedule });

  res.json({ success: true, data: result });
}

// DELETE /medicines/:id
export async function deleteMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const result = await medicineService.deleteMedicine(req.userId, id);
  res.json({ success: true, data: result });
}
