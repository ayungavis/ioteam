import { Response } from "express";
import { AuthenticatedRequest } from "../types";
import { doseSchedulerService } from "../services/dose-scheduler.service";

export async function triggerDoseTick(
  _req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  console.log("[scheduler] manual tick triggered via API");
  await doseSchedulerService.runTick();
  res.json({ success: true, message: "Dose scheduler tick completed." });
}
