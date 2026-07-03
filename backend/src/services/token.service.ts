import { SignJWT, jwtVerify } from "jose";
import crypto from "crypto";

const secret = new TextEncoder().encode(process.env.SESSION_SECRET);

const EXPIRES_IN = process.env.SESSION_EXPIRES_IN ?? "7d";

export const tokenService = {
  async generate(userId: string): Promise<string> {
    return new SignJWT({ sub: userId })
      .setProtectedHeader({ alg: "HS256" })
      .setIssuedAt()
      .setExpirationTime(EXPIRES_IN)
      .sign(secret);
  },

  async verify(token: string): Promise<{ userId: string }> {
    const { payload } = await jwtVerify(token, secret);
    if (!payload.sub) throw new Error("Invalid token payload");
    return { userId: payload.sub };
  },

  // Store a SHA-256 hash instead of the raw token so the DB exposure doesn't leak valid tokens.
  hash(token: string): string {
    return crypto.createHash("sha256").update(token).digest("hex");
  },
};
