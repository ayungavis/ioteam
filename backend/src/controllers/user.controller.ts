import { Request, Response } from "express";
import { userService } from "../services/user.service";

// GET /me
export async function getMe(req: Request, res: Response): Promise<void> {
  const user = await userService.getProfile(req.userId);
  res.json({
    success: true,
    data: {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      dateOfBirth: user.dateOfBirth,
      avatarUrl: user.avatarUrl,
      onboardingCompleted: user.onboardingCompleted,
    },
  });
}

// PATCH /me
export async function updateMe(req: Request, res: Response): Promise<void> {
  const { fullName, dateOfBirth, avatarUrl } = req.body as {
    fullName?: string;
    dateOfBirth?: string;
    avatarUrl?: string;
  };

  const user = await userService.updateProfile(req.userId, {
    fullName,
    dateOfBirth,
    avatarUrl,
  });

  res.json({
    success: true,
    data: {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      dateOfBirth: user.dateOfBirth,
      avatarUrl: user.avatarUrl,
      onboardingCompleted: user.onboardingCompleted,
    },
  });
}

// DELETE /me
export async function deleteMe(req: Request, res: Response): Promise<void> {
  await userService.deleteAccount(req.userId);
  res.json({ success: true });
}

// POST /onboarding/complete
export async function completeOnboarding(req: Request, res: Response): Promise<void> {
  const user = await userService.completeOnboarding(req.userId);
  res.json({
    success: true,
    data: {
      id: user.id,
      onboardingCompleted: user.onboardingCompleted,
    },
  });
}
