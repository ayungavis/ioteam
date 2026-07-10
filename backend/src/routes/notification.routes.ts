import { Router } from "express";
import {
  registerPushToken,
  sendTestNotification,
  unregisterPushToken,
} from "../controllers/notification.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/tokens", registerPushToken);
router.delete("/tokens", unregisterPushToken);
router.post("/send-test", sendTestNotification);

export default router;
