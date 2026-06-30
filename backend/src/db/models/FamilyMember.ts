import {
  Model,
  DataTypes,
  Sequelize,
  InferAttributes,
  InferCreationAttributes,
  CreationOptional,
} from "sequelize";
import { FamilyMemberRole } from "../../types";

class FamilyMember extends Model<
  InferAttributes<FamilyMember>,
  InferCreationAttributes<FamilyMember>
> {
  declare id: CreationOptional<string>;
  declare userId: string;
  declare familyId: string;
  declare role: CreationOptional<FamilyMemberRole>;
  declare joinedAt: CreationOptional<Date>;

  static initModel(sequelize: Sequelize): typeof FamilyMember {
    FamilyMember.init(
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
        familyId: {
          type: DataTypes.UUID,
          allowNull: false,
          references: { model: "families", key: "id" },
        },
        role: {
          type: DataTypes.ENUM("owner", "admin", "member"),
          allowNull: false,
          defaultValue: "member",
        },
        joinedAt: { type: DataTypes.DATE, allowNull: false },
      },
      { sequelize, tableName: "family_members", underscored: true, timestamps: false }
    );
    return FamilyMember;
  }
}

export { FamilyMember };
