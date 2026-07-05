import Domain
import SwiftUI

@Observable
final class MedicineDetailViewModel {
    enum Mode: Equatable {
        case add
        case edit(medicineID: String)
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.add, .add): return true
            case (.edit(let left), .edit(let right)): return left == right
            default: return false
            }
        }
    }

    var mode: Mode
    var medicineName = ""
    var selectedDeviceName = ""
    var quantity = 1
    var frequency: MedicineFrequency = .daily
    var dailyTimes: [Date] = [Calendar.current.date(from: DateComponents(hour: 8, minute: 0))!]
    var weeklyDays: Set<String> = ["Sunday", "Saturday"]
    var weeklyTimes: [Date] = [
        Calendar.current.date(from: DateComponents(hour: 6, minute: 0))!,
        Calendar.current.date(from: DateComponents(hour: 12, minute: 0))!,
        Calendar.current.date(from: DateComponents(hour: 18, minute: 0))!
    ]
    var hourlyInterval = 8
    var graceBeforeMinutes = 15
    var graceAfterMinutes = 30
    var startDate = Date()
    var doses: [DoseItem] = []
    var doseFilter: DoseFilter = .upcoming
    var isLoadingDoses = false
    var isGeneratingPreview = false
    var alertMessage: String?

    private var previewDosesUseCase: PreviewDosesUseCase?
    private var createMedicineUseCase: CreateMedicineUseCase?
    private var getMedicineDosesUseCase: GetMedicineDosesUseCase?
    private var appSessionStore: AppSessionStore?

    init(mode: Mode, previewDosesUseCase: PreviewDosesUseCase? = nil, createMedicineUseCase: CreateMedicineUseCase? = nil, getMedicineDosesUseCase: GetMedicineDosesUseCase? = nil, appSessionStore: AppSessionStore? = nil) {
        self.mode = mode
        self.previewDosesUseCase = previewDosesUseCase
        self.createMedicineUseCase = createMedicineUseCase
        self.getMedicineDosesUseCase = getMedicineDosesUseCase
        self.appSessionStore = appSessionStore
        if case .edit(let id) = mode { loadDoses(medicineId: id) }
    }

    /// Call from onAppear to inject real use cases without replacing the entire VM
    func configure(previewDosesUseCase: PreviewDosesUseCase, createMedicineUseCase: CreateMedicineUseCase, getMedicineDosesUseCase: GetMedicineDosesUseCase, appSessionStore: AppSessionStore) {
        let needsDoseLoad = self.getMedicineDosesUseCase == nil && mode != .add
        self.previewDosesUseCase = previewDosesUseCase
        self.createMedicineUseCase = createMedicineUseCase
        self.getMedicineDosesUseCase = getMedicineDosesUseCase
        self.appSessionStore = appSessionStore
        if needsDoseLoad, case .edit(let id) = mode { loadDoses(medicineId: id) }
    }

    var canSave: Bool { !medicineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && quantity > 0 }

    var filteredDoses: [DoseItem] {
        switch doseFilter {
        case .upcoming: return doses.filter { $0.status == "pending" || $0.status == "due" }
        case .taken: return doses.filter { $0.status == "taken" }
        case .missed: return doses.filter { $0.status == "missed" }
        case .needsConfirmation: return doses.filter { $0.status == "needs_confirmation" }
        }
    }

    func loadDoses(medicineId: String) {
        guard let useCase = getMedicineDosesUseCase else { return }
        isLoadingDoses = true
        Task {
            do {
                let result = try await useCase.execute(medicineId: medicineId)
                await MainActor.run { doses = result; isLoadingDoses = false }
            } catch {
                await MainActor.run { alertMessage = error.localizedDescription; isLoadingDoses = false }
            }
        }
    }

    func previewDoses() async -> (doses: [GeneratedDose], summary: DoseSummary)? {
        guard let useCase = previewDosesUseCase else { return nil }
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }
        do {
            let data = try await useCase.execute(quantity: quantity, pillPerDose: 1, schedule: buildScheduleInput())
            return (data.doses, data.summary)
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return nil
        }
    }

    func createMedicine() async -> Bool {
        guard let useCase = createMedicineUseCase, let deviceId = appSessionStore?.deviceId else {
            await MainActor.run { alertMessage = "Device not set up. Complete family setup first." }
            return false
        }
        do {
            _ = try await useCase.execute(name: medicineName.trimmingCharacters(in: .whitespacesAndNewlines), deviceId: deviceId, quantity: quantity, schedule: buildScheduleInput())
            return true
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return false
        }
    }

    // MARK: - Schedule Builder
    private static let weekdayMap: [String: Int] = ["Sunday":0,"Monday":1,"Tuesday":2,"Wednesday":3,"Thursday":4,"Friday":5,"Saturday":6]
    private func toHHmm(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; return formatter.string(from: date) }

    func buildScheduleInput() -> ScheduleInput {
        let config: ScheduleConfig
        switch frequency {
        case .daily: config = .daily(timesOfDay: dailyTimes.map { toHHmm($0) })
        case .weekly: config = .weekly(weekdays: Self.weekdayMap.filter { weeklyDays.contains($0.key) }.values.sorted(), timesOfDay: weeklyTimes.map { toHHmm($0) })
        case .hourly: config = .hourly(intervalHours: hourlyInterval)
        }
        return ScheduleInput(frequencyType: frequency, scheduleConfig: config, timezone: TimeZone.current.identifier, graceBeforeMinutes: graceBeforeMinutes, graceAfterMinutes: graceAfterMinutes, startAt: startDate, endAt: nil)
    }
}

enum DoseFilter: String, CaseIterable, Identifiable {
    case upcoming, taken, missed, needsConfirmation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"; case .taken: return "Taken"
        case .missed: return "Missed"; case .needsConfirmation: return "Confirm"
        }
    }
}
