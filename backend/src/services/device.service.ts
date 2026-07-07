import { deviceRepository } from "../repositories/device.repository";
import { familyRepository } from "../repositories/family.repository";
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
  UnauthorizedError,
} from "../errors/AppError";
import { DeviceConnectionType, DeviceEventType } from "../types";
import { tokenService } from "./token.service";

// Reed-switch bounce can fire multiple times per physical open; drop near-duplicates.
const DEBOUNCE_MS = 3000;

// The device sends raw_payload as stringified JSON. Parse it into an object for
// the JSONB column; if it isn't valid JSON, keep the original string so no data
// is lost rather than rejecting the event.
function normalizeRawPayload(raw?: string | null): object | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed !== null && typeof parsed === "object" ? parsed : { value: parsed };
  } catch {
    return { raw };
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
    return deviceRepository.findByFamily(membership.familyId);
  },

  async generatePairingToken(userId: string) {
    const membership = await assertFamilyMember(userId);
    const token = await tokenService.generatePairingToken(membership.familyId);
    return { token, expiresInSeconds: 600 };
  },

  async registerDevice(
    data: {
      pairingToken: string;
      hardwareId: string;
      name: string;
      firmwareVersion?: string;
      connectionType?: DeviceConnectionType;
    },
  ) {
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

    const existing = await deviceRepository.findByHardwareId(data.hardwareId);
    if (existing)
      throw new ConflictError(
        "A device with this hardware ID is already registered",
      );

    const device = await deviceRepository.create({
      familyId: pairing.familyId,
      name: data.name,
      hardwareId: data.hardwareId,
      firmwareVersion: data.firmwareVersion,
      connectionType: data.connectionType ?? "bluetooth",
    });

    const deviceToken = await tokenService.generateDeviceToken(device.id);
    const updated = await deviceRepository.update(device.id, {
      deviceTokenHash: tokenService.hash(deviceToken),
    });

    return {
      device: updated ?? device,
      deviceToken,
    };
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

    return updated ?? device;
  },

  async deleteDevice(userId: string, deviceId: string) {
    const membership = await assertFamilyMember(userId);
    await assertDeviceInFamily(deviceId, membership.familyId);
    await deviceRepository.softDelete(deviceId);
  },

  // Ingests a reed-switch event from an ESP32: debounces, stores the raw event, and
  // refreshes device liveness. Dose matching is intentionally not done here.
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
      throw new ForbiddenError("Device token does not match the requested device");
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
      Math.abs(eventTime.getTime() - latest.deviceTimestamp.getTime()) < DEBOUNCE_MS
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
      ...(data.firmwareVersion ? { firmwareVersion: data.firmwareVersion } : {}),
    });

    return { status: "recorded" as const, event };
  },
};
