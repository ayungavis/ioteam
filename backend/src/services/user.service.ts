import { userRepository } from "../repositories/user.repository";

export const userService = {
  // Find existing user by Apple ID or create a new one.
  // fullName is only sent by Apple on first sign-in — store it then, ignore on subsequent calls.
  async findOrCreateFromApple(params: {
    appleUserId: string;
    email: string;
    fullName?: string;
  }) {
    const [user, created] = await userRepository.findOrCreate({
      appleUserId: params.appleUserId,
      email: params.email,
      fullName: params.fullName ?? "",
    });

    return { user, created };
  },

  async getProfile(userId: string) {
    const user = await userRepository.findById(userId);
    if (!user) throw Object.assign(new Error("User not found"), { statusCode: 404 });
    return user;
  },

  async updateProfile(
    userId: string,
    data: { fullName?: string; dateOfBirth?: string; avatarUrl?: string }
  ) {
    const user = await userRepository.update(userId, data);
    if (!user) throw Object.assign(new Error("User not found"), { statusCode: 404 });
    return user;
  },

  async completeOnboarding(userId: string) {
    const user = await userRepository.update(userId, { onboardingCompleted: true });
    if (!user) throw Object.assign(new Error("User not found"), { statusCode: 404 });
    return user;
  },

  async deleteAccount(userId: string) {
    const deleted = await userRepository.deleteById(userId);
    if (!deleted) throw Object.assign(new Error("User not found"), { statusCode: 404 });
  },
};
