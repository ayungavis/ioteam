import axios from "axios";
import { decodeProtectedHeader, importJWK, JWK, jwtVerify } from "jose";

type AppleSignInCredentials = {
  clientId: string;
  teamId: string;
  keyId: string;
  privateKey: string;
};

export class AppleAuthHandler {
  private readonly _credentials: AppleSignInCredentials;
  clientSecret?: string;
  static publicKeys: JWK[] = [];

  constructor(credentials: AppleSignInCredentials) {
    this._credentials = credentials;
  }

  // Get public keys from Apple servers
  private static async updatePublicKeys() {
    try {
      const url = "https://appleid.apple.com/auth/oauth2/v2/keys";
      const { status, data } = await axios.get(url);

      if ([200, 201, 204].includes(status)) {
        const keys = data.keys;
        if (keys && keys.length > 0) {
          AppleAuthHandler.publicKeys = keys;
          return keys;
        } else {
          console.log("No keys found in the response.");
          throw new Error("No keys found in the response");
        }
      }

      throw {
        message: "Failed to execute HTTP request",
        status,
        data,
      };
    } catch (error) {
      console.error("Error occurred while updating public keys:", error);
      throw error;
    }
  }

  private static async getPublicKey(kid: string) {
    if (AppleAuthHandler.publicKeys.length === 0) {
      await AppleAuthHandler.updatePublicKeys();
    }

    const foundKey = AppleAuthHandler.publicKeys.find((key) => key.kid === kid);
    if (foundKey) {
      return foundKey;
    }

    await AppleAuthHandler.updatePublicKeys();
    const foundKeySecondAttempt = AppleAuthHandler.publicKeys.find(
      (key) => key.kid === kid,
    );

    if (foundKeySecondAttempt) {
      return foundKeySecondAttempt;
    }

    throw new Error("AppleAuthHandler: Public key not found");
  }

  private static async decodeIdToken(idToken: string) {
    const idTokenHeader = await decodeProtectedHeader(idToken);
    const relatedPublicKey = await AppleAuthHandler.getPublicKey(
      idTokenHeader.kid!,
    );
    const publicKey = await importJWK(relatedPublicKey);
    const { payload } = await jwtVerify(idToken, publicKey);

    return payload;
  }

  async validateIdToken(idToken: string, clientNonce?: string) {
    try {
      const decodedToken = await AppleAuthHandler.decodeIdToken(idToken);

      const { iss, sub, aud, email, email_verified, is_private_email, nonce } =
        decodedToken;

      if (!iss || !sub || !aud) {
        throw new Error("Token is missing required fields.");
      }

      const audience = typeof aud === "string" ? aud : aud[0]!;
      const emailVerified =
        email_verified === true || email_verified === "true";

      this.validateTokenProperties(
        iss,
        audience,
        sub,
        emailVerified,
        typeof nonce === "string" ? nonce : undefined,
        clientNonce,
      );

      return {
        aud: audience,
        email: email as string | undefined,
        emailVerified,
        isPrivateEmail: is_private_email,
        sub,
      };
    } catch (error) {
      throw error;
    }
  }

  get credentials() {
    return this._credentials;
  }

  private validateTokenProperties(
    iss: string,
    aud: string,
    sub: string,
    emailVerified: boolean,
    nonce?: string,
    clientNonce?: string,
  ): void {
    if (!iss.includes("https://appleid.apple.com")) {
      throw new Error("Token issuer is invalid.");
    }
    if (aud !== this._credentials.clientId) {
      throw new Error("Token audience is invalid.");
    }
    if (!sub) {
      throw new Error("Token subject is invalid.");
    }
    if (!emailVerified) {
      throw new Error("Email not verified.");
    }
    if (nonce && nonce !== clientNonce) {
      throw new Error("Nonce is invalid.");
    }
  }
}

export const appleAuthHandler = new AppleAuthHandler({
  clientId: process.env.APPLE_CLIENT_ID ?? "",
  teamId: process.env.APPLE_TEAM_ID ?? "",
  keyId: process.env.APPLE_KEY_ID ?? "",
  privateKey: process.env.APPLE_PRIVATE_KEY ?? "",
});
