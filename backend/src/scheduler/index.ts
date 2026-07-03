import { doseSchedulerService } from "../services/dose-scheduler.service";

// ponytail: setInterval, no new dep — we run "every N ms", not a cron expression.
// Swap in node-cron only if calendar-style scheduling is ever needed.

const DEFAULT_INTERVAL_MS = 5 * 60 * 1000;

let timer: NodeJS.Timeout | null = null;
let isRunning = false; // reentrancy guard: skip a tick if the previous is still going.

async function tick(): Promise<void> {
  if (isRunning) {
    console.warn("[scheduler] previous tick still running — skipping");
    return;
  }
  isRunning = true;
  try {
    await doseSchedulerService.runTick();
  } finally {
    isRunning = false;
  }
}

export function startScheduler(): void {
  if (process.env.SCHEDULER_ENABLED === "false") {
    console.log("[scheduler] disabled via SCHEDULER_ENABLED=false");
    return;
  }
  if (timer) return;

  const intervalMs = Number(process.env.SCHEDULER_INTERVAL_MS) || DEFAULT_INTERVAL_MS;
  timer = setInterval(() => void tick(), intervalMs);
  console.log(`[scheduler] started, interval ${intervalMs}ms`);
}

export function stopScheduler(): void {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}
