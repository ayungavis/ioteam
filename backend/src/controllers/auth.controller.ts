import { Request, Response } from "express";
import { appleAuthHandler } from "../services/appleAuth";
import { userService } from "../services/user.service";
import { tokenService } from "../services/token.service";

// POST /auth/apple
export async function appleSignIn(req: Request, res: Response): Promise<void> {
  const { identityToken, fullName } = req.body as {
    identityToken: string;
    fullName?: string;
  };

  if (!identityToken) {
    res.status(400).json({ success: false, error: "identityToken is required" });
    return;
  }

  const tokenPayload = await appleAuthHandler.validateIdToken(identityToken);

  if (!tokenPayload.email) {
    res.status(400).json({ success: false, error: "Email not available from Apple token" });
    return;
  }

  const { user, created } = await userService.findOrCreateFromApple({
    appleUserId: tokenPayload.sub,
    email: tokenPayload.email,
    fullName,
  });

  const accessToken = await tokenService.generate(user.id);

  res.status(created ? 201 : 200).json({
    success: true,
    data: {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        onboardingCompleted: user.onboardingCompleted,
      },
    },
  });
}

// POST /auth/dev-login — development only, skips Apple verification
export async function devLogin(req: Request, res: Response): Promise<void> {
  const { email, fullName } = req.body as { email: string; fullName?: string };

  if (!email) {
    res.status(400).json({ success: false, error: "email is required" });
    return;
  }

  const { user, created } = await userService.findOrCreateFromApple({
    appleUserId: `dev-${email}`,
    email,
    fullName: fullName ?? "Dev User",
  });

  const accessToken = await tokenService.generate(user.id);

  res.status(created ? 201 : 200).json({
    success: true,
    data: {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        onboardingCompleted: user.onboardingCompleted,
      },
    },
  });
}

// POST /auth/logout — frontend deletes the token; nothing to do server-side for now
export async function logout(_req: Request, res: Response): Promise<void> {
  res.json({ success: true });
}

// GET /auth/sessions — TODO: implement when session tracking is added
export async function listSessions(_req: Request, res: Response): Promise<void> {
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /auth/sessions/:id — TODO: implement when session tracking is added
export async function revokeSession(_req: Request, res: Response): Promise<void> {
  res.status(501).json({ success: false, error: "Not implemented" });
}
