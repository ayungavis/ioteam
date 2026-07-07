import Foundation

@MainActor
public final class GetDevicesUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [DeviceSummary] {
        try await repository.getDevices()
    }
}
