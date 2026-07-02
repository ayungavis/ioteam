import Foundation

public enum MedicineStatus: String, Codable, Sendable, CaseIterable {
    case active
    case disabled
}

public enum MedicineFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case daily
    case weekly
    case hourly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .hourly: return "Hourly"
        }
    }
}

public enum DoseStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case due
    case taken
    case missed
    case skipped
    case needsConfirmation
    case disabled

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .due: return "Due"
        case .taken: return "Taken"
        case .missed: return "Missed"
        case .skipped: return "Skipped"
        case .needsConfirmation: return "Needs Confirmation"
        case .disabled: return "Disabled"
        }
    }
}

public struct Medicine: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var totalQuantity: Int
    public var remainingQuantity: Int
    public var status: MedicineStatus
    public var linkedDeviceName: String?
    public var linkedDeviceID: UUID?
    public var nextDoseTime: Date?
    public var frequency: MedicineFrequency
    public var scheduleTimesText: String
    public var graceBeforeMinutes: Int
    public var graceAfterMinutes: Int

    public init(
        id: UUID,
        name: String,
        totalQuantity: Int,
        remainingQuantity: Int,
        status: MedicineStatus,
        linkedDeviceName: String? = nil,
        linkedDeviceID: UUID? = nil,
        nextDoseTime: Date? = nil,
        frequency: MedicineFrequency,
        scheduleTimesText: String,
        graceBeforeMinutes: Int = 15,
        graceAfterMinutes: Int = 30
    ) {
        self.id = id
        self.name = name
        self.totalQuantity = totalQuantity
        self.remainingQuantity = remainingQuantity
        self.status = status
        self.linkedDeviceName = linkedDeviceName
        self.linkedDeviceID = linkedDeviceID
        self.nextDoseTime = nextDoseTime
        self.frequency = frequency
        self.scheduleTimesText = scheduleTimesText
        self.graceBeforeMinutes = graceBeforeMinutes
        self.graceAfterMinutes = graceAfterMinutes
    }
}

public struct Dose: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let medicineID: UUID
    public var scheduledAt: Date
    public var actualTakenAt: Date?
    public var status: DoseStatus
    public var source: DoseSource

    public init(
        id: UUID,
        medicineID: UUID,
        scheduledAt: Date,
        actualTakenAt: Date? = nil,
        status: DoseStatus,
        source: DoseSource = .device
    ) {
        self.id = id
        self.medicineID = medicineID
        self.scheduledAt = scheduledAt
        self.actualTakenAt = actualTakenAt
        self.status = status
        self.source = source
    }
}

public enum DoseSource: String, Codable, Sendable, CaseIterable {
    case device
    case manual

    public var displayName: String {
        switch self {
        case .device: return "Device"
        case .manual: return "Manual"
        }
    }
}
