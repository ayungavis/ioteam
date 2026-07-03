import Domain
import SwiftUI

@Observable
final class MedicineListViewModel {
    var medicines: [Medicine] = []
    var alertMessage: String?

    init() {
        loadMockData()
    }

    func loadMockData() {
        let calendar = Calendar.current
        let now = Date()

        medicines = [
            Medicine(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: "Paracetamol",
                totalQuantity: 30,
                remainingQuantity: 24,
                status: .active,
                linkedDeviceName: "My medicine box",
                linkedDeviceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                nextDoseTime: calendar.date(byAdding: .hour, value: 2, to: now),
                frequency: .daily,
                scheduleTimesText: "08:00, 13:00, 18:00"
            ),
            Medicine(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: "Vitamin D",
                totalQuantity: 60,
                remainingQuantity: 55,
                status: .active,
                linkedDeviceName: "My medicine box",
                linkedDeviceID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                nextDoseTime: calendar.date(byAdding: .day, value: 1, to: now),
                frequency: .weekly,
                scheduleTimesText: "Mon, Wed, Fri at 09:00"
            ),
            Medicine(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: "Blood Pressure Meds",
                totalQuantity: 14,
                remainingQuantity: 8,
                status: .disabled,
                linkedDeviceName: "Grandma's box",
                linkedDeviceID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                nextDoseTime: nil,
                frequency: .hourly,
                scheduleTimesText: "Every 8 hours"
            )
        ]
    }
}
