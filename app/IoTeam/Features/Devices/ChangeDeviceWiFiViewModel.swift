import Domain
import Foundation
import SwiftUI

@Observable
final class ChangeDeviceWiFiViewModel {
    let device: DeviceSummary
    var discoveredDevices: [DiscoveredDevice] = []
    var selectedDeviceID: UUID?
    var wifiSSID = ""
    var wifiPassword = ""
    var isScanning = false
    var isSaving = false
    var statusMessage: String?
    var alertMessage: String?

    private let startDeviceScanUseCase: StartDeviceScanUseCase
    private let stopDeviceScanUseCase: StopDeviceScanUseCase
    private let reconfigureDeviceWiFiUseCase: ReconfigureDeviceWiFiUseCase
    private let wiFiProvisioningService: WiFiProvisioningServiceProtocol
    @ObservationIgnored
    private var scanTask: Task<Void, Never>?

    init(
        device: DeviceSummary,
        startDeviceScanUseCase: StartDeviceScanUseCase,
        stopDeviceScanUseCase: StopDeviceScanUseCase,
        reconfigureDeviceWiFiUseCase: ReconfigureDeviceWiFiUseCase,
        wiFiProvisioningService: WiFiProvisioningServiceProtocol
    ) {
        self.device = device
        self.startDeviceScanUseCase = startDeviceScanUseCase
        self.stopDeviceScanUseCase = stopDeviceScanUseCase
        self.reconfigureDeviceWiFiUseCase = reconfigureDeviceWiFiUseCase
        self.wiFiProvisioningService = wiFiProvisioningService
    }

    deinit {
        scanTask?.cancel()
    }

    func startScanning() {
        guard scanTask == nil else {
            return
        }

        isScanning = true
        let stream = startDeviceScanUseCase.execute()
        scanTask = Task { @MainActor in
            for await snapshot in stream {
                discoveredDevices = snapshot.discoveredDevices
                isScanning = snapshot.state == .scanning
            }
        }
    }

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        stopDeviceScanUseCase.execute()
    }

    @MainActor
    func loadCurrentSSID() async {
        if let currentSSID = await wiFiProvisioningService.currentSSID(),
           wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            wifiSSID = currentSSID
        }
    }

    @MainActor
    func save() async -> Bool {
        guard let selectedDeviceID else {
            alertMessage = "Select the nearby DoseLatch device before updating Wi-Fi."
            return false
        }

        let trimmedSSID = wifiSSID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSSID.isEmpty else {
            alertMessage = WiFiProvisioningError.missingSSID.localizedDescription
            return false
        }

        isSaving = true
        alertMessage = nil
        statusMessage = "Preparing Wi-Fi..."

        defer {
            isSaving = false
        }

        do {
            try await wiFiProvisioningService.joinNetworkIfNeeded(
                ssid: trimmedSSID,
                passphrase: wifiPassword
            )
            statusMessage = "Sending Wi-Fi update to DoseLatch..."
            _ = try await reconfigureDeviceWiFiUseCase.execute(
                deviceID: device.id,
                discoveryID: selectedDeviceID,
                provisioningInfo: DeviceProvisioningInfo(
                    customName: device.name,
                    wifiSSID: trimmedSSID,
                    wifiPassword: wifiPassword
                )
            )
            statusMessage = "DoseLatch Wi-Fi is updated."
            stopScanning()
            return true
        } catch {
            statusMessage = nil
            alertMessage = error.localizedDescription
            return false
        }
    }
}
