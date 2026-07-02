import { FrequencyType } from "../types";
import { ScheduleConfig } from "../db/models/Schedule";

// A single generated dose, not yet persisted. Times are absolute UTC instants.
export interface GeneratedDose {
  scheduledAt: Date;
  windowStartAt: Date;
  windowEndAt: Date;
  doseAmount: number;
}

export interface GenerateDosesInput {
  frequencyType: FrequencyType;
  scheduleConfig: ScheduleConfig;
  startAt: Date;
  endAt: Date | null;
  graceBeforeMinutes: number;
  graceAfterMinutes: number;
  pillPerDose: number;
  // Pills free to allocate to *new* doses. maxNewDoses = floor(availablePills / pillPerDose).
  availablePills: number;
  // When appending/rescheduling, chain forward from the last existing dose instead of startAt.
  lastDoseAt?: Date | null;
  // Reschedule: only materialize doses strictly after this instant, while keeping the
  // schedule's phase alignment. Past-dated occurrences are skipped, not counted.
  notBefore?: Date | null;
}

// Hard upper bound so a misconfigured schedule (e.g. huge quantity, tiny interval)
// can never loop unbounded. Quantity is the primary limiter; this is a backstop.
const SAFETY_CUTOFF_YEARS = 5;

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60_000);
}

function addHours(date: Date, hours: number): Date {
  return new Date(date.getTime() + hours * 3_600_000);
}

// NOTE: There is no per-schedule timezone column, so "HH:MM" times are combined
// with the calendar day in UTC. If timezone support is added later, this is the
// single place that needs to convert local wall-clock time -> UTC.
function combineDayAndTime(day: Date, time: string): Date {
  const [hh, mm] = time.split(":").map(Number);
  return new Date(
    Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), hh, mm, 0, 0)
  );
}

function scheduleAppliesOn(
  frequencyType: FrequencyType,
  config: ScheduleConfig,
  day: Date
): boolean {
  if (frequencyType === "daily") return true;
  if (frequencyType === "weekly") {
    const weekdays = (config as { weekdays: number[] }).weekdays;
    return weekdays.includes(day.getUTCDay()); // 0=Sun..6=Sat
  }
  return false;
}

function buildDose(scheduledAt: Date, input: GenerateDosesInput): GeneratedDose {
  return {
    scheduledAt,
    windowStartAt: addMinutes(scheduledAt, -input.graceBeforeMinutes),
    windowEndAt: addMinutes(scheduledAt, input.graceAfterMinutes),
    doseAmount: input.pillPerDose,
  };
}

function generateInterval(input: GenerateDosesInput, maxNewDoses: number): GeneratedDose[] {
  const intervalHours = (input.scheduleConfig as { intervalHours: number }).intervalHours;
  const safetyCutoff = addHours(input.startAt, SAFETY_CUTOFF_YEARS * 365 * 24);

  // Chain forward from the last existing dose, otherwise anchor at startAt.
  let nextTime = input.lastDoseAt
    ? addHours(input.lastDoseAt, intervalHours)
    : new Date(input.startAt);

  // Fast-forward past occurrences at or before notBefore, preserving phase.
  if (input.notBefore) {
    while (nextTime <= input.notBefore) {
      const gapMs = input.notBefore.getTime() - nextTime.getTime();
      const steps = Math.max(1, Math.ceil(gapMs / (intervalHours * 3_600_000)));
      nextTime = addHours(nextTime, steps * intervalHours);
    }
  }

  const doses: GeneratedDose[] = [];
  while (doses.length < maxNewDoses) {
    if (input.endAt && nextTime > input.endAt) break;
    if (nextTime > safetyCutoff) break;
    doses.push(buildDose(nextTime, input));
    nextTime = addHours(nextTime, intervalHours);
  }
  return doses;
}

function generateCalendar(input: GenerateDosesInput, maxNewDoses: number): GeneratedDose[] {
  const times = [...(input.scheduleConfig as { timesOfDay: string[] }).timesOfDay].sort();
  const safetyCutoff = addHours(input.startAt, SAFETY_CUTOFF_YEARS * 365 * 24);

  // First materialization anchors on the start day; appends resume the day after
  // the last existing dose.
  let currentDay: Date;
  if (input.lastDoseAt) {
    currentDay = new Date(input.lastDoseAt);
    currentDay.setUTCDate(currentDay.getUTCDate() + 1);
  } else {
    currentDay = new Date(input.startAt);
  }
  currentDay = new Date(
    Date.UTC(currentDay.getUTCFullYear(), currentDay.getUTCMonth(), currentDay.getUTCDate())
  );

  // Fast-forward to the notBefore day so we don't scan irrelevant past days.
  if (input.notBefore) {
    const floorDay = new Date(
      Date.UTC(
        input.notBefore.getUTCFullYear(),
        input.notBefore.getUTCMonth(),
        input.notBefore.getUTCDate()
      )
    );
    if (currentDay < floorDay) currentDay = floorDay;
  }

  const doses: GeneratedDose[] = [];
  while (doses.length < maxNewDoses) {
    if (currentDay > safetyCutoff) break;

    if (scheduleAppliesOn(input.frequencyType, input.scheduleConfig, currentDay)) {
      for (const time of times) {
        if (doses.length >= maxNewDoses) break;
        const scheduledAt = combineDayAndTime(currentDay, time);
        // Skip times before the anchor (e.g. earlier slots on the start day).
        if (scheduledAt < input.startAt) continue;
        // Skip past occurrences when rescheduling.
        if (input.notBefore && scheduledAt <= input.notBefore) continue;
        if (input.endAt && scheduledAt > input.endAt) return doses;
        doses.push(buildDose(scheduledAt, input));
      }
    }
    currentDay.setUTCDate(currentDay.getUTCDate() + 1);
  }
  return doses;
}

// Pure dose materialization. No DB access — used by both preview and create.
export function generateDoses(input: GenerateDosesInput): GeneratedDose[] {
  const maxNewDoses = Math.floor(input.availablePills / input.pillPerDose);
  if (maxNewDoses <= 0) return [];

  if (input.frequencyType === "hourly") {
    return generateInterval(input, maxNewDoses);
  }
  return generateCalendar(input, maxNewDoses);
}
