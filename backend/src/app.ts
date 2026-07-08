import express from "express";
import cors from "cors";
import helmet from "helmet";
import swaggerUi from "swagger-ui-express";

import authRoutes from "./routes/auth.routes";
import userRoutes from "./routes/user.routes";
import familyRoutes from "./routes/family.routes";
import deviceRoutes from "./routes/device.routes";
import medicineRoutes from "./routes/medicine.routes";
import doseRoutes from "./routes/dose.routes";
import notificationRoutes from "./routes/notification.routes";
import { errorHandler } from "./middleware/error.middleware";
import swaggerDocument from "./docs/swagger";

const app = express();

app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ success: true, message: "DoseLatch API is running" });
});

app.use("/docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));

app.use("/auth", authRoutes);
app.use("/families", familyRoutes);
app.use("/devices", deviceRoutes);
app.use("/medicines", medicineRoutes);
app.use("/doses", doseRoutes);
app.use("/notifications", notificationRoutes);
app.use("/", userRoutes);

app.use(errorHandler);

export default app;
