import Foundation

public enum BLEScanState: Equatable, Sendable {
    case idle
    case scanning
    case deviceFound
    case noDevicesFound
    case poweredOff
    case unauthorized
    case unsupported
    case resetting
    case unknown
}

public struct DeviceScanSnapshot: Equatable, Sendable {
    public let discoveredDevices: [DiscoveredDevice]
    public let state: BLEScanState

    public init(discoveredDevices: [DiscoveredDevice], state: BLEScanState) {
        self.discoveredDevices = discoveredDevices
        self.state = state
    }
}
