import Domain
import SwiftUI

@Observable
final class DeviceListViewModel {
    var devices: [DeviceSummary] = []
    var alertMessage: String?

    private let observeDevicesUseCase: ObserveDevicesUseCase
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    init(observeDevicesUseCase: ObserveDevicesUseCase) {
        self.observeDevicesUseCase = observeDevicesUseCase
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
}
