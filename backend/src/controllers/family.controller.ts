import { Response } from "express";
import { AuthenticatedRequest } from "../types";

// POST /families
export async function createFamily(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { name } = req.body as { name: string };

  if (!name) {
    res.status(400).json({ success: false, error: "Family name is required" });
    return;
  }

  // TODO: create family, assign req.userId as owner, generate invite code
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /families/join
export async function joinFamily(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { inviteCode } = req.body as { inviteCode: string };

  if (!inviteCode) {
    res.status(400).json({ success: false, error: "inviteCode is required" });
    return;
  }

  // TODO: validate invite code, add req.userId to family as member
  res.status(501).json({ success: false, error: "Not implemented" });
}

// GET /families/current
export async function getCurrentFamily(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: return active family for req.userId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// PATCH /families/:id
export async function updateFamily(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { name } = req.body as { name: string };

  // TODO: rename family, verify req.userId is owner or admin
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /families/:id/invite-code
export async function refreshInviteCode(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: generate new invite code, set expiry, verify req.userId is owner or admin
  res.status(501).json({ success: false, error: "Not implemented" });
}

// GET /families/:id/members
export async function listMembers(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: return all members of family id
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /families/:id/members/:memberId
export async function removeMember(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id, memberId } = req.params;

  // TODO: remove member, verify req.userId is owner or admin, prevent removing last owner
  res.status(501).json({ success: false, error: "Not implemented" });
}
