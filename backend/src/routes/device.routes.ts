import { Router } from "express";
import {
  listDevices,
  createPairingToken,
  registerDevice,
  updateDevice,
  deleteDevice,
  recordDeviceHeartbeat,
  ingestDeviceEvent,
} from "../controllers/device.controller";
import { authenticate, authenticateDevice } from "../middleware/auth.middleware";

const router = Router();

router.post("/register", registerDevice);
router.get("/", authenticate, listDevices);
router.post("/pairing-token", authenticate, createPairingToken);
router.patch("/:id", authenticate, updateDevice);
router.delete("/:id", authenticate, deleteDevice);
router.post("/:id/heartbeat", authenticateDevice, recordDeviceHeartbeat);
router.post("/:id/events", authenticateDevice, ingestDeviceEvent);

export default router;
