import { SignJWT, jwtVerify } from "jose";
import crypto from "crypto";

const secret = new TextEncoder().encode(process.env.SESSION_SECRET || "change-me-in-production");

const EXPIRES_IN = process.env.SESSION_EXPIRES_IN ?? "7d";
const DEVICE_EXPIRES_IN = process.env.DEVICE_TOKEN_EXPIRES_IN ?? "180d";

type TokenUse = "user_session" | "pairing" | "device";

async function signToken(payload: Record<string, string>, tokenUse: TokenUse, expiresIn: string): Promise<string> {
  return new SignJWT({ ...payload, tokenUse })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secret);
}

export const tokenService = {
  async generate(userId: string): Promise<string> {
    return signToken({ sub: userId }, "user_session", EXPIRES_IN);
  },

  async verify(token: string): Promise<{ userId: string }> {
    const { payload } = await jwtVerify(token, secret);
    if (payload.tokenUse && payload.tokenUse !== "user_session") {
      throw new Error("Invalid token payload");
    }
    if (!payload.sub) throw new Error("Invalid token payload");
    return { userId: payload.sub };
  },

  async generatePairingToken(familyId: string): Promise<string> {
    return signToken({ familyId }, "pairing", "10m");
  },

  async verifyPairingToken(token: string): Promise<{ familyId: string }> {
    const { payload } = await jwtVerify(token, secret);
    if (payload.tokenUse !== "pairing" || typeof payload.familyId !== "string") {
      throw new Error("Invalid pairing token payload");
    }
    return { familyId: payload.familyId };
  },

  async generateDeviceToken(deviceId: string): Promise<string> {
    return signToken({ deviceId }, "device", DEVICE_EXPIRES_IN);
  },

  async verifyDeviceToken(token: string): Promise<{ deviceId: string }> {
    const { payload } = await jwtVerify(token, secret);
    if (payload.tokenUse !== "device" || typeof payload.deviceId !== "string") {
      throw new Error("Invalid device token payload");
    }
    return { deviceId: payload.deviceId };
  },

  // Store a SHA-256 hash instead of the raw token so the DB exposure doesn't leak valid tokens.
  hash(token: string): string {
    return crypto.createHash("sha256").update(token).digest("hex");
  },
};
