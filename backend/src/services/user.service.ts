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
};
