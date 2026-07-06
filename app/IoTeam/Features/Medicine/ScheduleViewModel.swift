import Domain
import SwiftUI

@Observable
final class ScheduleViewModel {
    var doses: [ScheduleUIDose] = []
    var isLoading = false
    var alertMessage: String?

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
                let statusFilter = ["pending", "due", "taken"]
                let doseItems = try await getMedicineDosesUseCase.execute(medicineId: medicine.id, statuses: statusFilter)
                for item in doseItems where item.scheduledAt <= endDate {
                    allDoses.append(ScheduleUIDose(
                        id: item.id,
                        scheduledAt: item.scheduledAt,
                        time: Self.timeFormatter.string(from: item.scheduledAt),
                        medicineName: medicine.name,
                        deviceName: medicine.device?.name ?? "—",
                        amount: item.doseAmount,
                        status: Domain.DoseStatus(rawValue: item.status) ?? .pending
                    ))
                }
            }
            doses = allDoses.sorted { $0.scheduledAt < $1.scheduledAt }
        } catch {
            alertMessage = error.localizedDescription
        }
        isLoading = false
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
