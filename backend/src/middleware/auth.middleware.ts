import { Request, Response, NextFunction } from "express";
import { tokenService } from "../services/token.service";

export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const token = req.headers.authorization?.split(" ")[1];

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
