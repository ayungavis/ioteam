import { Response } from "express";
import { AuthenticatedRequest } from "../types";

// GET /me
export async function getMe(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: return user profile for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// PATCH /me
export async function updateMe(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { fullName, dateOfBirth, avatarUrl } = req.body as {
    fullName?: string;
    dateOfBirth?: string;
    avatarUrl?: string;
  };

  // TODO: update user record for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /me
export async function deleteMe(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: delete account and associated data for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /onboarding/complete
export async function completeOnboarding(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: mark onboarding as complete for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}
