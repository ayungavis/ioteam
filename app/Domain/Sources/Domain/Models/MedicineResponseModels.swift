import Foundation

// MARK: - Device registration

public struct DeviceRegistrationResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: RegisteredDevice
    public init(success: Bool, data: RegisteredDevice) { self.success = success; self.data = data }
}

public struct RegisteredDevice: Codable, Sendable, Equatable {
    public let id: String; public let name: String; public let hardwareId: String; public let familyId: String
    public init(id: String, name: String, hardwareId: String, familyId: String) { self.id = id; self.name = name; self.hardwareId = hardwareId; self.familyId = familyId }
}

// MARK: - Medicine list

public struct MedicineItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String; public let name: String; public let status: String
    public let totalQuantity: Int; public let remainingQuantity: Int; public let pillPerDose: Int
    public let device: MedicineDeviceSummary?; public let nextDoseAt: Date?
    public init(id: String, name: String, status: String, totalQuantity: Int, remainingQuantity: Int, pillPerDose: Int, device: MedicineDeviceSummary?, nextDoseAt: Date?) {
        self.id = id; self.name = name; self.status = status; self.totalQuantity = totalQuantity
        self.remainingQuantity = remainingQuantity; self.pillPerDose = pillPerDose; self.device = device; self.nextDoseAt = nextDoseAt
    }
}

public struct MedicineDeviceSummary: Codable, Sendable, Equatable {
    public let id: String; public let name: String; public let status: String
    public init(id: String, name: String, status: String) { self.id = id; self.name = name; self.status = status }
}

public struct MedicineListResponse: Codable, Sendable, Equatable {
    public let success: Bool; public let data: [MedicineItem]
    public init(success: Bool, data: [MedicineItem]) { self.success = success; self.data = data }
}

// MARK: - Preview doses

public struct PreviewDosesRequest: Encodable {
    public let quantity: Int; public let pillPerDose: Int; public let schedule: ScheduleInput
    public init(quantity: Int, pillPerDose: Int, schedule: ScheduleInput) { self.quantity = quantity; self.pillPerDose = pillPerDose; self.schedule = schedule }
}

public struct PreviewDosesResponse: Codable, Sendable, Equatable {
    public let success: Bool; public let data: PreviewDosesData
    public init(success: Bool, data: PreviewDosesData) { self.success = success; self.data = data }
}

public struct PreviewDosesData: Codable, Sendable, Equatable {
    public let doses: [GeneratedDose]; public let summary: DoseSummary
    public init(doses: [GeneratedDose], summary: DoseSummary) { self.doses = doses; self.summary = summary }
}

// MARK: - Create medicine

public struct CreateMedicineRequest: Encodable {
    public let name: String; public let deviceId: String; public let quantity: Int; public let pillPerDose: Int; public let schedule: ScheduleInput
    public init(name: String, deviceId: String, quantity: Int, pillPerDose: Int, schedule: ScheduleInput) {
        self.name = name; self.deviceId = deviceId; self.quantity = quantity; self.pillPerDose = pillPerDose; self.schedule = schedule
    }
}

public struct CreateMedicineResponse: Codable, Sendable, Equatable {
    public let success: Bool; public let data: CreateMedicineData
    public init(success: Bool, data: CreateMedicineData) { self.success = success; self.data = data }
}

public struct CreateMedicineData: Codable, Sendable, Equatable {
    public let medicine: MedicineItem; public let schedule: ScheduleResponse?; public let doses: [GeneratedDose]; public let summary: DoseSummary
    public init(medicine: MedicineItem, schedule: ScheduleResponse?, doses: [GeneratedDose], summary: DoseSummary) {
        self.medicine = medicine; self.schedule = schedule; self.doses = doses; self.summary = summary
    }
}

public struct ScheduleResponse: Codable, Sendable, Equatable {
    public let id: String; public let frequencyType: String; public let scheduleConfig: ScheduleConfig
    public let timezone: String; public let graceBeforeMinutes: Int; public let graceAfterMinutes: Int
    public let startAt: String; public let endAt: String?; public let status: String
    public init(id: String, frequencyType: String, scheduleConfig: ScheduleConfig, timezone: String, graceBeforeMinutes: Int, graceAfterMinutes: Int, startAt: String, endAt: String?, status: String) {
        self.id = id; self.frequencyType = frequencyType; self.scheduleConfig = scheduleConfig; self.timezone = timezone
        self.graceBeforeMinutes = graceBeforeMinutes; self.graceAfterMinutes = graceAfterMinutes; self.startAt = startAt; self.endAt = endAt; self.status = status
    }
}

// MARK: - Dose list

public struct DoseItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String; public let scheduleId: String; public let medicineId: String
    public let scheduledAt: Date; public let windowStartAt: Date; public let windowEndAt: Date
    public let doseAmount: Int; public let status: String; public let actualTakenAt: Date?; public let takenSource: String?
    public init(id: String, scheduleId: String, medicineId: String, scheduledAt: Date, windowStartAt: Date, windowEndAt: Date, doseAmount: Int, status: String, actualTakenAt: Date?, takenSource: String?) {
        self.id = id; self.scheduleId = scheduleId; self.medicineId = medicineId; self.scheduledAt = scheduledAt
        self.windowStartAt = windowStartAt; self.windowEndAt = windowEndAt; self.doseAmount = doseAmount; self.status = status; self.actualTakenAt = actualTakenAt; self.takenSource = takenSource
    }
}

public struct DoseListResponse: Codable, Sendable, Equatable {
    public let success: Bool; public let data: [DoseItem]
    public init(success: Bool, data: [DoseItem]) { self.success = success; self.data = data }
}

// MARK: - Mark taken

public struct MarkTakenData: Codable, Sendable, Equatable {
    public let dose: DoseItem; public let remainingQuantity: Int
    public init(dose: DoseItem, remainingQuantity: Int) { self.dose = dose; self.remainingQuantity = remainingQuantity }
}

public struct MarkTakenResponse: Codable, Sendable, Equatable {
    public let success: Bool; public let data: MarkTakenData
    public init(success: Bool, data: MarkTakenData) { self.success = success; self.data = data }
}
