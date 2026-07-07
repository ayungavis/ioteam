import Domain
import Foundation
import SwiftData

@Model
public final class SDDeviceRecord {
    @Attribute(.unique) public var id: UUID
    public var peripheralIdentifier: String
    public var firmwareVersion: String
    public var name: String
    public var statusRawValue: String
    public var connectionStateRawValue: String
    public var lastSeenAt: Date?
    public var lastEventTypeRawValue: String?

    public init(
        id: UUID,
        peripheralIdentifier: UUID,
        firmwareVersion: String,
        name: String,
        status: DeviceStatus,
        connectionState: DeviceConnectionState,
        lastSeenAt: Date?,
        lastEventType: DeviceEventType?
    ) {
        self.id = id
        self.peripheralIdentifier = peripheralIdentifier.uuidString
        self.firmwareVersion = firmwareVersion
        self.name = name
        self.statusRawValue = status.rawValue
        self.connectionStateRawValue = connectionState.rawValue
        self.lastSeenAt = lastSeenAt
        self.lastEventTypeRawValue = lastEventType?.rawValue
    }

    public func toDomain() -> DeviceSummary {
        DeviceSummary(
            id: id,
            peripheralIdentifier: UUID(uuidString: peripheralIdentifier) ?? id,
            firmwareVersion: firmwareVersion,
            name: name,
            status: DeviceStatus(rawValue: statusRawValue) ?? .active,
            connectionState: DeviceConnectionState(rawValue: connectionStateRawValue) ?? .disconnected,
            lastSeenAt: lastSeenAt,
            lastEventType: lastEventTypeRawValue.flatMap(DeviceEventType.init(rawValue:))
        )
    }

    public func apply(_ summary: DeviceSummary) {
        peripheralIdentifier = summary.peripheralIdentifier.uuidString
        firmwareVersion = summary.firmwareVersion
        name = summary.name
        statusRawValue = summary.status.rawValue
        connectionStateRawValue = summary.connectionState.rawValue
        lastSeenAt = summary.lastSeenAt
        lastEventTypeRawValue = summary.lastEventType?.rawValue
    }
}
