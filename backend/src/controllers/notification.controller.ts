import { Response } from "express";
import { AuthenticatedRequest, NotificationPayload } from "../types";
import { pushTokenRepository } from "../repositories/pushToken.repository";
import { apnsService } from "../services/apns.service";

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

export async function sendTestNotification(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { userId, title, body } = req.body as {
    userId?: string;
    title?: string;
    body?: string;
  };

  if (!userId || typeof userId !== "string") {
    res.status(400).json({ success: false, error: "userId is required" });
    return;
  }

  const tokens = await pushTokenRepository.findByUserIds([userId]);
  if (tokens.length === 0) {
    res.status(404).json({
      success: false,
      error: "No push tokens found for this user",
    });
    return;
  }

  const payload: NotificationPayload = {
    title: title || "Test notification",
    body: body || "This is a test push from IoTeam.",
    data: { kind: "test", sentBy: req.userId },
  };

  await apnsService.sendToTokens(
    tokens.map((t) => t.token),
    payload
  );

  res.json({
    success: true,
    message: `Push sent to ${tokens.length} device(s).`,
  });
}
