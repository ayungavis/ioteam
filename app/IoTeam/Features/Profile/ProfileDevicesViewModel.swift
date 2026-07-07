import Domain
import SwiftUI

@Observable
final class ProfileDevicesViewModel {
    var devices: [DeviceSummary] = []
    private let observeDevicesUseCase: ObserveDevicesUseCase

    init(observeDevicesUseCase: ObserveDevicesUseCase) {
        self.observeDevicesUseCase = observeDevicesUseCase
    }

    func startObserving() {
        Task {
            for await devices in observeDevicesUseCase.execute() {
                self.devices = devices
            }
        }
    }
}
