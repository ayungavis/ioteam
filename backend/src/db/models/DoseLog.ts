import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { DoseLogEventType } from "../../types";

class DoseLog extends Model<
  InferAttributes<DoseLog>,
  InferCreationAttributes<DoseLog>
> {
  declare id: CreationOptional<string>;
  declare doseId: string;
  declare userId: string | null;
  declare eventType: DoseLogEventType;
  declare source: "device_event" | "manual" | "system";
  declare metadata: CreationOptional<object | null>;
  declare createdAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof DoseLog {
    DoseLog.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        doseId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "doses", key: "id" },
        },
        userId: {
          type: DataTypes.UUID,
          allowNull: true,
          references: { model: "users", key: "id" },
        },
        eventType: {
          type: DataTypes.ENUM("taken", "missed", "skipped", "confirmed", "rejected"),
          allowNull: false,
        },
        source: {
          type: DataTypes.ENUM("device_event", "manual", "system"),
          allowNull: false,
        },
        metadata: { type: DataTypes.JSONB, allowNull: true },
        createdAt: DataTypes.DATE,
      },
      { sequelize, tableName: "dose_logs", underscored: true, updatedAt: false }
    );
    return DoseLog;
  }
}

export { DoseLog };
