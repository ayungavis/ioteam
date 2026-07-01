import Foundation

@MainActor
public final class SetDeviceEnabledUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        try await repository.setDeviceEnabled(deviceID: deviceID, isEnabled: isEnabled)
    }
}
