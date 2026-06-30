import { Response } from "express";
import { AuthenticatedRequest } from "../types";

// GET /medicines
export async function listMedicines(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: return all medicines for req.familyId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /medicines/preview-doses
// Returns generated dose list without saving — used for the review screen.
export async function previewDoses(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { quantity, schedule } = req.body as {
    quantity: number;
    schedule: unknown;
  };

  if (!quantity || !schedule) {
    res
      .status(400)
      .json({ success: false, error: "quantity and schedule are required" });
    return;
  }

  // TODO: run dose generation algorithm and return preview list
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /medicines
export async function createMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { name, deviceId, quantity, schedule } = req.body as {
    name: string;
    deviceId: string;
    quantity: number;
    schedule: unknown;
  };

  if (!name || !deviceId || !quantity || !schedule) {
    res.status(400).json({
      success: false,
      error: "name, deviceId, quantity, and schedule are required",
    });
    return;
  }

  // TODO: create medicine, schedule, and generate doses
  res.status(501).json({ success: false, error: "Not implemented" });
}

// GET /medicines/:id
export async function getMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: return medicine detail with schedule and dose summary
  res.status(501).json({ success: false, error: "Not implemented" });
}

// PATCH /medicines/:id
export async function updateMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { name, quantity, status, deviceId } = req.body as {
    name?: string;
    quantity?: number;
    status?: string;
    deviceId?: string;
  };

  // TODO: update medicine fields, verify family ownership
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /medicines/:id/reschedule-preview
// Returns future doses that would be generated after a schedule change.
export async function reschedulePreview(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: compute new future doses without writing them
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /medicines/:id/reschedule
// Replaces future pending doses with newly generated ones.
export async function reschedule(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { quantity, schedule } = req.body as {
    quantity?: number;
    schedule?: unknown;
  };

  // TODO: delete future pending doses, generate new ones, preserve history
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /medicines/:id
export async function deleteMedicine(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: soft-delete or archive medicine, retain historical dose logs
  res.status(501).json({ success: false, error: "Not implemented" });
}
