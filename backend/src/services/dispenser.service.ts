import { DoseTransitionKind } from "../types";

// ponytail: a cloud process cannot reach a BLE/Matter/HomeKit dispenser — the
// device is on local radio, not a cloud push channel. The real path is a local
// bridge (the phone app or an Apple Home hub) relaying the command. Until that
// exists this is a logged no-op; swap in the outbound command path later.
export const dispenserService = {
  async notify(deviceId: string | null, kind: DoseTransitionKind, doseId: string): Promise<void> {
    if (!deviceId) return;
    console.log(`[dispenser] would signal device ${deviceId} for dose ${doseId} (${kind}) — no bridge yet`);
  },
};
