import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { MedicineStatus } from "../../types";

class Medicine extends Model<
  InferAttributes<Medicine>,
  InferCreationAttributes<Medicine>
> {
  declare id: CreationOptional<string>;
  declare familyId: string;
  declare deviceId: string | null;
  declare name: string;
  declare totalQuantity: number;
  declare pillPerDose: CreationOptional<number>;
  declare remainingQuantity: number;
  declare status: CreationOptional<MedicineStatus>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof Medicine {
    Medicine.init(
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
        deviceId: {
          type: DataTypes.UUID,
          allowNull: true,
          references: { model: "devices", key: "id" },
        },
        name: { type: DataTypes.STRING, allowNull: false },
        totalQuantity: { type: DataTypes.INTEGER, allowNull: false },
        pillPerDose: {
          type: DataTypes.INTEGER,
          allowNull: false,
          defaultValue: 1,
        },
        remainingQuantity: { type: DataTypes.INTEGER, allowNull: false },
        status: {
          type: DataTypes.ENUM("active", "disabled", "deleted"),
          allowNull: false,
          defaultValue: "active",
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "medicines", underscored: true }
    );
    return Medicine;
  }
}

export { Medicine };
