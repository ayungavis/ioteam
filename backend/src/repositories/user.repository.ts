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

  update(id: string, data: Partial<Pick<User, "fullName" | "dateOfBirth" | "avatarUrl" | "onboardingCompleted">>) {
    return User.update(data, { where: { id }, returning: true });
  },
};
