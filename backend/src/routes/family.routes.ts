import { Router } from "express";
import {
  createFamily,
  joinFamily,
  getCurrentFamily,
  updateFamily,
  refreshInviteCode,
  listMembers,
  removeMember,
} from "../controllers/family.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.post("/", createFamily);
router.post("/join", joinFamily);
router.get("/current", getCurrentFamily);
router.patch("/:id", updateFamily);
router.post("/:id/invite-code", refreshInviteCode);
router.get("/:id/members", listMembers);
router.delete("/:id/members/:memberId", removeMember);

export default router;
