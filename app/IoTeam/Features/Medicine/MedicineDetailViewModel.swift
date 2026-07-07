import Domain
import SwiftUI

/// All backend use cases the medicine detail screen needs, grouped so they can be injected as one unit.
struct MedicineDetailUseCases {
    let previewDoses: PreviewDosesUseCase
    let createMedicine: CreateMedicineUseCase
    let getDoses: GetMedicineDosesUseCase
    let listFamilyDevices: ListFamilyDevicesUseCase
    let getDetail: GetMedicineDetailUseCase
    let update: UpdateMedicineUseCase
    let delete: DeleteMedicineUseCase
    let reschedulePreview: ReschedulePreviewUseCase
    let reschedule: RescheduleMedicineUseCase
}

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

    // Edit-mode state
    var medicineStatus: MedicineStatus = .active
    var remainingQuantity = 0
    var totalQuantity = 0
    var adjustQuantityDelta = 0
    var isLoadingDetail = false
    var isSaving = false
    private var originalName = ""
    private var originalStatus: MedicineStatus = .active

    private var useCases: MedicineDetailUseCases?
    private var appSessionStore: AppSessionStore?

    init(mode: Mode) {
        self.mode = mode
    }

    /// Call from onAppear to inject real use cases without replacing the entire VM
    func configure(useCases: MedicineDetailUseCases, appSessionStore: AppSessionStore) {
        let needsLoad = self.useCases == nil && mode != .add
        self.useCases = useCases
        self.appSessionStore = appSessionStore
        if needsLoad, case .edit(let id) = mode {
            loadDoses(medicineId: id)
            loadDetail(medicineId: id)
        }
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
        guard let useCase = useCases?.getDoses else { return }
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

    func loadDetail(medicineId: String) {
        guard let useCase = useCases?.getDetail else { return }
        isLoadingDetail = true
        Task {
            do {
                let detail = try await useCase.execute(medicineId: medicineId)
                await MainActor.run { applyDetail(detail); isLoadingDetail = false }
            } catch {
                await MainActor.run { alertMessage = error.localizedDescription; isLoadingDetail = false }
            }
        }
    }

    private func applyDetail(_ detail: MedicineDetailData) {
        medicineName = detail.name
        originalName = detail.name
        medicineStatus = MedicineStatus(rawValue: detail.status) ?? .active
        originalStatus = medicineStatus
        remainingQuantity = detail.remainingQuantity
        totalQuantity = detail.totalQuantity
        selectedDeviceName = detail.device?.name ?? ""
        adjustQuantityDelta = 0

        guard let schedule = detail.schedule else { return }
        frequency = MedicineFrequency(rawValue: schedule.frequencyType) ?? .daily
        graceBeforeMinutes = schedule.graceBeforeMinutes
        graceAfterMinutes = schedule.graceAfterMinutes
        if let parsed = Self.parseISODate(schedule.startAt) { startDate = parsed }
        switch schedule.scheduleConfig {
        case .daily(let timesOfDay):
            dailyTimes = timesOfDay.compactMap { Self.parseHHmm($0) }
            if dailyTimes.isEmpty { dailyTimes = [Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()] }
        case .weekly(let weekdays, let timesOfDay):
            weeklyDays = Set(weekdays.compactMap { Self.weekdayNames[safe: $0] })
            weeklyTimes = timesOfDay.compactMap { Self.parseHHmm($0) }
        case .hourly(let intervalHours):
            hourlyInterval = intervalHours
        }
    }

    /// True when name, status, or stock differ from the loaded medicine.
    var hasDetailChanges: Bool {
        medicineName.trimmingCharacters(in: .whitespacesAndNewlines) != originalName
            || medicineStatus != originalStatus
            || adjustQuantityDelta != 0
    }

    /// PATCHes only the changed fields. Returns true when there was nothing to save or the save succeeded.
    func saveChanges() async -> Bool {
        guard case .edit(let medicineId) = mode, let useCase = useCases?.update else { return false }
        let trimmedName = medicineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = UpdateMedicineRequest(
            name: trimmedName != originalName && !trimmedName.isEmpty ? trimmedName : nil,
            status: medicineStatus != originalStatus ? medicineStatus.rawValue : nil,
            adjustQuantity: adjustQuantityDelta != 0 ? adjustQuantityDelta : nil
        )
        if request.isEmpty { return true }
        await MainActor.run { isSaving = true }
        defer { Task { await MainActor.run { isSaving = false } } }
        do {
            let result = try await useCase.execute(medicineId: medicineId, request: request)
            await MainActor.run {
                originalName = result.medicine.name
                medicineName = result.medicine.name
                originalStatus = MedicineStatus(rawValue: result.medicine.status) ?? medicineStatus
                medicineStatus = originalStatus
                remainingQuantity = result.medicine.remainingQuantity
                totalQuantity = result.medicine.totalQuantity
                adjustQuantityDelta = 0
            }
            loadDoses(medicineId: medicineId)
            return true
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return false
        }
    }

    /// Previews the future doses a schedule change would produce (writes nothing).
    func previewReschedule() async -> (doses: [GeneratedDose], summary: DoseSummary)? {
        guard case .edit(let medicineId) = mode, let useCase = useCases?.reschedulePreview else { return nil }
        isGeneratingPreview = true
        defer { isGeneratingPreview = false }
        do {
            let data = try await useCase.execute(medicineId: medicineId, schedule: buildScheduleInput())
            return (data.doses, data.summary)
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return nil
        }
    }

    /// Applies the new schedule: replaces future pending doses, keeps history.
    func applyReschedule() async -> Bool {
        guard case .edit(let medicineId) = mode, let useCase = useCases?.reschedule else { return false }
        do {
            _ = try await useCase.execute(medicineId: medicineId, schedule: buildScheduleInput())
            loadDoses(medicineId: medicineId)
            loadDetail(medicineId: medicineId)
            return true
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return false
        }
    }

    func deleteMedicine() async -> Bool {
        guard case .edit(let medicineId) = mode, let useCase = useCases?.delete else { return false }
        do {
            _ = try await useCase.execute(medicineId: medicineId)
            return true
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return false
        }
    }

    func previewDoses() async -> (doses: [GeneratedDose], summary: DoseSummary)? {
        guard let useCase = useCases?.previewDoses else { return nil }
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
        guard let useCase = useCases?.createMedicine else {
            await MainActor.run { alertMessage = String(localized: "Not ready yet. Please try again.") }
            return false
        }
        do {
            let deviceId = try await resolveDeviceId()
            _ = try await useCase.execute(name: medicineName.trimmingCharacters(in: .whitespacesAndNewlines), deviceId: deviceId, quantity: quantity, schedule: buildScheduleInput())
            return true
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
            return false
        }
    }

    /// Resolves the deviceId to attach the medicine to from the current session or the family's active devices.
    private func resolveDeviceId() async throws -> String {
        if let deviceId = await MainActor.run(body: { appSessionStore?.deviceId }) { return deviceId }

        if let device = try await useCases?.listFamilyDevices.execute().first(where: { $0.status == "active" }) {
            await saveResolvedDevice(id: device.id, familyId: device.familyId, name: device.name)
            return device.id
        }

        throw NetworkError.badResponse(
            statusCode: 0,
            message: String(localized: "No active device is available. Add and pair a DoseLatch device first.")
        )
    }

    private func saveResolvedDevice(id: String, familyId: String, name: String) async {
        await MainActor.run {
            appSessionStore?.saveFamilyAndDevice(familyId: familyId, deviceId: id, deviceName: name)
        }
    }

    // MARK: - Schedule Builder
    private static let weekdayMap: [String: Int] = ["Sunday":0,"Monday":1,"Tuesday":2,"Wednesday":3,"Thursday":4,"Friday":5,"Saturday":6]
    static let weekdayNames = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    private func toHHmm(_ date: Date) -> String { let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"; return formatter.string(from: date) }

    private static func parseHHmm(_ time: String) -> Date? {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        guard let parsed = formatter.date(from: time) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
        return Calendar.current.date(from: comps)
    }

    private static func parseISODate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        let plain = ISO8601DateFormatter()
        return plain.date(from: string)
    }

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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum DoseFilter: String, CaseIterable, Identifiable {
    case upcoming, taken, missed, needsConfirmation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .upcoming: return String(localized: "Upcoming"); case .taken: return String(localized: "Taken")
        case .missed: return String(localized: "Missed"); case .needsConfirmation: return String(localized: "Confirm")
        }
    }
}
