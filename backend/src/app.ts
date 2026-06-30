import express from "express";
import cors from "cors";
import helmet from "helmet";

import authRoutes from "./routes/auth.routes";
import userRoutes from "./routes/user.routes";
import familyRoutes from "./routes/family.routes";
import deviceRoutes from "./routes/device.routes";
import medicineRoutes from "./routes/medicine.routes";
import doseRoutes from "./routes/dose.routes";
import { errorHandler } from "./middleware/error.middleware";

const app = express();

// Use Helmet to set various HTTP headers for security
app.use(helmet());
// Enable CORS for all routes
app.use(cors());
// Parse incoming JSON requests
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ success: true, message: "DoseLatch API is running" });
});

app.use("/auth", authRoutes);
app.use("/", userRoutes);
app.use("/families", familyRoutes);
app.use("/devices", deviceRoutes);
app.use("/medicines", medicineRoutes);
app.use("/doses", doseRoutes);

app.use(errorHandler);

export default app;
