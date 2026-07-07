import { Op, Transaction } from "sequelize";
import { Device } from "../db/models/Device";
import { DeviceEvent } from "../db/models/DeviceEvent";
import { DeviceConnectionType, DeviceEventType } from "../types";

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
    deviceTokenHash?: string | null;
  }) {
    return Device.create(data);
  },

  async update(
    id: string,
    data: Partial<Pick<Device, "name" | "status" | "firmwareVersion" | "lastSeenAt" | "deviceTokenHash">>,
    transaction?: Transaction
  ) {
    const [, rows] = await Device.update(data, {
      where: { id },
      returning: true,
      transaction,
    });
    return rows[0] ?? null;
  },

  async softDelete(id: string) {
    const [count] = await Device.update({ status: "deleted" }, { where: { id } });
    return count > 0;
  },

  createEvent(
    data: {
      deviceId: string;
      eventType: DeviceEventType;
      deviceTimestamp: Date;
      serverReceivedAt: Date;
      firmwareVersion?: string | null;
      rawPayload?: object | null;
    },
    transaction?: Transaction
  ) {
    return DeviceEvent.create(data, { transaction });
  },

  // Most recent event of the same type for a device — used to debounce reed bounce.
  findLatestEvent(deviceId: string, eventType: DeviceEventType) {
    return DeviceEvent.findOne({
      where: { deviceId, eventType },
      order: [["deviceTimestamp", "DESC"]],
    });
  },
};
