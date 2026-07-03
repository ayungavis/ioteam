import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { DeviceEventType } from "../../types";

class DeviceEvent extends Model<
  InferAttributes<DeviceEvent>,
  InferCreationAttributes<DeviceEvent>
> {
  declare id: CreationOptional<string>;
  declare deviceId: string;
  declare eventType: DeviceEventType;
  declare deviceTimestamp: Date;
  declare serverReceivedAt: CreationOptional<Date>;
  declare firmwareVersion: CreationOptional<string | null>;
  declare rawPayload: CreationOptional<object | null>;

  static initModel(sequelize: Sequelize): typeof DeviceEvent {
    DeviceEvent.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        deviceId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "devices", key: "id" },
        },
        eventType: {
          type: DataTypes.ENUM("open", "close"),
          allowNull: false,
        },
        deviceTimestamp: { type: DataTypes.DATE, allowNull: false },
        serverReceivedAt: { type: DataTypes.DATE, allowNull: false },
        firmwareVersion: { type: DataTypes.STRING, allowNull: true },
        rawPayload: { type: DataTypes.JSONB, allowNull: true },
      },
      { sequelize, tableName: "device_events", underscored: true, timestamps: false }
    );
    return DeviceEvent;
  }
}

export { DeviceEvent };
