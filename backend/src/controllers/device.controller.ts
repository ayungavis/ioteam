import { Response } from "express";
import { AuthenticatedRequest } from "../types";
import { deviceService } from "../services/device.service";
import { DeviceConnectionType } from "../types";

// GET /devices
export async function listDevices(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const devices = await deviceService.listDevices(req.userId ?? "");
  res.json({ success: true, data: devices });
}

// POST /devices/pairing-token
export async function createPairingToken(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const result = await deviceService.generatePairingToken(req.userId ?? "");
  res.json({ success: true, data: result });
}

// POST /devices/register
export async function registerDevice(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const { pairingToken, hardwareId, name, firmwareVersion, connectionType } = req.body as {
    pairingToken: string;
    hardwareId: string;
    name: string;
    firmwareVersion?: string;
    connectionType?: DeviceConnectionType;
  };

  const result = await deviceService.registerDevice({
    pairingToken,
    hardwareId,
    name,
    firmwareVersion,
    connectionType,
  });

  res.status(201).json({ success: true, data: result });
}

// PATCH /devices/:id
export async function updateDevice(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const { id } = req.params as { id: string };
  const { name, status } = req.body as {
    name?: string;
    status?: "active" | "disabled";
  };

  const device = await deviceService.updateDevice(req.userId ?? "", id, {
    name,
    status,
  });
  res.json({ success: true, data: device });
}

// DELETE /devices/:id
export async function deleteDevice(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const { id } = req.params as { id: string };
  await deviceService.deleteDevice(req.userId ?? "", id);
  res.json({ success: true });
}

// POST /devices/:id/events
// Ingests a reed-switch open/close event from the ESP32.
export async function ingestDeviceEvent(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const { id } = req.params as { id: string };
  const { eventType, deviceTimestamp, firmwareVersion, raw_payload } =
    req.body as {
      eventType: string;
      deviceTimestamp: string;
      firmwareVersion?: string;
      // Stringified JSON from the device — parsed to an object in the service.
      raw_payload?: string;
    };

  const result = await deviceService.ingestDeviceEvent(req.deviceId ?? "", id, {
    eventType,
    deviceTimestamp,
    firmwareVersion,
    rawPayload: raw_payload,
  });

  res.json({ success: true, data: result });
}
