import { LoginSession } from "../db/models/LoginSession";

export const sessionRepository = {
  create(data: {
    userId: string;
    tokenHash: string;
    deviceName?: string;
    ipAddress?: string;
  }) {
    return LoginSession.create({
      userId: data.userId,
      tokenHash: data.tokenHash,
      deviceName: data.deviceName ?? null,
      ipAddress: data.ipAddress ?? null,
      lastActiveAt: new Date(),
    });
  },

  findActiveByTokenHash(tokenHash: string) {
    return LoginSession.findOne({
      where: { tokenHash, revokedAt: null },
    });
  },

  findAllActiveByUserId(userId: string) {
    return LoginSession.findAll({
      where: { userId, revokedAt: null },
      order: [["lastActiveAt", "DESC"]],
    });
  },

  async revokeById(id: string, userId: string) {
    const [count] = await LoginSession.update(
      { revokedAt: new Date() },
      { where: { id, userId, revokedAt: null } },
    );
    return count > 0;
  },

  async revokeByTokenHash(tokenHash: string) {
    const [count] = await LoginSession.update(
      { revokedAt: new Date() },
      { where: { tokenHash, revokedAt: null } },
    );
    return count > 0;
  },

  touchLastActive(tokenHash: string) {
    return LoginSession.update(
      { lastActiveAt: new Date() },
      { where: { tokenHash, revokedAt: null } },
    );
  },
};
