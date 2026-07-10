import { Device, sequelize } from "../db";
import {
  BadRequestError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
} from "../errors/AppError";
import { deviceRepository } from "../repositories/device.repository";
import { doseRepository } from "../repositories/dose.repository";
import { familyRepository } from "../repositories/family.repository";
import {
  DeviceConnectionState,
  DeviceConnectionType,
  DeviceEventType,
} from "../types";
import { shouldNotify } from "./notification-cooldown";
import { notificationService } from "./notification.service";
import { tokenService } from "./token.service";

// Reed-switch bounce can fire multiple times per physical open; drop near-duplicates.
const DEBOUNCE_MS = 3000;
export const DEVICE_ONLINE_GRACE_MS = 90_000;

export type PublicDevice = {
  id: string;
  familyId: string;
  name: string;
  hardwareId: string;
  connectionType: DeviceConnectionType;
  status: string;
  firmwareVersion: string | null;
  lastSeenAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  connectionState: DeviceConnectionState;
};

export function getDeviceConnectionState(
  lastSeenAt: Date | null | undefined,
  now: Date,
): DeviceConnectionState {
  if (!lastSeenAt) {
    return "disconnected";
  }

  const ageMs = now.getTime() - lastSeenAt.getTime();
  return ageMs >= 0 && ageMs <= DEVICE_ONLINE_GRACE_MS
    ? "connected"
    : "disconnected";
}

function toPublicDevice(device: Device, now: Date): PublicDevice {
  return {
    id: device.id,
    familyId: device.familyId,
    name: device.name,
    hardwareId: device.hardwareId,
    connectionType: device.connectionType,
    status: device.status,
    firmwareVersion: device.firmwareVersion ?? null,
    lastSeenAt: device.lastSeenAt ?? null,
    createdAt: device.createdAt,
    updatedAt: device.updatedAt,
    connectionState: getDeviceConnectionState(device.lastSeenAt, now),
  };
}

// The device sends raw_payload as stringified JSON. Parse it into an object for
// the JSONB column; if it isn't valid JSON, keep the original string so no data
// is lost rather than rejecting the event.
function normalizeRawPayload(raw?: string | null): object | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed !== null && typeof parsed === "object"
      ? parsed
      : { value: parsed };
  } catch {
    return { raw };
  }
}

// Push for a recorded `open`. Best-effort: the event row is already committed, so a
// dead APNS must never fail the device's POST.
//
// `eventTime` is the device clock (correlation), `now` is the server clock (cooldown).
// They are not interchangeable — a drifting RTC must not be able to bypass the cooldown.
async function notifyOpen(device: Device, eventTime: Date, now: Date): Promise<void> {
  try {
    const { insideWindow, transitionedIds } = await doseRepository.correlateOpenEvent(
      device.id,
      eventTime,
    );

    // A dose transitions at most once, ever (the UPDATE is status-guarded), so this
    // push cannot repeat. Deliberately not cooldown-gated: one open on a box holding
    // two medicines with overlapping windows must send both confirmations.
    if (transitionedIds.length > 0) {
      await notificationService.notifyDoseTransition(transitionedIds, "needs_confirmation");
      return;
    }

    // Opened inside a window, but nothing transitioned — the dose is already
    // needs_confirmation (or taken/missed). Expected, and already notified. Silent.
    if (insideWindow) return;

    // Opened with nothing scheduled. No dose to dedupe against, so throttle by device.
    if (!shouldNotify(`box_opened:${device.id}`, now.getTime())) return;
    await notificationService.notifyBoxOpened(device.familyId, device.id, device.name);
  } catch (err) {
    console.error(`[device-event] notify failed for device ${device.id}:`, err);
  }
}

async function assertFamilyMember(userId: string) {
  const membership = await familyRepository.getMembershipByUserId(userId);
  if (!membership)
    throw new ForbiddenError("You are not a member of any family");
  return membership;
}

async function assertDeviceInFamily(deviceId: string, familyId: string) {
  const device = await deviceRepository.findById(deviceId);
  if (!device || device.status === "deleted")
    throw new NotFoundError("Device not found");
  if (device.familyId !== familyId)
    throw new ForbiddenError("Device does not belong to your family");
  return device;
}

