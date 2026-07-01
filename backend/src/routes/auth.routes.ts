import { Router } from "express";
import {
  appleSignIn,
  devLogin,
  logout,
  listSessions,
  revokeSession,
} from "../controllers/auth.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.post("/apple", appleSignIn);
router.post("/logout", authenticate, logout);
router.get("/sessions", authenticate, listSessions);
router.delete("/sessions/:id", authenticate, revokeSession);

if (process.env.NODE_ENV !== "production") {
  router.post("/dev-login", devLogin);
}

export default router;
