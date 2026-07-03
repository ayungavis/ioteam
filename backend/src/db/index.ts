import { Sequelize } from "sequelize";
import { User } from "./models/User";
import { Family } from "./models/Family";
import { FamilyMember } from "./models/FamilyMember";
import { Device } from "./models/Device";
import { Medicine } from "./models/Medicine";
import { Schedule } from "./models/Schedule";
import { Dose } from "./models/Dose";
import { DeviceEvent } from "./models/DeviceEvent";
import { DoseLog } from "./models/DoseLog";
import { LoginSession } from "./models/LoginSession";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) throw new Error("DATABASE_URL is not set");

export const sequelize = new Sequelize(DATABASE_URL, {
  host: "localhost",
  dialect: "postgres",
  logging: process.env.NODE_ENV === "development" ? console.log : false,
});

// Initialize all models
User.initModel(sequelize);
Family.initModel(sequelize);
FamilyMember.initModel(sequelize);
Device.initModel(sequelize);
Medicine.initModel(sequelize);
Schedule.initModel(sequelize);
Dose.initModel(sequelize);
DeviceEvent.initModel(sequelize);
DoseLog.initModel(sequelize);
LoginSession.initModel(sequelize);

// Associations
User.hasMany(FamilyMember, { foreignKey: "userId", as: "familyMemberships" });
FamilyMember.belongsTo(User, { foreignKey: "userId", as: "user" });

Family.hasMany(FamilyMember, { foreignKey: "familyId", as: "members" });
FamilyMember.belongsTo(Family, { foreignKey: "familyId", as: "family" });

Family.hasMany(Device, { foreignKey: "familyId", as: "devices" });
Device.belongsTo(Family, { foreignKey: "familyId", as: "family" });

Family.hasMany(Medicine, { foreignKey: "familyId", as: "medicines" });
Medicine.belongsTo(Family, { foreignKey: "familyId", as: "family" });

Device.hasMany(Medicine, { foreignKey: "deviceId", as: "medicines" });
Medicine.belongsTo(Device, { foreignKey: "deviceId", as: "device" });

Medicine.hasMany(Schedule, { foreignKey: "medicineId", as: "schedules" });
Schedule.belongsTo(Medicine, { foreignKey: "medicineId", as: "medicine" });

Schedule.hasMany(Dose, { foreignKey: "scheduleId", as: "doses" });
Dose.belongsTo(Schedule, { foreignKey: "scheduleId", as: "schedule" });

Medicine.hasMany(Dose, { foreignKey: "medicineId", as: "doses" });
Dose.belongsTo(Medicine, { foreignKey: "medicineId", as: "medicine" });

Device.hasMany(DeviceEvent, { foreignKey: "deviceId", as: "events" });
DeviceEvent.belongsTo(Device, { foreignKey: "deviceId", as: "device" });

Dose.hasMany(DoseLog, { foreignKey: "doseId", as: "logs" });
DoseLog.belongsTo(Dose, { foreignKey: "doseId", as: "dose" });

User.hasMany(LoginSession, { foreignKey: "userId", as: "sessions" });
LoginSession.belongsTo(User, { foreignKey: "userId", as: "user" });

export {
  User,
  Family,
  FamilyMember,
  Device,
  Medicine,
  Schedule,
  Dose,
  DeviceEvent,
  DoseLog,
  LoginSession,
};
