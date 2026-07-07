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
        try? await refreshDevicesFromBackend()
        return try await localStore.fetchAll()
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
                try? await self.refreshDevicesFromBackend()
                await self.publishDevices()
            }
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
            pairingToken: tokenResponse.data.token,
            wifiSSID: provisioningInfo.wifiSSID,
            wifiPassword: provisioningInfo.wifiPassword,
            deviceName: provisioningInfo.customName,
            backendMode: backendMode,
            backendBaseURL: backendBaseURL
        )

        let device = try await waitForRegisteredDevice(
            hardwareID: info.deviceId.uuidString,
            peripheralID: discoveryID
        )

        await publishDevices()
        return device
    }

    public func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        let requestBody = try JSONEncoder().encode(["name": newName])
        let response: FamilyDeviceResponse = try await apiClient.request(
            APIEndpoint(path: "devices/\(deviceID.uuidString)", method: .patch, body: requestBody)
        )
        let existing = try? await localStore.fetchAll().first(where: { $0.id == deviceID })
        let updated = makeSummary(from: response.data, existing: existing)

        try await localStore.upsert(updated)
        await publishDevices()
        return updated
    }

    public func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        let requestBody = try JSONEncoder().encode(["status": isEnabled ? DeviceStatus.active.rawValue : DeviceStatus.disabled.rawValue])
        let response: FamilyDeviceResponse = try await apiClient.request(
            APIEndpoint(path: "devices/\(deviceID.uuidString)", method: .patch, body: requestBody)
        )
        let existing = try? await localStore.fetchAll().first(where: { $0.id == deviceID })
        let updated = makeSummary(from: response.data, existing: existing)

        try await localStore.upsert(updated)
        await publishDevices()
        return updated
    }

    public func deleteDevice(deviceID: UUID) async throws {
        let _: SimpleSuccessResponse = try await apiClient.request(
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

    private func refreshDevicesFromBackend(peripheralOverrides: [String: UUID] = [:]) async throws -> [DeviceSummary] {
        let response: FamilyDeviceListResponse = try await apiClient.request(APIEndpoint(path: "devices", method: .get))
        let existingDevices = (try? await localStore.fetchAll()) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existingDevices.map { ($0.id.uuidString.lowercased(), $0) })
        let summaries = response.data.compactMap { remoteDevice in
            makeSummary(
                from: remoteDevice,
                existing: existingByID[remoteDevice.id.lowercased()],
                peripheralOverride: peripheralOverrides[remoteDevice.id]
            )
        }
        try await localStore.replaceAll(with: summaries)
        return summaries
    }

    private func waitForRegisteredDevice(hardwareID: String, peripheralID: UUID) async throws -> DeviceSummary {
        let deadline = Date().addingTimeInterval(25)

        while Date() < deadline {
            let remoteDevices: FamilyDeviceListResponse = try await apiClient.request(APIEndpoint(path: "devices", method: .get))
            if let remoteDevice = remoteDevices.data.first(where: { $0.hardwareId.caseInsensitiveCompare(hardwareID) == .orderedSame }) {
                let existing = try? await localStore.fetchAll().first(where: {
                    $0.id.uuidString.caseInsensitiveCompare(remoteDevice.id) == .orderedSame
                })
                let summary = makeSummary(from: remoteDevice, existing: existing, peripheralOverride: peripheralID)
                try await localStore.upsert(summary)
                return summary
            }

            try await Task.sleep(for: .seconds(1))
        }

        throw BLEDeviceProvisioningError.pairingFailed(
            String(localized: "The device joined Bluetooth, but backend registration was not confirmed in time.")
        )
    }

    private func makeSummary(
        from remoteDevice: FamilyDevice,
        existing: DeviceSummary?,
        peripheralOverride: UUID? = nil
    ) -> DeviceSummary {
        let identifier = peripheralOverride
            ?? existing?.peripheralIdentifier
            ?? UUID(uuidString: remoteDevice.id)
            ?? UUID()
        let connectionState: DeviceConnectionState
        if existing?.connectionState == .connected || remoteDevice.lastSeenAt != nil {
            connectionState = .connected
        } else {
            connectionState = existing?.connectionState ?? .paired
        }

        return DeviceSummary(
            id: UUID(uuidString: remoteDevice.id) ?? UUID(),
            peripheralIdentifier: identifier,
            firmwareVersion: remoteDevice.firmwareVersion ?? existing?.firmwareVersion ?? "Unknown",
            name: remoteDevice.name,
            status: DeviceStatus(rawValue: remoteDevice.status) ?? .active,
            connectionState: connectionState,
            lastSeenAt: remoteDevice.lastSeenAt ?? existing?.lastSeenAt,
            lastEventType: existing?.lastEventType
        )
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
        "http"
    }

    private var backendBaseURL: String? {
        "https://resourceful-generosity-staging.up.railway.app"
    }
}
