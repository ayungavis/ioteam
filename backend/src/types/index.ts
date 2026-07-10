import { Request } from "express";

// Alias for route handlers that require authentication.
// userId is guaranteed present after the authenticate middleware runs.
export type AuthenticatedRequest = Request;
export type AuthenticatedDeviceRequest = Request & { deviceId: string };

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

export type DoseStatus =
  | "pending"
  | "due"
  | "taken"
  | "missed"
  | "skipped"
  | "needs_confirmation"
  | "disabled";

export type FrequencyType = "daily" | "weekly" | "hourly";

export type DeviceStatus = "active" | "disabled" | "deleted";

export type DeviceConnectionState = "connected" | "disconnected";

export type MedicineStatus = "active" | "disabled" | "deleted";

export type FamilyMemberRole = "owner" | "admin" | "member";

export type DeviceConnectionType = "bluetooth" | "matter" | "homekit";

export type DeviceEventType = "open" | "close";

export type DoseLogEventType =
  | "taken"
  | "missed"
  | "skipped"
  | "confirmed"
  | "rejected";

export type TakenSource = "device_event" | "manual";

export type PushTokenPlatform = "ios";

// Dose status changes the scheduler drives and notifies on.
export type DoseTransitionKind = "due" | "missed" | "needs_confirmation";

// Everything we push on. `box_opened` is device-scoped, not dose-scoped.
export type NotificationKind = DoseTransitionKind | "box_opened";

export interface NotificationPayload {
  title: string;
  body: string;
  // Extra data delivered in the APNS payload for the client to route on.
  data?: Record<string, string>;
}