export const deviceService = {
  async listDevices(userId: string) {
    const membership = await assertFamilyMember(userId);
    const devices = await deviceRepository.findByFamily(membership.familyId);
    const now = new Date();
    return devices.map((device) => toPublicDevice(device, now));
  },

  async generatePairingToken(userId: string) {
    const membership = await assertFamilyMember(userId);
    const token = await tokenService.generatePairingToken(membership.familyId);
    return { token, expiresInSeconds: 600 };
  },

  async registerDevice(data: {
    pairingToken: string;
    hardwareId: string;
    name: string;
    firmwareVersion?: string;
    connectionType?: DeviceConnectionType;
  }) {
    if (!data.pairingToken) {
      throw new BadRequestError("pairingToken is required");
    }
    if (!data.hardwareId) throw new BadRequestError("hardwareId is required");
    if (!data.name) throw new BadRequestError("name is required");

    let pairing;
    try {
      pairing = await tokenService.verifyPairingToken(data.pairingToken);
    } catch {
      throw new UnauthorizedError("Invalid or expired pairing token");
    }

    let device: Device | undefined = undefined;
    let deviceToken: string | undefined = undefined;

    return sequelize.transaction(async (tx) => {
      const existing = await deviceRepository.findByHardwareId(data.hardwareId);
      if (existing) {
        if (existing.familyId !== pairing.familyId) {
          throw new ForbiddenError("Device is already registered to another family");
        }

        deviceToken = await tokenService.generateDeviceToken(existing.id);
        device = await deviceRepository.update(
          existing.id,
          {
            name: data.name,
            status: "active",
            deviceTokenHash: tokenService.hash(deviceToken),
          },
          tx,
        );
      } else {
        device = await deviceRepository.create(
          {
            familyId: pairing.familyId,
            name: data.name,
            hardwareId: data.hardwareId,
            firmwareVersion: data.firmwareVersion,
            connectionType: data.connectionType ?? "bluetooth",
          },
          tx,
        );

        deviceToken = await tokenService.generateDeviceToken(device.id);
        device = await deviceRepository.update(
          device.id,
          {
            deviceTokenHash: tokenService.hash(deviceToken),
          },
          tx,
        );
      }

      if (!deviceToken) {
        throw new BadRequestError(
          "Device token is failed to generate, please try again",
        );
      }

      return {
        device: toPublicDevice(device, new Date()),
        deviceToken,
      };
    });
  },

  async updateDevice(
    userId: string,
    deviceId: string,
    data: { name?: string; status?: "active" | "disabled" },
  ) {
    if (!data.name && !data.status)
      throw new BadRequestError("Provide name or status to update");

    const membership = await assertFamilyMember(userId);
    const device = await assertDeviceInFamily(deviceId, membership.familyId);

    if (data.status && data.status !== "active" && data.status !== "disabled") {
      throw new BadRequestError("status must be active or disabled");
    }

    const updated = await deviceRepository.update(device.id, {
      ...(data.name && { name: data.name }),
      ...(data.status && { status: data.status }),
    });

    return toPublicDevice(updated ?? device, new Date());
  },

  async deleteDevice(userId: string, deviceId: string) {
    const membership = await assertFamilyMember(userId);
    await assertDeviceInFamily(deviceId, membership.familyId);
    await deviceRepository.softDelete(deviceId);
  },

  async recordHeartbeat(
    authenticatedDeviceId: string,
    deviceId: string,
    data: { firmwareVersion?: string },
  ) {
    if (authenticatedDeviceId !== deviceId) {
      throw new ForbiddenError(
        "Device token does not match the requested device",
      );
    }

    const device = await deviceRepository.findById(deviceId);
    if (!device || device.status === "deleted") {
      throw new NotFoundError("Device not found");
    }

    const updated = await deviceRepository.update(deviceId, {
      lastSeenAt: new Date(),
      ...(data.firmwareVersion
        ? { firmwareVersion: data.firmwareVersion }
        : {}),
    });

    return toPublicDevice(updated ?? device, new Date());
  },

  // Ingests a reed-switch event from an ESP32: debounces, stores the raw event,
  // refreshes device liveness, then correlates an `open` to its dose window and pushes.
  async ingestDeviceEvent(
    authenticatedDeviceId: string,
    deviceId: string,
    data: {
      eventType: string;
      deviceTimestamp: string;
      firmwareVersion?: string;
      rawPayload?: string;
    },
  ) {
    if (authenticatedDeviceId !== deviceId) {
      throw new ForbiddenError(
        "Device token does not match the requested device",
      );
    }

    if (data.eventType !== "open" && data.eventType !== "close") {
      throw new BadRequestError("eventType must be 'open' or 'close'");
    }
    const eventType = data.eventType as DeviceEventType;

    const eventTime = new Date(data.deviceTimestamp);
    if (Number.isNaN(eventTime.getTime())) {
      throw new BadRequestError("deviceTimestamp is not a valid date");
    }

    const device = await deviceRepository.findById(deviceId);
    if (!device || device.status === "deleted") {
      throw new NotFoundError("Device not found");
    }

    const now = new Date();

    // EVT-010: ignore events from disabled devices — no event stored.
    if (device.status === "disabled") {
      return { status: "ignored_disabled" as const, event: null };
    }

    // EVT-008: debounce reed bounce — drop a same-type event within the window.
    const latest = await deviceRepository.findLatestEvent(deviceId, eventType);
    if (
      latest &&
      Math.abs(eventTime.getTime() - latest.deviceTimestamp.getTime()) <
        DEBOUNCE_MS
    ) {
      return { status: "debounced" as const, event: null };
    }

    // Record the raw event (EVT-002/003) and refresh device liveness.
    const event = await deviceRepository.createEvent({
      deviceId,
      eventType,
      deviceTimestamp: eventTime,
      serverReceivedAt: now,
      firmwareVersion: data.firmwareVersion ?? null,
      rawPayload: normalizeRawPayload(data.rawPayload),
    });
    await deviceRepository.update(deviceId, {
      lastSeenAt: now,
      ...(data.firmwareVersion
        ? { firmwareVersion: data.firmwareVersion }
        : {}),
    });

    // Correlate + push. `close` has no consumer yet.
    if (eventType === "open") {
      await notifyOpen(device, eventTime, now);
    }

    return { status: "recorded" as const, event };
  },
};
