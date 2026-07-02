import { SignJWT } from "jose";
import { deviceRepository } from "../repositories/device.repository";
import { familyRepository } from "../repositories/family.repository";
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from "../errors/AppError";
import { DeviceConnectionType } from "../types";

const secret = new TextEncoder().encode(process.env.SESSION_SECRET || "change-me-in-production");

async function assertFamilyMember(userId: string) {
  const membership = await familyRepository.getMembershipByUserId(userId);
  if (!membership) throw new ForbiddenError("You are not a member of any family");
  return membership;
}

async function assertDeviceInFamily(deviceId: string, familyId: string) {
  const device = await deviceRepository.findById(deviceId);
  if (!device || device.status === "deleted") throw new NotFoundError("Device not found");
  if (device.familyId !== familyId) throw new ForbiddenError("Device does not belong to your family");
  return device;
}

export const deviceService = {
  async listDevices(userId: string) {
    const membership = await assertFamilyMember(userId);
    return deviceRepository.findByFamily(membership.familyId);
  },

  async generatePairingToken(userId: string) {
    const membership = await assertFamilyMember(userId);
    const token = await new SignJWT({ familyId: membership.familyId })
      .setProtectedHeader({ alg: "HS256" })
      .setIssuedAt()
      .setExpirationTime("10m")
      .sign(secret);
    return { token, expiresInSeconds: 600 };
  },

  async registerDevice(
    userId: string,
    data: {
      hardwareId: string;
      name: string;
      firmwareVersion?: string;
      connectionType?: DeviceConnectionType;
    }
  ) {
    if (!data.hardwareId) throw new BadRequestError("hardwareId is required");
    if (!data.name) throw new BadRequestError("name is required");

    const membership = await assertFamilyMember(userId);

    const existing = await deviceRepository.findByHardwareId(data.hardwareId);
    if (existing) throw new ConflictError("A device with this hardware ID is already registered");

    return deviceRepository.create({
      familyId: membership.familyId,
      name: data.name,
      hardwareId: data.hardwareId,
      firmwareVersion: data.firmwareVersion,
      connectionType: data.connectionType ?? "bluetooth",
    });
  },

  async updateDevice(
    userId: string,
    deviceId: string,
    data: { name?: string; status?: "active" | "disabled" }
  ) {
    if (!data.name && !data.status) throw new BadRequestError("Provide name or status to update");

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
};
