import Foundation

@MainActor
public final class PairDeviceUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(discoveryID: UUID, customName: String) async throws -> DeviceSummary {
        try await repository.pairDevice(discoveryID: discoveryID, customName: customName)
    }
}
