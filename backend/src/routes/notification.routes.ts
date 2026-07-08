import { Router } from "express";
import { registerPushToken, sendTestNotification } from "../controllers/notification.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/tokens", registerPushToken);
router.post("/send-test", sendTestNotification);

export default router;
