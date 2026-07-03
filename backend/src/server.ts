import dotenv from "dotenv";
dotenv.config();

import app from "./app";
import { sequelize } from "./db";
import { startScheduler } from "./scheduler";

const PORT = process.env.PORT || 3000;

async function start() {
  await sequelize.authenticate();
  console.log("Database connected");
  startScheduler();
  app.listen(PORT, () => {
    console.log(`DoseLatch API running on port ${PORT}`);
  });
}

start().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});
