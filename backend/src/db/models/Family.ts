import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";

class Family extends Model<
  InferAttributes<Family>,
  InferCreationAttributes<Family>
> {
  declare id: CreationOptional<string>;
  declare name: string;
  declare inviteCode: CreationOptional<string | null>;
  declare inviteCodeExpiresAt: CreationOptional<Date | null>;
  declare createdAt: CreationOptional<Date>;
  declare updatedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof Family {
    Family.init(
      {
        id: {
          type: DataTypes.UUID,
          defaultValue: DataTypes.UUIDV4,
          primaryKey: true,
        },
        name: { type: DataTypes.STRING, allowNull: false },
        inviteCode: { type: DataTypes.STRING, allowNull: true, unique: true },
        inviteCodeExpiresAt: { type: DataTypes.DATE, allowNull: true },
        createdAt: DataTypes.DATE,
        updatedAt: DataTypes.DATE,
      },
      { sequelize, tableName: "families", underscored: true }
    );
    return Family;
  }
}

export { Family };
