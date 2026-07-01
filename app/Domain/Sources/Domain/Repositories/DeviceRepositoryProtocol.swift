import Foundation

@MainActor
public protocol DeviceRepositoryProtocol {
    func getDevices() async throws -> [DeviceSummary]
    func observeDevices() -> AsyncStream<[DeviceSummary]>
    func startScanning() -> AsyncStream<DeviceScanSnapshot>
    func stopScanning()
    func pairDevice(discoveryID: UUID, customName: String) async throws -> DeviceSummary
    func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary
    func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary
    func deleteDevice(deviceID: UUID) async throws
}
