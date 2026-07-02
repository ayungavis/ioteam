import { Op } from "sequelize";
import { Device } from "../db/models/Device";
import { DeviceConnectionType, DeviceStatus } from "../types";

export const deviceRepository = {
  findByFamily(familyId: string) {
    return Device.findAll({
      where: { familyId, status: { [Op.ne]: "deleted" } },
      order: [["createdAt", "ASC"]],
    });
  },

  findById(id: string) {
    return Device.findByPk(id);
  },

  findByHardwareId(hardwareId: string) {
    return Device.findOne({ where: { hardwareId } });
  },

  create(data: {
    familyId: string;
    name: string;
    hardwareId: string;
    connectionType?: DeviceConnectionType;
    firmwareVersion?: string;
  }) {
    return Device.create(data);
  },

  async update(
    id: string,
    data: Partial<Pick<Device, "name" | "status" | "firmwareVersion" | "lastSeenAt">>
  ) {
    const [, rows] = await Device.update(data, {
      where: { id },
      returning: true,
    });
    return rows[0] ?? null;
  },

  async softDelete(id: string) {
    const [count] = await Device.update({ status: "deleted" }, { where: { id } });
    return count > 0;
  },
};
