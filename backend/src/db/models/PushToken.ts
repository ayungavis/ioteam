import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { PushTokenPlatform } from "../../types";

class PushToken extends Model<
  InferAttributes<PushToken>,
  InferCreationAttributes<PushToken>
> {
  declare id: CreationOptional<string>;
  declare userId: string;
  declare token: string;
  declare platform: CreationOptional<PushTokenPlatform>;
  declare lastUsedAt: CreationOptional<Date | null>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof PushToken {
    PushToken.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        userId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "users", key: "id" },
        },
        token: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        platform: {
          type: DataTypes.ENUM("ios"),
          allowNull: false,
          defaultValue: "ios",
        },
        lastUsedAt: { type: DataTypes.DATE, allowNull: true },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "push_tokens", underscored: true }
    );
    return PushToken;
  }
}

export { PushToken };
