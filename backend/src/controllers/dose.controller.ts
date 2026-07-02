import { Response } from "express";
import { AuthenticatedRequest } from "../types";
import { doseService } from "../services/dose.service";

// GET /medicines/:id/doses
export async function listDoses(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const statusRaw = req.query.status;
  const status = typeof statusRaw === "string" ? statusRaw : undefined;

  const doses = await doseService.listDoses(req.userId, id, status);
  res.json({ success: true, data: doses });
}

// POST /doses/:id/mark-taken
export async function markTaken(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params as { id: string };
  const result = await doseService.markTaken(req.userId, id);
  res.json({ success: true, data: result });
}

// POST /doses/:id/mark-skipped
export async function markSkipped(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: mark dose as skipped, log the action
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /doses/:id/confirm
// Resolves a dose in needs_confirmation state after an ambiguous device event.
export async function confirmDose(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { confirmed } = req.body as { confirmed: boolean };

  if (confirmed === undefined) {
    res.status(400).json({ success: false, error: "confirmed field is required" });
    return;
  }

  // TODO: if confirmed=true mark taken, if false mark missed or leave for retry
  res.status(501).json({ success: false, error: "Not implemented" });
}
