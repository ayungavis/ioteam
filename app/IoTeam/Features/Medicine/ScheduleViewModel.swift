import Domain
import SwiftUI

@Observable
final class ScheduleViewModel {
    var doses: [ScheduleUIDose] = []
    var isLoading = false
    var alertMessage: String?

    private let getMedicinesUseCase: GetMedicinesUseCase
    private let getMedicineDosesUseCase: GetMedicineDosesUseCase

    init(getMedicinesUseCase: GetMedicinesUseCase, getMedicineDosesUseCase: GetMedicineDosesUseCase) {
        self.getMedicinesUseCase = getMedicinesUseCase
        self.getMedicineDosesUseCase = getMedicineDosesUseCase
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
                    let timeStr = Self.timeFormatter.string(from: item.scheduledAt)
                    let status: Domain.DoseStatus = Domain.DoseStatus(rawValue: item.status) ?? .pending
                    allDoses.append(ScheduleUIDose(
                        time: timeStr,
                        medicineName: medicine.name,
                        deviceName: medicine.device?.name ?? "—",
                        amount: item.doseAmount,
                        status: status
                    ))
                }
            }
            doses = allDoses.sorted { $0.time < $1.time }
        } catch {
            alertMessage = error.localizedDescription
        }
        isLoading = false
    }

    func dosesForDate(_ date: Date) -> [ScheduleUIDose] {
        doses.filter { dose in
            guard let doseTime = Self.parseTime(dose.time) else { return false }
            return Calendar.current.isDate(doseTime, inSameDayAs: date)
        }
    }

    func toggleDose(_ dose: ScheduleUIDose) {
        guard let idx = doses.firstIndex(where: { $0.id == dose.id }) else { return }
        doses[idx].status = doses[idx].status == .taken ? .pending : .taken
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "hh:mm a"; return formatter
    }()

    private static func parseTime(_ time: String) -> Date? {
        let formatter = DateFormatter(); formatter.dateFormat = "hh:mm a"
        return formatter.date(from: time)
    }
}
