// Pure window/event correlation — the one non-trivial in-JS bit of the sweep.
// Kept DB-free so it can be unit-tested without a database.

export interface WindowDose {
  id: string;
  deviceId: string | null;
  windowStartAt: Date;
  windowEndAt: Date;
}

export interface OpenEvent {
  deviceId: string;
  deviceTimestamp: Date;
}

// Ids of doses whose medicine's device reported an `open` inside the dose window
// (inclusive of both edges — a box opened exactly at window_start/window_end counts).
export function matchOpenEvents(doses: WindowDose[], events: OpenEvent[]): string[] {
  return doses
    .filter((d) => d.deviceId !== null)
    .filter((d) =>
      events.some(
        (e) =>
          e.deviceId === d.deviceId &&
          e.deviceTimestamp >= d.windowStartAt &&
          e.deviceTimestamp <= d.windowEndAt
      )
    )
    .map((d) => d.id);
}
