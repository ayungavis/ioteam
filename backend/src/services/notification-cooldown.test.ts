// Runnable self-check for the notification cooldown.
// No framework — run with: npx ts-node src/services/notification-cooldown.test.ts
import assert from "node:assert/strict";
import { shouldNotify, resetNotificationCooldowns } from "./notification-cooldown";

const T0 = 1_000_000;

// default cooldown (60s)
delete process.env.DEVICE_EVENT_NOTIFY_COOLDOWN_MS;
resetNotificationCooldowns();

// first call for a key always notifies
assert.equal(shouldNotify("dev1", T0), true);

// immediate repeat is suppressed
assert.equal(shouldNotify("dev1", T0), false);

// still inside the window at 59.999s
assert.equal(shouldNotify("dev1", T0 + 59_999), false);

// exactly at the boundary the cooldown has elapsed
assert.equal(shouldNotify("dev1", T0 + 60_000), true);

// ...and that call re-armed the cooldown from the new time
assert.equal(shouldNotify("dev1", T0 + 60_001), false);

// keys are independent
resetNotificationCooldowns();
assert.equal(shouldNotify("dev1", T0), true);
assert.equal(shouldNotify("dev2", T0), true);
assert.equal(shouldNotify("dev1", T0), false);

// a suppressed call must not slide the window forward: at T0+60_000 the cooldown
// is measured from T0 (the last *notification*), not from the suppressed call.
resetNotificationCooldowns();
assert.equal(shouldNotify("dev1", T0), true);
assert.equal(shouldNotify("dev1", T0 + 50_000), false);
assert.equal(shouldNotify("dev1", T0 + 60_000), true);

// env override is read per call, not frozen at import
resetNotificationCooldowns();
process.env.DEVICE_EVENT_NOTIFY_COOLDOWN_MS = "5000";
assert.equal(shouldNotify("dev1", T0), true);
assert.equal(shouldNotify("dev1", T0 + 4_999), false);
assert.equal(shouldNotify("dev1", T0 + 5_000), true);

// unparseable / zero env falls back to the default
resetNotificationCooldowns();
process.env.DEVICE_EVENT_NOTIFY_COOLDOWN_MS = "not-a-number";
assert.equal(shouldNotify("dev1", T0), true);
assert.equal(shouldNotify("dev1", T0 + 59_999), false);

delete process.env.DEVICE_EVENT_NOTIFY_COOLDOWN_MS;
console.log("notification-cooldown self-check passed");
