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

public struct FamilyDevice: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let familyId: String
    public let name: String
    public let hardwareId: String
    public let connectionType: String
    public let status: String
    public let firmwareVersion: String?
    public let lastSeenAt: Date?
    public let connectionState: String?

    public init(
        id: String,
        familyId: String,
        name: String,
        hardwareId: String,
        connectionType: String,
        status: String,
        firmwareVersion: String?,
        lastSeenAt: Date?,
        connectionState: String?
    ) {
        self.id = id
        self.familyId = familyId
        self.name = name
        self.hardwareId = hardwareId
        self.connectionType = connectionType
        self.status = status
        self.firmwareVersion = firmwareVersion
        self.lastSeenAt = lastSeenAt
        self.connectionState = connectionState
    }
}

public struct FamilyDeviceListResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: [FamilyDevice]

    public init(success: Bool, data: [FamilyDevice]) {
        self.success = success
        self.data = data
    }
}

public struct FamilyDeviceResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: FamilyDevice

    public init(success: Bool, data: FamilyDevice) {
        self.success = success
        self.data = data
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
    public let success: Bool
    public let data: PairingTokenData

    public init(success: Bool, data: PairingTokenData) {
        self.success = success
        self.data = data
    }
}

public struct PairingTokenData: Codable, Sendable, Equatable {
    public let token: String
    public let expiresInSeconds: Int

    public init(token: String, expiresInSeconds: Int) {
        self.token = token
        self.expiresInSeconds = expiresInSeconds
    }
}

public struct DeviceRegistrationResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: DeviceRegistrationData

    public init(success: Bool, data: DeviceRegistrationData) {
        self.success = success
        self.data = data
    }
}

public struct DeviceRegistrationData: Codable, Sendable, Equatable {
    public let device: FamilyDevice
    public let deviceToken: String

    public init(device: FamilyDevice, deviceToken: String) {
        self.device = device
        self.deviceToken = deviceToken
    }
}

public struct DeviceProvisioningInfo: Sendable, Equatable {
    public let customName: String
    public let wifiSSID: String
    public let wifiPassword: String

    public init(customName: String, wifiSSID: String, wifiPassword: String) {
        self.customName = customName
        self.wifiSSID = wifiSSID
        self.wifiPassword = wifiPassword
    }
}
