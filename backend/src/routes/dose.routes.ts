import { Router } from "express";
import { markTaken, markSkipped, confirmDose } from "../controllers/dose.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/:id/mark-taken", markTaken);
router.post("/:id/mark-skipped", markSkipped);
router.post("/:id/confirm", confirmDose);

export default router;
