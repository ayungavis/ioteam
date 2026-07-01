import { User } from "../db/models/User";

export const userRepository = {
  findByAppleUserId(appleUserId: string) {
    return User.findOne({ where: { appleUserId } });
  },

  findById(id: string) {
    return User.findByPk(id);
  },

  // Returns [user, created] — created=true means a new row was inserted
  findOrCreate(data: { appleUserId: string; email: string; fullName: string }) {
    return User.findOrCreate({
      where: { appleUserId: data.appleUserId },
      defaults: data,
    });
  },

  async update(
    id: string,
    data: Partial<Pick<User, "fullName" | "dateOfBirth" | "avatarUrl" | "onboardingCompleted">>
  ) {
    const [, rows] = await User.update(data, { where: { id }, returning: true });
    return rows[0] ?? null;
  },

  async deleteById(id: string) {
    const count = await User.destroy({ where: { id } });
    return count > 0;
  },
};
