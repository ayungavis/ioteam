import Domain
import SwiftUI

@Observable
final class MedicineDetailViewModel {
    enum Mode {
        case add
        case edit(Medicine)
    }

    var mode: Mode

    // Add mode form fields
    var medicineName = ""
    var selectedDeviceName = ""
    var quantity = 1
    var frequency: MedicineFrequency = .daily
    var dailyTimes: [Date] = [Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!]
    var weeklyDays: Set<String> = ["Monday"]
    var weeklyTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0))!
    var hourlyInterval = 8
    var graceBeforeMinutes = 15
    var graceAfterMinutes = 30
    var startDate = Date()

    // Edit mode data
    var doses: [Dose] = []
    var doseFilter: DoseFilter = .upcoming

    var isDeleteConfirmed = false

    init(mode: Mode) {
        self.mode = mode
        if case .edit(let medicine) = mode {
            self.medicineName = medicine.name
            self.selectedDeviceName = medicine.linkedDeviceName ?? ""
            self.quantity = medicine.remainingQuantity
            self.frequency = medicine.frequency
            self.graceBeforeMinutes = medicine.graceBeforeMinutes
            self.graceAfterMinutes = medicine.graceAfterMinutes
            loadMockDoses(for: medicine)
        }
    }

    var medicine: Medicine? {
        if case .edit(let medicine) = mode { return medicine }
        return nil
    }

    var filteredDoses: [Dose] {
        switch doseFilter {
        case .upcoming:
            return doses.filter { $0.status == .pending || $0.status == .due }
        case .taken:
            return doses.filter { $0.status == .taken }
        case .missed:
            return doses.filter { $0.status == .missed }
        case .needsConfirmation:
            return doses.filter { $0.status == .needsConfirmation }
        }
    }

    var canSave: Bool {
        !medicineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity > 0
            && !selectedDeviceName.isEmpty
    }

    var scheduleSummary: String {
        if case .edit(let medicine) = mode { return medicine.scheduleTimesText }
        switch frequency {
        case .daily:
            return dailyTimes.map { $0.formatted(date: .omitted, time: .shortened) }.joined(separator: ", ")
        case .weekly:
            let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
            let selected = days.filter { weeklyDays.contains($0) }.joined(separator: ", ")
            return "\(selected) at \(weeklyTime.formatted(date: .omitted, time: .shortened))"
        case .hourly:
            return "Every \(hourlyInterval) hours"
        }
    }

    private func loadMockDoses(for medicine: Medicine) {
        let calendar = Calendar.current
        let now = Date()
        let medID = medicine.id

        doses = [
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: 2, to: now)!, status: .pending),
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: 5, to: now)!, status: .pending),
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: -3, to: now)!, actualTakenAt: calendar.date(byAdding: .hour, value: -3, to: now), status: .taken),
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: -8, to: now)!, actualTakenAt: calendar.date(byAdding: .hour, value: -8, to: now), status: .taken),
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: -14, to: now)!, status: .missed),
            Dose(id: UUID(), medicineID: medID, scheduledAt: calendar.date(byAdding: .hour, value: -20, to: now)!, actualTakenAt: calendar.date(byAdding: .hour, value: -20, to: now), status: .needsConfirmation, source: .device)
        ]
    }
}

enum DoseFilter: String, CaseIterable, Identifiable {
    case upcoming
    case taken
    case missed
    case needsConfirmation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .taken: return "Taken"
        case .missed: return "Missed"
        case .needsConfirmation: return "Confirm"
        }
    }
}
