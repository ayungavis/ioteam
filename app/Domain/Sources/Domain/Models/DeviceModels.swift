import Foundation

public enum DeviceStatus: String, Codable, Sendable, CaseIterable {
    case active
    case disabled
}

public enum DeviceConnectionState: String, Codable, Sendable, CaseIterable {
    case disconnected
    case scanning
    case connecting
    case paired
    case connected
    case setupFailed
}

public enum DeviceEventType: String, Codable, Sendable, CaseIterable {
    case open
    case close
}

public struct DeviceSummary: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let peripheralIdentifier: UUID
    public let firmwareVersion: String
    public var name: String
    public var status: DeviceStatus
    public var connectionState: DeviceConnectionState
    public var lastSeenAt: Date?
    public var lastEventType: DeviceEventType?

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
        self.peripheralIdentifier = peripheralIdentifier
        self.firmwareVersion = firmwareVersion
        self.name = name
        self.status = status
        self.connectionState = connectionState
        self.lastSeenAt = lastSeenAt
        self.lastEventType = lastEventType
    }
}

public struct DiscoveredDevice: Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let rssi: Int

    public init(id: UUID, name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
    }
}

public struct PairingTokenResponse: Codable, Sendable, Equatable {
    public let pairingToken: String
    public let familyId: String

    public init(pairingToken: String, familyId: String) {
        self.pairingToken = pairingToken
        self.familyId = familyId
    }
}
