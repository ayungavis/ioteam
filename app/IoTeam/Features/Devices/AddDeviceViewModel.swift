import Data
import Domain
import SwiftUI

@Observable
final class AddDeviceViewModel {
    var visibleDevices: [DiscoveredDevice] = []
    var selectedDeviceID: UUID?
    var customName = ""
    var wifiSSID = ""
    var wifiPassword = ""
    var currentWiFiSSID: String?
    var isDetectingWiFi = false
    var scanState: BLEScanState = .idle
    var isPairing = false
    var pairingStatusMessage: String?
    var alertMessage: String?

    var selectedDeviceName: String? {
        guard let selectedDeviceID else { return nil }
        return visibleDevices.first(where: { $0.id == selectedDeviceID })?.name
    }

    private let startDeviceScanUseCase: StartDeviceScanUseCase
    private let stopDeviceScanUseCase: StopDeviceScanUseCase
    private let pairDeviceUseCase: PairDeviceUseCase
    private let wiFiProvisioningService: WiFiProvisioningServiceProtocol
    @ObservationIgnored
    private var scanTask: Task<Void, Never>?
    @ObservationIgnored
    private var wiFiTask: Task<Void, Never>?
    @ObservationIgnored
    private var pairingStatusObserver: NSObjectProtocol?

    init(
        startDeviceScanUseCase: StartDeviceScanUseCase,
        stopDeviceScanUseCase: StopDeviceScanUseCase,
        pairDeviceUseCase: PairDeviceUseCase,
        wiFiProvisioningService: WiFiProvisioningServiceProtocol
    ) {
        self.startDeviceScanUseCase = startDeviceScanUseCase
        self.stopDeviceScanUseCase = stopDeviceScanUseCase
        self.pairDeviceUseCase = pairDeviceUseCase
        self.wiFiProvisioningService = wiFiProvisioningService
        self.pairingStatusObserver = NotificationCenter.default.addObserver(
            forName: .devicePairingStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let peripheralID = notification.userInfo?[DevicePairingStatusUserInfoKey.peripheralID] as? UUID,
                  peripheralID == self.selectedDeviceID,
                  let message = notification.userInfo?[DevicePairingStatusUserInfoKey.message] as? String
            else {
                return
            }

            self.pairingStatusMessage = message
        }
    }

    deinit {
        if let pairingStatusObserver {
            NotificationCenter.default.removeObserver(pairingStatusObserver)
        }
        stopScanning()
    }

    func startScanning() {
        alertMessage = nil
        selectedDeviceID = nil
        visibleDevices = []
        scanState = .scanning
        currentWiFiSSID = nil
        pairingStatusMessage = nil
        scanTask?.cancel()
        loadCurrentWiFi()

        let stream = startDeviceScanUseCase.execute()
        scanTask = Task { @MainActor in
            for await snapshot in stream {
                scanState = snapshot.state

                if selectedDeviceID == nil && !isPairing {
                    visibleDevices = snapshot.discoveredDevices
                }
            }
        }
    }

    func loadCurrentWiFi() {
        wiFiTask?.cancel()
        isDetectingWiFi = true

        wiFiTask = Task { @MainActor in
            defer {
                isDetectingWiFi = false
            }

            let detectedSSID = await wiFiProvisioningService.currentSSID()
            guard !Task.isCancelled else {
                return
            }

            currentWiFiSSID = detectedSSID

            guard wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let detectedSSID
            else {
                return
            }

            wifiSSID = detectedSSID
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        wiFiTask?.cancel()
        wiFiTask = nil
        stopDeviceScanUseCase.execute()
    }

    func selectDevice(_ device: DiscoveredDevice) {
        selectedDeviceID = device.id
        if customName.isEmpty {
            customName = device.name
        }
        pairingStatusMessage = nil
        stopScanning()
    }

    @MainActor
    func pairSelectedDevice() async -> Bool {
        guard let selectedDeviceID else {
            return false
        }

        isPairing = true
        alertMessage = nil
        pairingStatusMessage = "Preparing Wi-Fi for DoseLatch..."

        defer {
            isPairing = false
        }

        do {
            try await wiFiProvisioningService.joinNetworkIfNeeded(
                ssid: wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines),
                passphrase: wifiPassword
            )
            pairingStatusMessage = "Sending provisioning to DoseLatch..."

            let pairedDevice = try await pairDeviceUseCase.execute(
                discoveryID: selectedDeviceID,
                provisioningInfo: DeviceProvisioningInfo(
                    customName: customName.trimmingCharacters(in: .whitespacesAndNewlines),
                    wifiSSID: wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines),
                    wifiPassword: wifiPassword
                )
            )
            if let familyId = AppSessionStore.shared.familyId {
                AppSessionStore.shared.saveFamilyAndDevice(
                    familyId: familyId,
                    deviceId: pairedDevice.id.uuidString,
                    deviceName: customName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            pairingStatusMessage = "DoseLatch is ready."
            return true
        } catch {
            pairingStatusMessage = nil
            alertMessage = error.localizedDescription
            return false
        }
    }
}
