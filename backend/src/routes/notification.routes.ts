import { Router } from "express";
import { registerPushToken } from "../controllers/notification.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/tokens", registerPushToken);

export default router;
