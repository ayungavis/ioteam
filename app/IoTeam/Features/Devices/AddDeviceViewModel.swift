import Domain
import SwiftUI

@Observable
final class AddDeviceViewModel {
    var visibleDevices: [DiscoveredDevice] = []
    var selectedDeviceID: UUID?
    var customName = ""
    var scanState: BLEScanState = .idle
    var isPairing = false
    var alertMessage: String?

    private let startDeviceScanUseCase: StartDeviceScanUseCase
    private let stopDeviceScanUseCase: StopDeviceScanUseCase
    private let pairDeviceUseCase: PairDeviceUseCase
    @ObservationIgnored
    private var scanTask: Task<Void, Never>?

    init(
        startDeviceScanUseCase: StartDeviceScanUseCase,
        stopDeviceScanUseCase: StopDeviceScanUseCase,
        pairDeviceUseCase: PairDeviceUseCase
    ) {
        self.startDeviceScanUseCase = startDeviceScanUseCase
        self.stopDeviceScanUseCase = stopDeviceScanUseCase
        self.pairDeviceUseCase = pairDeviceUseCase
    }

    deinit {
        stopScanning()
    }

    func startScanning() {
        alertMessage = nil
        selectedDeviceID = nil
        visibleDevices = []
        scanState = .scanning
        scanTask?.cancel()

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

    func stopScanning() {
        scanTask?.cancel()
        scanTask = nil
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
            _ = try await pairDeviceUseCase.execute(
                discoveryID: selectedDeviceID,
                customName: customName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }
}
