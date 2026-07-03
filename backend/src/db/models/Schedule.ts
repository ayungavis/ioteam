import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { FrequencyType } from "../../types";

// schedule_config shape per frequency_type:
//   daily:   { timesOfDay: string[] }           e.g. ["08:00", "13:00"]
//   weekly:  { weekdays: number[], timesOfDay: string[] }  weekdays 0=Sun..6=Sat
//   hourly:  { intervalHours: number }
export type ScheduleConfig =
  | { timesOfDay: string[] }
  | { weekdays: number[]; timesOfDay: string[] }
  | { intervalHours: number };

class Schedule extends Model<
  InferAttributes<Schedule>,
  InferCreationAttributes<Schedule>
> {
  declare id: CreationOptional<string>;
  declare medicineId: string;
  declare frequencyType: FrequencyType;
  declare scheduleConfig: ScheduleConfig;
  declare timezone: string;
  declare graceBeforeMinutes: CreationOptional<number>;
  declare graceAfterMinutes: CreationOptional<number>;
  declare startAt: Date;
  declare endAt: CreationOptional<Date | null>;
  declare status: CreationOptional<"active" | "superseded">;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof Schedule {
    Schedule.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        medicineId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "medicines", key: "id" },
        },
        frequencyType: {
          type: DataTypes.ENUM("daily", "weekly", "hourly"),
          allowNull: false,
        },
        scheduleConfig: { type: DataTypes.JSONB, allowNull: false },
        timezone: {
          type: DataTypes.STRING,
          allowNull: false,
          defaultValue: "UTC",
        },
        graceBeforeMinutes: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 0,
        },
        graceAfterMinutes: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 30,
        },
        startAt: { type: DataTypes.DATE, allowNull: false },
        endAt: { type: DataTypes.DATE, allowNull: true },
        status: {
          type: DataTypes.ENUM("active", "superseded"),
          allowNull: false,
          defaultValue: "active",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "schedules", underscored: true }
    );
    return Schedule;
  }
}

export { Schedule };
