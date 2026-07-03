import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";

class User extends Model<InferAttributes<User>, InferCreationAttributes<User>> {
  declare id: CreationOptional<string>;
  declare appleUserId: string;
  declare email: string;
  declare fullName: string;
  declare dateOfBirth: CreationOptional<string | null>;
  declare avatarUrl: CreationOptional<string | null>;
  declare onboardingCompleted: CreationOptional<boolean>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof User {
    User.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        appleUserId: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        email: { type: DataTypes.STRING, allowNull: false },
        fullName: { type: DataTypes.STRING, allowNull: false },
        dateOfBirth: { type: DataTypes.DATEONLY, allowNull: true },
        avatarUrl: { type: DataTypes.STRING, allowNull: true },
        onboardingCompleted: {
          type: DataTypes.BOOLEAN,
          allowNull: false,
          defaultValue: false,
        },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "users", underscored: true },
    );
    return User;
  }
}

export { User };
