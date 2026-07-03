import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { DoseStatus, TakenSource } from "../../types";

class Dose extends Model<
  InferAttributes<Dose>,
  InferCreationAttributes<Dose>
> {
  declare id: CreationOptional<string>;
  declare scheduleId: string;
  declare medicineId: string;
  declare scheduledAt: Date;
  declare windowStartAt: Date;
  declare windowEndAt: Date;
  declare doseAmount: CreationOptional<number>;
  declare status: CreationOptional<DoseStatus>;
  declare actualTakenAt: CreationOptional<Date | null>;
  declare takenSource: CreationOptional<TakenSource | null>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof Dose {
    Dose.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        scheduleId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "schedules", key: "id" },
        },
        medicineId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "medicines", key: "id" },
        },
        scheduledAt: { type: DataTypes.DATE, allowNull: false },
        windowStartAt: { type: DataTypes.DATE, allowNull: false },
        windowEndAt: { type: DataTypes.DATE, allowNull: false },
        doseAmount: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 1,
        },
        status: {
          type: DataTypes.ENUM(
            "pending",
            "due",
            "taken",
            "missed",
            "skipped",
            "needs_confirmation",
            "disabled"
          ),
          allowNull: false,
          defaultValue: "pending",
        },
        actualTakenAt: { type: DataTypes.DATE, allowNull: true },
        takenSource: {
          type: DataTypes.ENUM("device_event", "manual"),
          allowNull: true,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "doses", underscored: true }
    );
    return Dose;
  }
}

export { Dose };
