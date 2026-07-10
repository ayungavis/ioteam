import Foundation

@MainActor
public protocol DeviceRepositoryProtocol {
    func getDevices() async throws -> [DeviceSummary]
    func observeDevices() -> AsyncStream<[DeviceSummary]>
    func startScanning() -> AsyncStream<DeviceScanSnapshot>
    func stopScanning()
    func pairDevice(discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary
    func reconfigureDeviceWiFi(deviceID: UUID, discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary
    func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary
    func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary
    func deleteDevice(deviceID: UUID) async throws
    /// Re-syncs the device list from the backend and republishes it to observers.
    func refreshFromBackend() async
}

public extension DeviceRepositoryProtocol {
    /// Default no-op so preview/test fakes don't need a backend.
    func refreshFromBackend() async {}
}
