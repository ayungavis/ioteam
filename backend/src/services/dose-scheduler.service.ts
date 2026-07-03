import { doseRepository } from "../repositories/dose.repository";
import { notificationService } from "./notification.service";

// One sweep of the dose lifecycle. Transitions run in a fixed order so an opened
// box (needs_confirmation) is claimed before the missed sweep could grab it, and
// each transition is isolated: a failure in one must not abort the others.
async function runTransition(
  name: string,
  transition: () => Promise<string[]>,
  notify?: (ids: string[]) => Promise<void>
): Promise<void> {
  try {
    const ids = await transition();
    if (ids.length === 0) return;
    console.log(`[scheduler] ${name}: ${ids.length} dose(s)`);
    if (notify) await notify(ids);
  } catch (err) {
    console.error(`[scheduler] ${name} failed:`, err);
  }
}

export const doseSchedulerService = {
  async runTick(): Promise<void> {
    const now = new Date();

    // 1. Opened-box correlation first — removes these from the missed sweep.
    await runTransition(
      "needs_confirmation",
      () => doseRepository.transitionNeedsConfirmation(now),
      (ids) => notificationService.notifyDoseTransition(ids, "needs_confirmation")
    );

    // 2. Expired windows -> missed (+ audit log).
    await runTransition(
      "missed",
      async () => {
        const ids = await doseRepository.transitionMissed(now);
        await doseRepository.logMissed(ids);
        return ids;
      },
      (ids) => notificationService.notifyDoseTransition(ids, "missed")
    );

    // 3. Open windows -> due (reminder).
    await runTransition(
      "due",
      () => doseRepository.transitionDue(now),
      (ids) => notificationService.notifyDoseTransition(ids, "due")
    );
  },
};
