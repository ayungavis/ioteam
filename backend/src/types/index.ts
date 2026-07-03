import { Request } from "express";

// Alias for route handlers that require authentication.
// userId is guaranteed present after the authenticate middleware runs.
export type AuthenticatedRequest = Request;

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
