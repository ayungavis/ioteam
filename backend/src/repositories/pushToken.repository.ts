import { Op } from "sequelize";
import { PushToken } from "../db/models/PushToken";

export const pushTokenRepository = {
  // One row per token (token is unique). Re-registering moves it to the current
  // user and refreshes last_used_at.
  async upsertToken(userId: string, token: string): Promise<PushToken> {
    const [row] = await PushToken.upsert({ userId, token, lastUsedAt: new Date() });
    return row;
  },

  findByUserIds(userIds: string[]): Promise<PushToken[]> {
    if (userIds.length === 0) return Promise.resolve([]);
    return PushToken.findAll({ where: { userId: { [Op.in]: userIds } } });
  },

  async deleteTokenForUser(userId: string, token: string): Promise<number> {
    return PushToken.destroy({ where: { userId, token } });
  },
};
