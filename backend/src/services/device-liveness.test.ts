// Runnable self-check for device liveness computation.
// No framework - run with: npx ts-node src/services/device-liveness.test.ts
import assert from "node:assert/strict";

async function main(): Promise<void> {
  process.env.DATABASE_URL = "postgres://user:password@localhost:5432/doselatch_liveness_test";
  const { DEVICE_ONLINE_GRACE_MS, getDeviceConnectionState } = await import("./device.service");
  const now = new Date("2026-07-10T12:00:00.000Z");

  assert.equal(getDeviceConnectionState(null, now), "disconnected");
  assert.equal(
    getDeviceConnectionState(new Date(now.getTime() - DEVICE_ONLINE_GRACE_MS), now),
    "connected",
  );
  assert.equal(
    getDeviceConnectionState(new Date(now.getTime() - DEVICE_ONLINE_GRACE_MS - 1), now),
    "disconnected",
  );
  assert.equal(
    getDeviceConnectionState(new Date(now.getTime() + 1), now),
    "disconnected",
  );

  console.log("device-liveness self-check passed");
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
