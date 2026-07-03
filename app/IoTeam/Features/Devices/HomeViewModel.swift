import Domain
import SwiftUI

@Observable
final class HomeViewModel {
    var devices: [DeviceSummary] = []
    var alertMessage: String?

    private let observeDevicesUseCase: ObserveDevicesUseCase
    private let setDeviceEnabledUseCase: SetDeviceEnabledUseCase
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    init(
        observeDevicesUseCase: ObserveDevicesUseCase,
        setDeviceEnabledUseCase: SetDeviceEnabledUseCase
    ) {
        self.observeDevicesUseCase = observeDevicesUseCase
        self.setDeviceEnabledUseCase = setDeviceEnabledUseCase
    }

    deinit {
        observationTask?.cancel()
    }

    func startObserving() {
        guard observationTask == nil else {
            return
        }

        alertMessage = nil
        let stream = observeDevicesUseCase.execute()
        observationTask = Task { @MainActor in
            for await devices in stream {
                self.devices = devices
            }
        }
    }

    @MainActor
    func toggleEnabled(_ device: DeviceSummary) async {
        do {
            _ = try await setDeviceEnabledUseCase.execute(
                deviceID: device.id,
                isEnabled: device.status != .active
            )
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
