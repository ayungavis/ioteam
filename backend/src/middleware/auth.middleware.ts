import { Request, Response, NextFunction } from "express";
import { deviceRepository } from "../repositories/device.repository";
import { tokenService } from "../services/token.service";

function readBearerToken(req: Request): string | null {
  return req.headers.authorization?.split(" ")[1] ?? null;
}

export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const token = readBearerToken(req);

  if (!token) {
    res.status(401).json({ success: false, error: "Unauthorized" });
    return;
  }

  try {
    const { userId } = await tokenService.verify(token);
    req.userId = userId;
    next();
  } catch {
    res.status(401).json({ success: false, error: "Invalid or expired token" });
  }
}

export async function authenticateDevice(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const token = readBearerToken(req);

  if (!token) {
    res.status(401).json({ success: false, error: "Unauthorized" });
    return;
  }

  try {
    const { deviceId } = await tokenService.verifyDeviceToken(token);
    const device = await deviceRepository.findById(deviceId);

    if (!device || device.status === "deleted" || device.deviceTokenHash !== tokenService.hash(token)) {
      res.status(401).json({ success: false, error: "Invalid or expired token" });
      return;
    }

    req.deviceId = deviceId;
    next();
  } catch {
    res.status(401).json({ success: false, error: "Invalid or expired token" });
  }
}
