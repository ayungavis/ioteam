import Domain
import Foundation
import SwiftData

@MainActor
public final class DeviceRepository: DeviceRepositoryProtocol {
    private let localStore: DeviceLocalStore
    private let apiClient: APIClientProtocol
    private let bleClient: BLEDeviceProvisioningClient
    private var scanContinuation: AsyncStream<DeviceScanSnapshot>.Continuation?
    private var deviceContinuations: [UUID: AsyncStream<[DeviceSummary]>.Continuation] = [:]
    private var currentSnapshot: DeviceScanSnapshot

    public init(modelContainer: ModelContainer, apiClient: APIClientProtocol, bleClient: BLEDeviceProvisioningClient) {
        self.localStore = DeviceLocalStore(modelContainer: modelContainer)
        self.apiClient = apiClient
        self.bleClient = bleClient
        self.currentSnapshot = DeviceScanSnapshot(discoveredDevices: [], state: .idle)

        bleClient.onDiscoveredDevicesChanged = { [weak self] devices in
            self?.publishSnapshot(devices: devices, state: self?.currentSnapshot.state ?? .idle)
        }

        bleClient.onScanStateChanged = { [weak self] state in
            self?.publishSnapshot(devices: self?.currentSnapshot.discoveredDevices ?? [], state: state)
        }

        bleClient.onDeviceEvent = { [weak self] peripheralID, payload in
            Task { @MainActor in
                try? await self?.updateDeviceEvent(peripheralID: peripheralID, payload: payload)
            }
        }
    }

    public func getDevices() async throws -> [DeviceSummary] {
        try await localStore.fetchAll()
    }

    public func observeDevices() -> AsyncStream<[DeviceSummary]> {
        AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            let observationID = UUID()
            deviceContinuations[observationID] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.deviceContinuations.removeValue(forKey: observationID)
                }
            }

            Task { @MainActor in
                // Publish the local cache immediately, then reconcile with the
                // family's devices on the backend (covers devices paired by other
                // family members' phones, which this phone has never seen over BLE).
                await self.publishDevices()
                await self.syncWithBackend()
                await self.publishDevices()
            }
        }
    }

    /// Pulls the family device list from GET /devices and reconciles the local store:
    /// upserts every backend device (preserving local-only BLE details when known)
    /// and drops local records the backend no longer has. Offline → keeps the cache.
    private func syncWithBackend() async {
        do {
            let response: FamilyDeviceListResponse = try await apiClient.request(
                APIEndpoint(path: "devices", method: .get)
            )
            let local = (try? await localStore.fetchAll()) ?? []
            let remoteIds = Set(response.data.compactMap { UUID(uuidString: $0.id) })

            for remote in response.data {
                guard let uuid = UUID(uuidString: remote.id) else { continue }
                let existing = local.first { $0.id == uuid }
                let summary = DeviceSummary(
                    id: uuid,
                    peripheralIdentifier: existing?.peripheralIdentifier ?? uuid,
                    firmwareVersion: remote.firmwareVersion ?? existing?.firmwareVersion ?? "",
                    name: remote.name,
                    status: DeviceStatus(rawValue: remote.status) ?? .active,
                    connectionState: existing?.connectionState ?? .disconnected,
                    lastSeenAt: remote.lastSeenAt ?? existing?.lastSeenAt,
                    lastEventType: existing?.lastEventType
                )
                try? await localStore.upsert(summary)
            }

            for device in local where !remoteIds.contains(device.id) {
                try? await localStore.delete(deviceID: device.id)
            }
        } catch {
            // No connectivity or auth issue — the local cache stays authoritative for now.
        }
    }

    public func startScanning() -> AsyncStream<DeviceScanSnapshot> {
        scanContinuation?.finish()
        currentSnapshot = DeviceScanSnapshot(discoveredDevices: [], state: .scanning)

        let stream = AsyncStream<DeviceScanSnapshot> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            self.scanContinuation = continuation
            continuation.yield(self.currentSnapshot)
            continuation.onTermination = { _ in
                Task { @MainActor in
                    self.stopScanning()
                }
            }
        }

        bleClient.startScanning()
        return stream
    }

    public func stopScanning() {
        bleClient.stopScanning()
        publishSnapshot(devices: currentSnapshot.discoveredDevices, state: .idle)
    }

    public func pairDevice(discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary {
        let tokenResponse: PairingTokenResponse = try await apiClient.request(
            APIEndpoint(path: "devices/pairing-token", method: .post)
        )

        let info = try await bleClient.pairDevice(
            id: discoveryID,
            pairingToken: tokenResponse.pairingToken,
            familyId: tokenResponse.familyId,
            wifiSSID: provisioningInfo.wifiSSID,
            wifiPassword: provisioningInfo.wifiPassword,
            backendMode: backendMode,
            backendBaseURL: backendBaseURL
        )

        let requestBody = try JSONEncoder().encode([
            "device_id": info.deviceId.uuidString,
            "device_name": provisioningInfo.customName,
            "peripheral_identifier": discoveryID.uuidString,
            "firmware_version": info.firmwareVersion
        ])

        let registered: DeviceSummary = try await apiClient.request(
            APIEndpoint(path: "devices/register", method: .post, body: requestBody)
        )

        try await localStore.upsert(registered)
        await publishDevices()
        return registered
    }

    public func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        let requestBody = try JSONEncoder().encode(["name": newName])
        let updated: DeviceSummary = try await apiClient.request(
            APIEndpoint(path: "devices/\(deviceID.uuidString)", method: .patch, body: requestBody)
        )

        try await localStore.upsert(updated)
        await publishDevices()
        return updated
    }

    public func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        let requestBody = try JSONEncoder().encode(["status": isEnabled ? DeviceStatus.active.rawValue : DeviceStatus.disabled.rawValue])
        let updated: DeviceSummary = try await apiClient.request(
            APIEndpoint(path: "devices/\(deviceID.uuidString)", method: .patch, body: requestBody)
        )

        try await localStore.upsert(updated)
        await publishDevices()
        return updated
    }

    public func deleteDevice(deviceID: UUID) async throws {
        let _: DeviceSummary = try await apiClient.request(
            APIEndpoint(path: "devices/\(deviceID.uuidString)", method: .delete)
        )

        try await localStore.delete(deviceID: deviceID)
        await publishDevices()
    }

    private func publishSnapshot(devices: [DiscoveredDevice], state: BLEScanState) {
        currentSnapshot = DeviceScanSnapshot(discoveredDevices: devices, state: state)
        scanContinuation?.yield(currentSnapshot)
    }

    private func publishDevices() async {
        let devices = (try? await localStore.fetchAll()) ?? []
        for continuation in deviceContinuations.values {
            continuation.yield(devices)
        }
    }

    private func updateDeviceEvent(peripheralID: UUID, payload: BLEDeviceEventPayload) async throws {
        let devices = try await localStore.fetchAll()

        guard let device = devices.first(where: { $0.peripheralIdentifier == peripheralID }) else {
            return
        }

        let updated = DeviceSummary(
            id: device.id,
            peripheralIdentifier: device.peripheralIdentifier,
            firmwareVersion: device.firmwareVersion,
            name: device.name,
            status: device.status,
            connectionState: .connected,
            lastSeenAt: payload.timestamp,
            lastEventType: payload.eventType
        )

        try await localStore.upsert(updated)
        await publishDevices()
    }

    private var backendMode: String {
        #if DEBUG
            "mock"
        #else
            "http"
        #endif
    }

    private var backendBaseURL: String? {
        #if DEBUG
            nil
        #else
            "https://yourdomain.com"
        #endif
    }
}
