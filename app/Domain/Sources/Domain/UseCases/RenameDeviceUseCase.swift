import Foundation

@MainActor
public final class RenameDeviceUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        try await repository.renameDevice(deviceID: deviceID, newName: newName)
    }
}
