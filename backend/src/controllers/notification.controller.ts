import { Response } from "express";
import { AuthenticatedRequest } from "../types";
import { pushTokenRepository } from "../repositories/pushToken.repository";

// POST /notifications/tokens — register/refresh this user's APNS device token.
export async function registerPushToken(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { token } = req.body as { token?: string };

  if (!token || typeof token !== "string") {
    res.status(400).json({ success: false, error: "token is required" });
    return;
  }

  const saved = await pushTokenRepository.upsertToken(req.userId, token);
  res.status(201).json({ success: true, data: { id: saved.id } });
}
