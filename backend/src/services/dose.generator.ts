import { fromZonedTime, formatInTimeZone } from "date-fns-tz";
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
  // IANA timezone the "HH:MM" times-of-day and calendar days are interpreted in.
  timezone: string;
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

// ─── Timezone helpers ───────────────────────────────────────────────────────
// A calendar date as seen in a specific timezone (month is 1-12).
interface LocalDate {
  year: number;
  month: number;
  day: number;
}

const pad = (n: number, len = 2) => String(n).padStart(len, "0");

// The calendar date an instant falls on in the given timezone.
function localDateOf(instant: Date, timeZone: string): LocalDate {
  const [year, month, day] = formatInTimeZone(instant, timeZone, "yyyy-MM-dd")
    .split("-")
    .map(Number);
  return { year, month, day };
}

// Convert a local wall-clock time (date + HH:MM in timeZone) to a UTC instant.
// date-fns-tz handles offset resolution, including DST transitions.
function zonedTimeToUtc(
  date: LocalDate,
  hour: number,
  minute: number,
  timeZone: string
): Date {
  const wallClock = `${pad(date.year, 4)}-${pad(date.month)}-${pad(date.day)}T${pad(hour)}:${pad(minute)}:00`;
  return fromZonedTime(wallClock, timeZone);
}

function addLocalDays(date: LocalDate, days: number): LocalDate {
  const proxy = new Date(Date.UTC(date.year, date.month - 1, date.day));
  proxy.setUTCDate(proxy.getUTCDate() + days);
  return {
    year: proxy.getUTCFullYear(),
    month: proxy.getUTCMonth() + 1,
    day: proxy.getUTCDate(),
  };
}

function compareLocalDate(a: LocalDate, b: LocalDate): number {
  if (a.year !== b.year) return a.year - b.year;
  if (a.month !== b.month) return a.month - b.month;
  return a.day - b.day;
}

// 0=Sun..6=Sat for the given calendar date (weekday is timezone-independent).
function localWeekday(date: LocalDate): number {
  return new Date(Date.UTC(date.year, date.month - 1, date.day)).getUTCDay();
}

// ─── Generation ───────────────────────────────────────────────────────────────
function scheduleAppliesOn(
  frequencyType: FrequencyType,
  config: ScheduleConfig,
  date: LocalDate
): boolean {
  if (frequencyType === "daily") return true;
  if (frequencyType === "weekly") {
    const weekdays = (config as { weekdays: number[] }).weekdays;
    return weekdays.includes(localWeekday(date));
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

// Interval schedules are pure elapsed-time, so timezone never affects them.
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

// Calendar schedules (daily/weekly) iterate over *local* days in the schedule's
// timezone, converting each "HH:MM" to a UTC instant.
function generateCalendar(input: GenerateDosesInput, maxNewDoses: number): GeneratedDose[] {
  const tz = input.timezone;
  const times = [...(input.scheduleConfig as { timesOfDay: string[] }).timesOfDay].sort();
  const safetyCutoffMs = addHours(input.startAt, SAFETY_CUTOFF_YEARS * 365 * 24).getTime();

  // First materialization anchors on the start day; appends resume the day after
  // the last existing dose (both in local time).
  let currentDate = input.lastDoseAt
    ? addLocalDays(localDateOf(input.lastDoseAt, tz), 1)
    : localDateOf(input.startAt, tz);

  // Fast-forward to the notBefore local day so we don't scan irrelevant past days.
  if (input.notBefore) {
    const floor = localDateOf(input.notBefore, tz);
    if (compareLocalDate(currentDate, floor) < 0) currentDate = floor;
  }

  const doses: GeneratedDose[] = [];
  while (doses.length < maxNewDoses) {
    const dayProxyMs = Date.UTC(currentDate.year, currentDate.month - 1, currentDate.day);
    if (dayProxyMs > safetyCutoffMs) break;

    if (scheduleAppliesOn(input.frequencyType, input.scheduleConfig, currentDate)) {
      for (const time of times) {
        if (doses.length >= maxNewDoses) break;
        const [hh, mm] = time.split(":").map(Number);
        const scheduledAt = zonedTimeToUtc(currentDate, hh, mm, tz);
        // Skip times before the anchor (e.g. earlier slots on the start day).
        if (scheduledAt.getTime() < input.startAt.getTime()) continue;
        // Skip past occurrences when rescheduling.
        if (input.notBefore && scheduledAt.getTime() <= input.notBefore.getTime()) continue;
        if (input.endAt && scheduledAt.getTime() > input.endAt.getTime()) return doses;
        doses.push(buildDose(scheduledAt, input));
      }
    }
    currentDate = addLocalDays(currentDate, 1);
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
