import Domain
import SwiftUI

@Observable
final class DeviceDetailViewModel {
    var device: DeviceSummary?
    var draftName = ""
    var alertMessage: String?

    private let deviceID: UUID
    private let getDevicesUseCase: GetDevicesUseCase
    private let renameDeviceUseCase: RenameDeviceUseCase
    private let setDeviceEnabledUseCase: SetDeviceEnabledUseCase
    private let deleteDeviceUseCase: DeleteDeviceUseCase

    init(
        deviceID: UUID,
        getDevicesUseCase: GetDevicesUseCase,
        renameDeviceUseCase: RenameDeviceUseCase,
        setDeviceEnabledUseCase: SetDeviceEnabledUseCase,
        deleteDeviceUseCase: DeleteDeviceUseCase
    ) {
        self.deviceID = deviceID
        self.getDevicesUseCase = getDevicesUseCase
        self.renameDeviceUseCase = renameDeviceUseCase
        self.setDeviceEnabledUseCase = setDeviceEnabledUseCase
        self.deleteDeviceUseCase = deleteDeviceUseCase
    }

    @MainActor
    func loadData() async {
        do {
            device = try await getDevicesUseCase.execute().first(where: { $0.id == deviceID })
            if draftName.isEmpty {
                draftName = device?.name ?? ""
            }
        } catch {
            alertMessage = error.localizedDescription
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
