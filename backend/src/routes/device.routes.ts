import { Router } from "express";
import {
  listDevices,
  createPairingToken,
  registerDevice,
  updateDevice,
  deleteDevice,
  ingestDeviceEvent,
} from "../controllers/device.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.get("/", listDevices);
router.post("/pairing-token", createPairingToken);
router.post("/register", registerDevice);
router.patch("/:id", updateDevice);
router.delete("/:id", deleteDevice);
router.post("/:id/events", ingestDeviceEvent);

export default router;
