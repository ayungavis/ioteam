import { familyRepository } from "../repositories/family.repository";
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
} from "../errors/AppError";

function generateInviteCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return Array.from({ length: 6 }, () =>
    chars[Math.floor(Math.random() * chars.length)]
  ).join("");
}

async function assertOwnerOrAdmin(familyId: string, userId: string) {
  const membership = await familyRepository.getMembershipByUserAndFamily(userId, familyId);
  if (!membership || (membership.role !== "owner" && membership.role !== "admin")) {
    throw new ForbiddenError("Only family owner or admin can perform this action");
  }
  return membership;
}

export const familyService = {
  async createFamily(userId: string, name: string) {
    const inviteCode = generateInviteCode();
    const family = await familyRepository.create({ name, inviteCode });

    await familyRepository.addMember({
      familyId: family.id,
      userId,
      role: "owner",
    });

    return family;
  },

  async joinFamily(userId: string, inviteCode: string) {
    const family = await familyRepository.findByInviteCode(inviteCode.toUpperCase());
    if (!family) throw new BadRequestError("Invalid invite code");

    const existing = await familyRepository.getMembershipByUserAndFamily(userId, family.id);
    if (existing) throw new ConflictError("You are already a member of this family");

    await familyRepository.addMember({ familyId: family.id, userId, role: "member" });

    return family;
  },

  async getCurrentFamily(userId: string) {
    const membership = await familyRepository.getMembershipByUserId(userId);
    if (!membership) throw new NotFoundError("You are not a member of any family");

    const family = await familyRepository.findById(membership.familyId);
    if (!family) throw new NotFoundError("Family not found");

    const members = await familyRepository.getMembers(family.id);

    return { family, members, role: membership.role };
  },

  async renameFamily(familyId: string, userId: string, name: string) {
    await assertOwnerOrAdmin(familyId, userId);

    const family = await familyRepository.findById(familyId);
    if (!family) throw new NotFoundError("Family not found");

    await familyRepository.update(familyId, { name });
    family.name = name;
    return family;
  },

  async refreshInviteCode(familyId: string, userId: string) {
    await assertOwnerOrAdmin(familyId, userId);

    const newCode = generateInviteCode();
    await familyRepository.update(familyId, { inviteCode: newCode });

    return { inviteCode: newCode };
  },

  async listMembers(familyId: string, userId: string) {
    const membership = await familyRepository.getMembershipByUserAndFamily(userId, familyId);
    if (!membership) throw new ForbiddenError("You are not a member of this family");

    return familyRepository.getMembers(familyId);
  },

  async removeMember(familyId: string, requesterId: string, memberId: string) {
    await assertOwnerOrAdmin(familyId, requesterId);

    const target = await familyRepository.getMemberById(memberId, familyId);
    if (!target) throw new NotFoundError("Member not found");

    if (target.role === "owner") {
      const ownerCount = await familyRepository.countOwners(familyId);
      if (ownerCount <= 1) throw new ForbiddenError("Cannot remove the last owner of the family");
    }

    await familyRepository.removeMember(memberId, familyId);
  },
};
