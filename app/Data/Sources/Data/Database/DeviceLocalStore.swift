import Domain
import Foundation
import SwiftData

@ModelActor
public actor DeviceLocalStore {
    public func fetchAll() throws -> [DeviceSummary] {
        let descriptor = FetchDescriptor<SDDeviceRecord>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    public func upsert(_ summary: DeviceSummary) throws {
        let summaryID = summary.id
        let descriptor = FetchDescriptor<SDDeviceRecord>(predicate: #Predicate { $0.id == summaryID })

        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(summary)
        } else {
            modelContext.insert(
                SDDeviceRecord(
                    id: summary.id,
                    peripheralIdentifier: summary.peripheralIdentifier,
                    firmwareVersion: summary.firmwareVersion,
                    name: summary.name,
                    status: summary.status,
                    connectionState: summary.connectionState,
                    lastSeenAt: summary.lastSeenAt,
                    lastEventType: summary.lastEventType
                )
            )
        }

        try modelContext.save()
    }

    public func delete(deviceID: UUID) throws {
        let descriptor = FetchDescriptor<SDDeviceRecord>(predicate: #Predicate { $0.id == deviceID })
        try modelContext.fetch(descriptor).forEach { modelContext.delete($0) }
        try modelContext.save()
    }
}
