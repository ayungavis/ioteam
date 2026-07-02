// Runnable self-check for the open-event/window correlation.
// No framework — run with: npx ts-node src/services/dose-window.test.ts
import assert from "node:assert/strict";
import { matchOpenEvents, WindowDose, OpenEvent } from "./dose-window";

const t = (s: string) => new Date(s);

const dose = (over: Partial<WindowDose> = {}): WindowDose => ({
  id: "d1",
  deviceId: "dev1",
  windowStartAt: t("2026-07-02T08:00:00Z"),
  windowEndAt: t("2026-07-02T08:30:00Z"),
  ...over,
});

const ev = (over: Partial<OpenEvent> = {}): OpenEvent => ({
  deviceId: "dev1",
  deviceTimestamp: t("2026-07-02T08:15:00Z"),
  ...over,
});

// inside window -> matched
assert.deepEqual(matchOpenEvents([dose()], [ev()]), ["d1"]);

// exactly on both edges -> matched (inclusive)
assert.deepEqual(matchOpenEvents([dose()], [ev({ deviceTimestamp: t("2026-07-02T08:00:00Z") })]), ["d1"]);
assert.deepEqual(matchOpenEvents([dose()], [ev({ deviceTimestamp: t("2026-07-02T08:30:00Z") })]), ["d1"]);

// before / after window -> not matched
assert.deepEqual(matchOpenEvents([dose()], [ev({ deviceTimestamp: t("2026-07-02T07:59:59Z") })]), []);
assert.deepEqual(matchOpenEvents([dose()], [ev({ deviceTimestamp: t("2026-07-02T08:30:01Z") })]), []);

// different device -> not matched
assert.deepEqual(matchOpenEvents([dose()], [ev({ deviceId: "other" })]), []);

// dose without a device -> never matched
assert.deepEqual(matchOpenEvents([dose({ deviceId: null })], [ev()]), []);

// mixed set -> only the matching dose id
const matched = matchOpenEvents(
  [dose({ id: "in" }), dose({ id: "out", windowStartAt: t("2026-07-02T09:00:00Z"), windowEndAt: t("2026-07-02T09:30:00Z") })],
  [ev()]
);
assert.deepEqual(matched, ["in"]);

console.log("dose-window self-check passed");
