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

export const notificationService = {
  // Fan a dose transition out to every family member (APNS) and the dispenser.
  // Called once per dose per transition — the sweep only hands us rows that just
  // changed state, so there is no re-notify. ponytail: at-most-once — status is
  // already committed, so a crash here drops the push; upgrade to an outbox if
  // that loss becomes unacceptable for `missed` alerts.
  async notifyDoseTransition(doseIds: string[], kind: DoseTransitionKind): Promise<void> {
    if (doseIds.length === 0) return;

    const doses = await doseRepository.findByIdsWithMedicine(doseIds);
    const withMedicine = doses.filter((d) => d.medicine);
    if (withMedicine.length === 0) return;

    const familyIds = [...new Set(withMedicine.map((d) => d.medicine!.familyId))];
    const userIdsByFamily = await familyRepository.getMemberUserIds(familyIds);
    const allUserIds = [...new Set([...userIdsByFamily.values()].flat())];
    const tokens = await pushTokenRepository.findByUserIds(allUserIds);

    const tokensByUser = new Map<string, string[]>();
    for (const t of tokens) {
      const list = tokensByUser.get(t.userId) ?? [];
      list.push(t.token);
      tokensByUser.set(t.userId, list);
    }

    for (const dose of withMedicine) {
      const medicine = dose.medicine!;
      const recipients = (userIdsByFamily.get(medicine.familyId) ?? []).flatMap(
        (userId) => tokensByUser.get(userId) ?? []
      );
      const payload = buildPayload(kind, medicine.name, dose.id);

      await Promise.all([
        apnsService.sendToTokens(recipients, payload),
        dispenserService.notify(medicine.deviceId, kind, dose.id),
      ]);
    }
  },
};
