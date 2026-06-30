import { Request, Response } from "express";

// POST /auth/apple
// Verify Apple identity token, create or update user, return session token.
export async function appleSignIn(req: Request, res: Response): Promise<void> {
  const { identityToken, fullName } = req.body as {
    identityToken: string;
    fullName?: string;
  };

  if (!identityToken) {
    res.status(400).json({ success: false, error: "identityToken is required" });
    return;
  }

  // TODO: verify identityToken with Apple's public keys
  // TODO: create or update user record
  // TODO: create login session and return session token
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /auth/logout
export async function logout(_req: Request, res: Response): Promise<void> {
  // TODO: revoke current session from database
  res.status(501).json({ success: false, error: "Not implemented" });
}

// GET /auth/sessions
export async function listSessions(_req: Request, res: Response): Promise<void> {
  // TODO: return all active sessions for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /auth/sessions/:id
export async function revokeSession(req: Request, res: Response): Promise<void> {
  const { id } = req.params;
  // TODO: revoke session by id, ensure it belongs to req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}
