import Domain
import SwiftUI

@Observable
final class DeviceListViewModel {
    var devices: [DeviceSummary] = []
    var isLoading = false
    var alertMessage: String?

    private let getDevicesUseCase: GetDevicesUseCase

    init(getDevicesUseCase: GetDevicesUseCase) {
        self.getDevicesUseCase = getDevicesUseCase
    }

    @MainActor
    func loadData() async {
        isLoading = true
        alertMessage = nil

        do {
            devices = try await getDevicesUseCase.execute()
            isLoading = false
        } catch {
            alertMessage = error.localizedDescription
            isLoading = false
        }
    }
}
