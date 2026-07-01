import { Request, Response } from "express";
import { familyService } from "../services/family.service";

// POST /families
export async function createFamily(req: Request, res: Response): Promise<void> {
  const { name } = req.body as { name: string };

  if (!name) {
    res.status(400).json({ success: false, error: "Family name is required" });
    return;
  }

  const family = await familyService.createFamily(req.userId, name);

  res.status(201).json({
    success: true,
    data: {
      id: family.id,
      name: family.name,
      inviteCode: family.inviteCode,
    },
  });
}

// POST /families/join
export async function joinFamily(req: Request, res: Response): Promise<void> {
  const { inviteCode } = req.body as { inviteCode: string };

  if (!inviteCode) {
    res.status(400).json({ success: false, error: "inviteCode is required" });
    return;
  }

  const family = await familyService.joinFamily(req.userId, inviteCode);

  res.json({
    success: true,
    data: { id: family.id, name: family.name },
  });
}

// GET /families/current
export async function getCurrentFamily(req: Request, res: Response): Promise<void> {
  const { family, members, role } = await familyService.getCurrentFamily(req.userId);

  res.json({
    success: true,
    data: {
      id: family.id,
      name: family.name,
      inviteCode: family.inviteCode,
      memberCount: members.length,
      role,
      members: members.map((m) => ({
        id: m.id,
        role: m.role,
        joinedAt: m.joinedAt,
        user: (m as any).user,
      })),
    },
  });
}

// PATCH /families/:id
export async function updateFamily(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  const { name } = req.body as { name: string };

  if (!name) {
    res.status(400).json({ success: false, error: "Family name is required" });
    return;
  }

  const family = await familyService.renameFamily(id, req.userId, name);

  res.json({
    success: true,
    data: { id: family.id, name: family.name },
  });
}

// POST /families/:id/invite-code
export async function refreshInviteCode(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  const result = await familyService.refreshInviteCode(id, req.userId);

  res.json({ success: true, data: result });
}

// GET /families/:id/members
export async function listMembers(req: Request, res: Response): Promise<void> {
  const { id } = req.params as { id: string };
  const members = await familyService.listMembers(id, req.userId);

  res.json({
    success: true,
    data: members.map((m) => ({
      id: m.id,
      role: m.role,
      joinedAt: m.joinedAt,
      user: (m as any).user,
    })),
  });
}

// DELETE /families/:id/members/:memberId
export async function removeMember(req: Request, res: Response): Promise<void> {
  const { id, memberId } = req.params as { id: string; memberId: string };
  await familyService.removeMember(id, req.userId, memberId);
  res.json({ success: true });
}
