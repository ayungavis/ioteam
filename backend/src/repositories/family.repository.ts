import { Family } from "../db/models/Family";
import { FamilyMember } from "../db/models/FamilyMember";
import { User } from "../db/models/User";
import { FamilyMemberRole } from "../types";

export const familyRepository = {
  findById(id: string) {
    return Family.findByPk(id);
  },

  findByInviteCode(inviteCode: string) {
    return Family.findOne({ where: { inviteCode } });
  },

  create(data: { name: string; inviteCode: string }) {
    return Family.create(data);
  },

  update(id: string, data: Partial<Pick<Family, "name" | "inviteCode">>) {
    return Family.update(data, { where: { id } });
  },

  // Get a single user's membership in any family
  getMembershipByUserId(userId: string) {
    return FamilyMember.findOne({ where: { userId } });
  },

  // Get a user's membership in a specific family
  getMembershipByUserAndFamily(userId: string, familyId: string) {
    return FamilyMember.findOne({ where: { userId, familyId } });
  },

  getMemberById(id: string, familyId: string) {
    return FamilyMember.findOne({ where: { id, familyId } });
  },

  // List all members with joined user profile
  getMembers(familyId: string) {
    return FamilyMember.findAll({
      where: { familyId },
      include: [{ model: User, as: "user", attributes: ["id", "fullName", "email", "avatarUrl"] }],
      order: [["joinedAt", "ASC"]],
    });
  },

  addMember(data: { familyId: string; userId: string; role: FamilyMemberRole }) {
    return FamilyMember.create({
      familyId: data.familyId,
      userId: data.userId,
      role: data.role,
      joinedAt: new Date(),
    });
  },

  async removeMember(id: string, familyId: string) {
    const count = await FamilyMember.destroy({ where: { id, familyId } });
    return count > 0;
  },

  countOwners(familyId: string) {
    return FamilyMember.count({ where: { familyId, role: "owner" } });
  },
};
