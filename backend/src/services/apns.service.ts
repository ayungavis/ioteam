import http2 from "node:http2";
import { SignJWT, importPKCS8 } from "jose";
import { NotificationPayload } from "../types";

// APNS token-based auth + delivery. Reuses the existing Apple credentials
// (APPLE_TEAM_ID / APPLE_KEY_ID) plus the push .p8 key.
//
// APNS is HTTP/2 only, so we use Node's built-in http2 client (no new dep).
// ponytail: axios speaks HTTP/1.1, which APNS rejects — http2 is the correct
// transport, not a nicety.

const TEAM_ID = process.env.APPLE_TEAM_ID;
const KEY_ID = process.env.APPLE_KEY_ID;
const TOPIC = process.env.APNS_TOPIC; // app bundle id
const HOST = process.env.APNS_HOST || "api.sandbox.push.apple.com";
// .p8 contents; env stores the PEM with escaped newlines.
const KEY_P8 = process.env.APNS_KEY_P8?.replace(/\\n/g, "\n");

const JWT_TTL_MS = 50 * 60 * 1000; // APNS tokens are valid <1h; refresh at 50m.

function isConfigured(): boolean {
  return Boolean(TEAM_ID && KEY_ID && TOPIC && KEY_P8);
}

let cachedKey: Awaited<ReturnType<typeof importPKCS8>> | null = null;
let cachedJwt: { value: string; expiresAt: number } | null = null;

async function getAuthToken(): Promise<string> {
  const now = Date.now();
  if (cachedJwt && cachedJwt.expiresAt > now) return cachedJwt.value;

  if (!cachedKey) cachedKey = await importPKCS8(KEY_P8 as string, "ES256");

  const value = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: KEY_ID as string })
    .setIssuedAt()
    .setIssuer(TEAM_ID as string)
    .sign(cachedKey);

  cachedJwt = { value, expiresAt: now + JWT_TTL_MS };
  return value;
}

function buildBody(payload: NotificationPayload): string {
  return JSON.stringify({
    aps: {
      alert: { title: payload.title, body: payload.body },
      sound: "default",
    },
    ...(payload.data ?? {}),
  });
}

function postOne(
  session: http2.ClientHttp2Session,
  jwt: string,
  token: string,
  body: string
): Promise<void> {
  return new Promise((resolve) => {
    const req = session.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": TOPIC as string,
      "apns-push-type": "alert",
      "content-type": "application/json",
    });

    let status = 0;
    let data = "";
    req.on("response", (headers) => {
      status = Number(headers[":status"]) || 0;
    });
    req.setEncoding("utf8");
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => {
      if (status !== 200) {
        console.warn(`APNS push failed (${status}) for token ${token.slice(0, 8)}…: ${data}`);
      }
      resolve();
    });
    req.on("error", (err) => {
      console.warn(`APNS request error for token ${token.slice(0, 8)}…:`, err.message);
      resolve();
    });

    req.write(body);
    req.end();
  });
}

export const apnsService = {
  async sendToTokens(tokens: string[], payload: NotificationPayload): Promise<void> {
    if (tokens.length === 0) return;
    if (!isConfigured()) {
      console.warn("APNS not configured (APPLE_TEAM_ID/APPLE_KEY_ID/APNS_TOPIC/APNS_KEY_P8) — skipping push");
      return;
    }

    let jwt: string;
    try {
      jwt = await getAuthToken();
    } catch (err) {
      console.error("APNS auth token build failed:", err);
      return;
    }

    const session = http2.connect(`https://${HOST}`);
    session.on("error", (err) => console.warn("APNS session error:", err.message));
    try {
      const body = buildBody(payload);
      await Promise.all(tokens.map((t) => postOne(session, jwt, t, body)));
    } finally {
      session.close();
    }
  },
};
