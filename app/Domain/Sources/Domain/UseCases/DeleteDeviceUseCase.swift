import Foundation

@MainActor
public final class DeleteDeviceUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(deviceID: UUID) async throws {
        try await repository.deleteDevice(deviceID: deviceID)
    }
}
