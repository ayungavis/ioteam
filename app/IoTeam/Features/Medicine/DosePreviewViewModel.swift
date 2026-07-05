import Domain
import SwiftUI

@Observable
final class DosePreviewViewModel: Identifiable {
    struct DayGroup: Identifiable {
        let id: Date; let day: Date; let doses: [GeneratedDose]
    }
    let id = UUID()
    var groupedDoses: [DayGroup] = []
    var summary: DoseSummary?
    let medicineName: String; let totalQuantity: Int; let scheduleInput: ScheduleInput
    private let onConfirm: () -> Void

    init(doses: [GeneratedDose], summary: DoseSummary, medicineName: String, totalQuantity: Int, scheduleInput: ScheduleInput, onConfirm: @escaping () -> Void) {
        self.medicineName = medicineName; self.totalQuantity = totalQuantity; self.scheduleInput = scheduleInput; self.onConfirm = onConfirm
        self.summary = summary; self.groupedDoses = Self.groupByDay(doses)
    }

    var exceedsQuantity: Bool { guard let summary = summary else { return false }; return summary.pillsUsed > totalQuantity }
    func confirmAndSave() { onConfirm() }

    private static func groupByDay(_ doses: [GeneratedDose]) -> [DayGroup] {
        let cal = Calendar.current
        return Dictionary(grouping: doses) { cal.startOfDay(for: $0.scheduledAt) }
            .map { DayGroup(id: $0.key, day: $0.key, doses: $0.value.sorted { $0.scheduledAt < $1.scheduledAt }) }
            .sorted { $0.day < $1.day }
    }
}
