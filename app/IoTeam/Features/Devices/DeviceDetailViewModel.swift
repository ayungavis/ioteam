import Domain
import SwiftUI

@Observable
final class DeviceDetailViewModel {
    var device: DeviceSummary?
    var draftName = ""
    var alertMessage: String?
    var hasReceivedFirstSnapshot = false

    private let deviceID: UUID
    private let observeDevicesUseCase: ObserveDevicesUseCase
    private let renameDeviceUseCase: RenameDeviceUseCase
    private let setDeviceEnabledUseCase: SetDeviceEnabledUseCase
    private let deleteDeviceUseCase: DeleteDeviceUseCase
    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    init(
        deviceID: UUID,
        observeDevicesUseCase: ObserveDevicesUseCase,
        renameDeviceUseCase: RenameDeviceUseCase,
        setDeviceEnabledUseCase: SetDeviceEnabledUseCase,
        deleteDeviceUseCase: DeleteDeviceUseCase
    ) {
        self.deviceID = deviceID
        self.observeDevicesUseCase = observeDevicesUseCase
        self.renameDeviceUseCase = renameDeviceUseCase
        self.setDeviceEnabledUseCase = setDeviceEnabledUseCase
        self.deleteDeviceUseCase = deleteDeviceUseCase
    }

    deinit {
        observationTask?.cancel()
    }

    func startObserving() {
        guard observationTask == nil else {
            return
        }

        let stream = observeDevicesUseCase.execute()
        observationTask = Task { @MainActor in
            for await devices in stream {
                hasReceivedFirstSnapshot = true
                device = devices.first(where: { $0.id == deviceID })
                if draftName.isEmpty {
                    draftName = device?.name ?? ""
                }
            }
        }
    }

    @MainActor
    func saveName() async {
        let trimmedName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        do {
            device = try await renameDeviceUseCase.execute(deviceID: deviceID, newName: trimmedName)
            draftName = device?.name ?? trimmedName
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    func setEnabled(_ isEnabled: Bool) async {
        do {
            device = try await setDeviceEnabledUseCase.execute(deviceID: deviceID, isEnabled: isEnabled)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    func deleteDevice() async -> Bool {
        do {
            try await deleteDeviceUseCase.execute(deviceID: deviceID)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }
}
