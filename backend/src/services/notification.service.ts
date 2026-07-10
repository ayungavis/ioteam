import { DoseTransitionKind, NotificationPayload } from "../types";
import { doseRepository } from "../repositories/dose.repository";
import { familyRepository } from "../repositories/family.repository";
import { pushTokenRepository } from "../repositories/pushToken.repository";
import { apnsService } from "./apns.service";
import { dispenserService } from "./dispenser.service";

function buildPayload(kind: DoseTransitionKind, medicineName: string, doseId: string): NotificationPayload {
  const copy: Record<DoseTransitionKind, { title: string; body: string }> = {
    due: { title: "Time for your medication", body: `Take ${medicineName} now.` },
    missed: { title: "Dose missed", body: `${medicineName} was not taken in time.` },
    needs_confirmation: {
      title: "Confirm medication",
      body: `Did you take ${medicineName}? Please confirm.`,
    },
  };
  return { ...copy[kind], data: { doseId, kind } };
}

// APNS tokens of every member of the given families, keyed by family id.
async function tokensByFamily(familyIds: string[]): Promise<Map<string, string[]>> {
  const userIdsByFamily = await familyRepository.getMemberUserIds(familyIds);
  const allUserIds = [...new Set([...userIdsByFamily.values()].flat())];
  const tokens = await pushTokenRepository.findByUserIds(allUserIds);

  const tokensByUser = new Map<string, string[]>();
  for (const t of tokens) {
    const list = tokensByUser.get(t.userId) ?? [];
    list.push(t.token);
    tokensByUser.set(t.userId, list);
  }

  const byFamily = new Map<string, string[]>();
  for (const [familyId, userIds] of userIdsByFamily) {
    byFamily.set(
      familyId,
      userIds.flatMap((userId) => tokensByUser.get(userId) ?? [])
    );
  }
  return byFamily;
}

export const notificationService = {
  // Fan a dose transition out to every family member (APNS) and the dispenser.
  // Called once per dose per transition — callers only hand us rows that just
  // changed state, so there is no re-notify. ponytail: at-most-once — status is
  // already committed, so a crash here drops the push; upgrade to an outbox if
  // that loss becomes unacceptable for `missed` alerts.
  async notifyDoseTransition(doseIds: string[], kind: DoseTransitionKind): Promise<void> {
    if (doseIds.length === 0) return;

    const doses = await doseRepository.findByIdsWithMedicine(doseIds);
    const withMedicine = doses.filter((d) => d.medicine);
    if (withMedicine.length === 0) return;

    const byFamily = await tokensByFamily([
      ...new Set(withMedicine.map((d) => d.medicine!.familyId)),
    ]);

    for (const dose of withMedicine) {
      const medicine = dose.medicine!;
      const recipients = byFamily.get(medicine.familyId) ?? [];
      const payload = buildPayload(kind, medicine.name, dose.id);

      await Promise.all([
        apnsService.sendToTokens(recipients, payload),
        dispenserService.notify(medicine.deviceId, kind, dose.id),
      ]);
    }
  },

  // The box was opened with no dose window open — nothing was scheduled. Device-
  // scoped, so there is no dose to dedupe against; the caller rate-limits this
  // with the per-device notification cooldown.
  async notifyBoxOpened(familyId: string, deviceId: string, deviceName: string): Promise<void> {
    const recipients = (await tokensByFamily([familyId])).get(familyId) ?? [];
    if (recipients.length === 0) return;

    await apnsService.sendToTokens(recipients, {
      title: "Pill box opened",
      body: `${deviceName} was opened.`,
      data: { deviceId, kind: "box_opened" },
    });
  },
};
