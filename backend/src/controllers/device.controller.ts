import { Response } from "express";
import { AuthenticatedRequest } from "../types";

// GET /devices
export async function listDevices(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: return all devices for req.familyId
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /devices/pairing-token
// Creates a short-lived pairing token the ESP32 uses to register itself.
export async function createPairingToken(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  // TODO: generate pairing token, associate with req.familyId, store with expiry
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /devices/register
// Called by the ESP32 after Wi-Fi provisioning to link itself to a family.
export async function registerDevice(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { pairingToken, hardwareId, firmwareVersion } = req.body as {
    pairingToken: string;
    hardwareId: string;
    firmwareVersion: string;
  };

  if (!pairingToken || !hardwareId) {
    res
      .status(400)
      .json({ success: false, error: "pairingToken and hardwareId are required" });
    return;
  }

  // TODO: validate pairing token, create device record linked to family
  res.status(501).json({ success: false, error: "Not implemented" });
}

// PATCH /devices/:id
export async function updateDevice(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { name, status } = req.body as { name?: string; status?: string };

  // TODO: rename or enable/disable device, verify family membership
  res.status(501).json({ success: false, error: "Not implemented" });
}

// DELETE /devices/:id
export async function deleteDevice(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;

  // TODO: soft-delete device, unlink from active medicines, verify family membership
  res.status(501).json({ success: false, error: "Not implemented" });
}

// POST /devices/:id/events
// Ingests reed switch open/close events from the ESP32.
export async function ingestDeviceEvent(
  req: AuthenticatedRequest,
  res: Response
): Promise<void> {
  const { id } = req.params;
  const { eventType, deviceTimestamp, firmwareVersion } = req.body as {
    eventType: "open" | "close";
    deviceTimestamp: string;
    firmwareVersion?: string;
  };

  if (!eventType || !deviceTimestamp) {
    res
      .status(400)
      .json({ success: false, error: "eventType and deviceTimestamp are required" });
    return;
  }

  // TODO: validate device, debounce, store event, match to active dose windows
  res.status(501).json({ success: false, error: "Not implemented" });
}
