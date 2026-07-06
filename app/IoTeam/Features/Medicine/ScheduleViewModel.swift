import Domain
import SwiftUI

@Observable
final class ScheduleViewModel {
    var doses: [ScheduleUIDose] = []
    var isLoading = false
    var alertMessage: String?
    var doseAwaitingConfirmation: ScheduleUIDose?
    private var pendingConfirmDoseId: String?

    private let getMedicinesUseCase: GetMedicinesUseCase
    private let getMedicineDosesUseCase: GetMedicineDosesUseCase
    private let markDoseTakenUseCase: MarkDoseTakenUseCase

    init(
        getMedicinesUseCase: GetMedicinesUseCase,
        getMedicineDosesUseCase: GetMedicineDosesUseCase,
        markDoseTakenUseCase: MarkDoseTakenUseCase
    ) {
        self.getMedicinesUseCase = getMedicinesUseCase
        self.getMedicineDosesUseCase = getMedicineDosesUseCase
        self.markDoseTakenUseCase = markDoseTakenUseCase
    }

    func loadDoses() async {
        isLoading = true
        alertMessage = nil
        do {
            let medicines = try await getMedicinesUseCase.execute()
            var allDoses: [ScheduleUIDose] = []
            let calendar = Calendar.current
            let endDate = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()

            for medicine in medicines {
                let statusFilter = ["pending", "due", "taken", "missed"]
                let doseItems = try await getMedicineDosesUseCase.execute(medicineId: medicine.id, statuses: statusFilter)
                for item in doseItems where item.scheduledAt <= endDate {
                    allDoses.append(ScheduleUIDose(
                        id: item.id,
                        scheduledAt: item.scheduledAt,
                        windowStartAt: item.windowStartAt,
                        windowEndAt: item.windowEndAt,
                        time: Self.timeFormatter.string(from: item.scheduledAt),
                        medicineName: medicine.name,
                        deviceName: medicine.device?.name ?? "—",
                        amount: item.doseAmount,
                        status: Domain.DoseStatus(rawValue: item.status) ?? .pending,
                        actualTakenAt: item.actualTakenAt,
                        takenSource: item.takenSource
                    ))
                }
            }
            doses = allDoses.sorted { $0.scheduledAt < $1.scheduledAt }
            resolvePendingConfirmation()
        } catch {
            alertMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Queues a one-tap confirmation for the dose a push notification pointed at.
    /// Resolves immediately if the dose list is already loaded, otherwise after the next load.
    func requestConfirmation(forDoseId doseId: String) {
        pendingConfirmDoseId = doseId
        resolvePendingConfirmation()
    }

    private func resolvePendingConfirmation() {
        guard let doseId = pendingConfirmDoseId,
              let dose = doses.first(where: { $0.id == doseId }) else { return }
        pendingConfirmDoseId = nil
        if dose.status != .taken { doseAwaitingConfirmation = dose }
    }

    func dosesForDate(_ date: Date) -> [ScheduleUIDose] {
        doses.filter { Calendar.current.isDate($0.scheduledAt, inSameDayAs: date) }
    }

    /// Marks the dose taken on the backend. There is no un-take endpoint, so taken doses stay taken.
    func markTaken(_ dose: ScheduleUIDose) async {
        guard dose.status != .taken else { return }
        guard let idx = doses.firstIndex(where: { $0.id == dose.id }) else { return }
        let previousStatus = doses[idx].status
        doses[idx].status = .taken
        do {
            _ = try await markDoseTakenUseCase.execute(doseId: dose.id)
        } catch {
            doses[idx].status = previousStatus
            alertMessage = error.localizedDescription
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "hh:mm a"; return formatter
    }()
}
