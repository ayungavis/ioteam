import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";

class LoginSession extends Model<
  InferAttributes<LoginSession>,
  InferCreationAttributes<LoginSession>
> {
  declare id: CreationOptional<string>;
  declare userId: string;
  declare tokenHash: string;
  declare deviceName: CreationOptional<string | null>;
  declare ipAddress: CreationOptional<string | null>;
  declare lastActiveAt: Date;
  declare createdAt: CreationOptional<Date>;
  declare revokedAt: CreationOptional<Date | null>;

  static initModel(sequelize: Sequelize): typeof LoginSession {
    LoginSession.init(
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
        tokenHash: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        deviceName: { type: DataTypes.STRING, allowNull: true },
        ipAddress: { type: DataTypes.STRING, allowNull: true },
        lastActiveAt: { type: DataTypes.DATE, allowNull: false },
        createdAt: DataTypes.DATE,
        revokedAt: { type: DataTypes.DATE, allowNull: true },
      },
      { sequelize, tableName: "login_sessions", underscored: true, updatedAt: false }
    );
    return LoginSession;
  }
}

export { LoginSession };
