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
    }

    deinit {
        stopScanning()
    }

    func startScanning() {
        alertMessage = nil
        selectedDeviceID = nil
        visibleDevices = []
        scanState = .scanning
        currentWiFiSSID = nil
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
        stopScanning()
    }

    @MainActor
    func pairSelectedDevice() async -> Bool {
        guard let selectedDeviceID else {
            return false
        }

        isPairing = true
        alertMessage = nil

        defer {
            isPairing = false
        }

        do {
            try await wiFiProvisioningService.joinNetworkIfNeeded(
                ssid: wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines),
                passphrase: wifiPassword
            )

            _ = try await pairDeviceUseCase.execute(
                discoveryID: selectedDeviceID,
                provisioningInfo: DeviceProvisioningInfo(
                    customName: customName.trimmingCharacters(in: .whitespacesAndNewlines),
                    wifiSSID: wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines),
                    wifiPassword: wifiPassword
                )
            )
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }
}
