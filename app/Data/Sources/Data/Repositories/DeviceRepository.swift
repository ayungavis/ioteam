import Domain
import Foundation
import SwiftData

public extension Notification.Name {
    static let devicePairingStatusDidChange = Notification.Name("devicePairingStatusDidChange")
}

public enum DevicePairingStatusUserInfoKey {
    public static let peripheralID = "peripheralID"
    public static let message = "message"
}

@MainActor
public final class DeviceRepository: DeviceRepositoryProtocol {
    private let localStore: DeviceLocalStore
    private let apiClient: APIClientProtocol
    private let bleClient: BLEDeviceProvisioningClient
    private var scanContinuation: AsyncStream<DeviceScanSnapshot>.Continuation?
    private var deviceContinuations: [UUID: AsyncStream<[DeviceSummary]>.Continuation] = [:]
    private var currentSnapshot: DeviceScanSnapshot
    private var latestDeviceInfoByPeripheralID: [UUID: BLEDeviceInfoPayload] = [:]

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

        bleClient.onDeviceInfoChanged = { [weak self] peripheralID, payload in
            Task { @MainActor in
                self?.latestDeviceInfoByPeripheralID[peripheralID] = payload
                self?.publishPairingStatus(for: peripheralID, payload: payload)
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
        latestDeviceInfoByPeripheralID.removeValue(forKey: discoveryID)
        publishPairingStatus(
            for: discoveryID,
            message: "Connecting to DoseLatch..."
        )
        print(
            "DoseLatch pairing started peripheral=\(discoveryID.uuidString) "
                + "ssid=\(provisioningInfo.wifiSSID) backendMode=\(backendMode) "
                + "backendBaseURLSet=\(backendBaseURL != nil)"
        )

        let tokenResponse: PairingTokenResponse = try await apiClient.request(
            APIEndpoint(path: "devices/pairing-token", method: .post)
        )
        let pairingFamilyID = decodePairingTokenFamilyID(tokenResponse.data.token)
        print(
            "DoseLatch pairing token received peripheral=\(discoveryID.uuidString) "
                + "familyId=\(pairingFamilyID ?? "nil") pairingToken=\(tokenResponse.data.token)"
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

        publishPairingStatus(
            for: discoveryID,
            message: "DoseLatch accepted provisioning. Waiting for backend registration..."
        )

        let device = try await waitForRegisteredDevice(
            hardwareID: info.deviceId.uuidString,
            peripheralID: discoveryID,
            wifiSSID: provisioningInfo.wifiSSID
        )

        publishPairingStatus(
            for: discoveryID,
            message: "DoseLatch is ready."
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

    private func waitForRegisteredDevice(hardwareID: String, peripheralID: UUID, wifiSSID: String) async throws -> DeviceSummary {
        let deadline = Date().addingTimeInterval(25)

        while Date() < deadline {
            if let failure = provisioningFailureMessage(for: peripheralID, wifiSSID: wifiSSID) {
                throw BLEDeviceProvisioningError.pairingFailed(failure)
            }

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

    private func provisioningFailureMessage(for peripheralID: UUID, wifiSSID: String) -> String? {
        guard let deviceInfo = latestDeviceInfoByPeripheralID[peripheralID] else {
            return nil
        }

        let provisioningState = deviceInfo.provisioningState?.lowercased()
        let lastError = deviceInfo.lastError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard provisioningState == "failed" || lastError.contains("reason=201") else {
            return nil
        }

        if lastError.contains("reason=201") {
            return "DoseLatch could not find the Wi-Fi network \"\(wifiSSID)\". Make sure it is visible to 2.4 GHz devices and not hidden or 5 GHz-only."
        }

        if !lastError.isEmpty {
            return "DoseLatch Wi-Fi provisioning failed: \(lastError)"
        }

        return "DoseLatch Wi-Fi provisioning failed before backend registration completed."
    }

    private func publishPairingStatus(for peripheralID: UUID, payload: BLEDeviceInfoPayload) {
        let provisioningState = payload.provisioningState?.lowercased()
        let wifiState = payload.wifiState?.lowercased()
        let lastError = payload.lastError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let message: String?
        if provisioningState == "failed" {
            message = lastError.isEmpty ? "DoseLatch provisioning failed." : "DoseLatch provisioning failed: \(lastError)"
        } else if wifiState == "connected" {
            message = payload.paired
                ? "DoseLatch is paired."
                : "DoseLatch connected to Wi-Fi. Registering device..."
        } else if provisioningState == "provisioning" || wifiState == "connecting" {
            message = "DoseLatch is connecting to Wi-Fi..."
        } else if !lastError.isEmpty {
            message = "DoseLatch status: \(lastError)"
        } else {
            message = nil
        }

        guard let message else {
            return
        }

        publishPairingStatus(for: peripheralID, message: message)
    }

    private func publishPairingStatus(for peripheralID: UUID, message: String) {
        NotificationCenter.default.post(
            name: .devicePairingStatusDidChange,
            object: self,
            userInfo: [
                DevicePairingStatusUserInfoKey.peripheralID: peripheralID,
                DevicePairingStatusUserInfoKey.message: message,
            ]
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

    private func decodePairingTokenFamilyID(_ token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else {
            return nil
        }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = (4 - payload.count % 4) % 4
        payload.append(String(repeating: "=", count: paddingLength))

        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let familyID = object["familyId"] as? String else {
            return nil
        }

        return familyID
    }
}
