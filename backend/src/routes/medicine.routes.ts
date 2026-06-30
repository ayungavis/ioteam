import { Router } from "express";
import {
  listMedicines,
  previewDoses,
  createMedicine,
  getMedicine,
  updateMedicine,
  reschedulePreview,
  reschedule,
  deleteMedicine,
} from "../controllers/medicine.controller";
import { listDoses } from "../controllers/dose.controller";
import { authenticate } from "../middleware/auth.middleware";

const router = Router();

router.use(authenticate);

router.get("/", listMedicines);
router.post("/preview-doses", previewDoses);
router.post("/", createMedicine);
router.get("/:id", getMedicine);
router.patch("/:id", updateMedicine);
router.post("/:id/reschedule-preview", reschedulePreview);
router.post("/:id/reschedule", reschedule);
router.delete("/:id", deleteMedicine);
router.get("/:id/doses", listDoses);

export default router;
