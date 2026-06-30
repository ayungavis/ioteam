import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { DeviceStatus, DeviceConnectionType } from "../../types";

class Device extends Model<
  InferAttributes<Device>,
  InferCreationAttributes<Device>
> {
  declare id: CreationOptional<string>;
  declare familyId: string;
  declare name: string;
  declare hardwareId: string;
  declare connectionType: CreationOptional<DeviceConnectionType>;
  declare status: CreationOptional<DeviceStatus>;
  declare firmwareVersion: CreationOptional<string | null>;
  declare lastSeenAt: CreationOptional<Date | null>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof Device {
    Device.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        familyId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "families", key: "id" },
        },
        name: { type: DataTypes.STRING, allowNull: false },
        hardwareId: { type: DataTypes.STRING, allowNull: false, unique: true },
        connectionType: {
          type: DataTypes.ENUM("bluetooth", "matter", "homekit"),
          allowNull: false,
          defaultValue: "bluetooth",
        },
        status: {
          type: DataTypes.ENUM("active", "disabled", "deleted"),
          allowNull: false,
          defaultValue: "active",
        },
        firmwareVersion: { type: DataTypes.STRING, allowNull: true },
        lastSeenAt: { type: DataTypes.DATE, allowNull: true },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "devices", underscored: true }
    );
    return Device;
  }
}

export { Device };
