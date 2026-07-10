// Per-key notification throttle. Distinct from the reed-switch debounce in
// device.service: the debounce drops the *event* (no DB row), this drops only the
// *push* — the event is always recorded.
//
// ponytail: in-memory, per-instance. The Map is bounded by device count (not event
// count), so no eviction. It resets on deploy — worst case one extra push. Move to
// a `devices.last_notified_at` column or Redis only if you run >1 instance and
// duplicate pushes actually matter.

const DEFAULT_COOLDOWN_MS = 60_000;

const lastNotifiedAtMs = new Map<string, number>();

// True if `key` is outside its cooldown — and records this call as the new
// notification time. `nowMs` must come from the server clock, never a device's.
export function shouldNotify(key: string, nowMs: number): boolean {
  const cooldownMs =
    Number(process.env.DEVICE_EVENT_NOTIFY_COOLDOWN_MS) || DEFAULT_COOLDOWN_MS;

  const last = lastNotifiedAtMs.get(key);
  if (last !== undefined && nowMs - last < cooldownMs) return false;

  lastNotifiedAtMs.set(key, nowMs);
  return true;
}

export function resetNotificationCooldowns(): void {
  lastNotifiedAtMs.clear();
}
