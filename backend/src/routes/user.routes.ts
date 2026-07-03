import { Router } from "express";
import {
  getMe,
  updateMe,
  deleteMe,
  completeOnboarding,
} from "../controllers/user.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.get("/me", getMe);
router.patch("/me", updateMe);
router.delete("/me", deleteMe);
router.post("/onboarding/complete", completeOnboarding);

export default router;
