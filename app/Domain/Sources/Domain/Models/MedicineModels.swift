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
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .hourly: return String(localized: "Hourly")
        }
    }
}

public enum DoseStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case due
    case taken
    case missed
    case skipped
    case needsConfirmation = "needs_confirmation"
    case disabled

    public var displayName: String {
        switch self {
        case .pending: return String(localized: "Pending")
        case .due: return String(localized: "Due")
        case .taken: return String(localized: "Taken")
        case .missed: return String(localized: "Missed")
        case .skipped: return String(localized: "Skipped")
        case .needsConfirmation: return String(localized: "Needs Confirmation")
        case .disabled: return String(localized: "Disabled")
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

// MARK: - Backend DTOs

public enum ScheduleConfig: Codable, Sendable, Equatable {
    case daily(timesOfDay: [String])
    case weekly(weekdays: [Int], timesOfDay: [String])
    case hourly(intervalHours: Int)

    private enum CodingKeys: String, CodingKey { case timesOfDay, weekdays, intervalHours }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let times = try? container.decode([String].self, forKey: .timesOfDay), !times.isEmpty,
           try container.decodeIfPresent([Int].self, forKey: .weekdays) == nil {
            self = .daily(timesOfDay: times); return
        }
        if let wd = try? container.decode([Int].self, forKey: .weekdays),
           let times = try? container.decode([String].self, forKey: .timesOfDay) {
            self = .weekly(weekdays: wd, timesOfDay: times); return
        }
        if let interval = try? container.decode(Int.self, forKey: .intervalHours) {
            self = .hourly(intervalHours: interval); return
        }
        throw DecodingError.dataCorruptedError(forKey: .timesOfDay, in: container, debugDescription: "Unknown scheduleConfig")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily(let times): try container.encode(times, forKey: .timesOfDay)
        case .weekly(let wd, let times):
            try container.encode(wd, forKey: .weekdays)
            try container.encode(times, forKey: .timesOfDay)
        case .hourly(let interval): try container.encode(interval, forKey: .intervalHours)
        }
    }
}

public struct ScheduleInput: Codable, Sendable, Equatable {
    public let frequencyType: MedicineFrequency
    public let scheduleConfig: ScheduleConfig
    public let timezone: String
    public let graceBeforeMinutes: Int
    public let graceAfterMinutes: Int
    public let startAt: Date
    public let endAt: Date?

    public init(frequencyType: MedicineFrequency, scheduleConfig: ScheduleConfig, timezone: String, graceBeforeMinutes: Int, graceAfterMinutes: Int, startAt: Date, endAt: Date? = nil) {
        self.frequencyType = frequencyType
        self.scheduleConfig = scheduleConfig
        self.timezone = timezone
        self.graceBeforeMinutes = graceBeforeMinutes
        self.graceAfterMinutes = graceAfterMinutes
        self.startAt = startAt
        self.endAt = endAt
    }
}

public struct GeneratedDose: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let scheduledAt: Date
    public let windowStartAt: Date
    public let windowEndAt: Date
    public let doseAmount: Int

    // The backend's GeneratedDose payload carries no id (doses are not yet
    // persisted), so the id is local-only and excluded from Codable.
    private enum CodingKeys: String, CodingKey {
        case scheduledAt, windowStartAt, windowEndAt, doseAmount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.scheduledAt = try container.decode(Date.self, forKey: .scheduledAt)
        self.windowStartAt = try container.decode(Date.self, forKey: .windowStartAt)
        self.windowEndAt = try container.decode(Date.self, forKey: .windowEndAt)
        self.doseAmount = try container.decode(Int.self, forKey: .doseAmount)
    }

    public init(id: UUID = UUID(), scheduledAt: Date, windowStartAt: Date, windowEndAt: Date, doseAmount: Int) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.windowStartAt = windowStartAt
        self.windowEndAt = windowEndAt
        self.doseAmount = doseAmount
    }
}

public struct DoseSummary: Codable, Sendable, Equatable {
    public let totalDoses: Int
    public let firstDoseAt: Date?
    public let lastDoseAt: Date?
    public let pillsUsed: Int

    public init(totalDoses: Int, firstDoseAt: Date?, lastDoseAt: Date?, pillsUsed: Int) {
        self.totalDoses = totalDoses
        self.firstDoseAt = firstDoseAt
        self.lastDoseAt = lastDoseAt
        self.pillsUsed = pillsUsed
    }
}
