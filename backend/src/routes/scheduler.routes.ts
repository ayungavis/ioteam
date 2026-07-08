import { Router } from "express";
import { triggerDoseTick } from "../controllers/scheduler.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/tick", triggerDoseTick);

export default router;
