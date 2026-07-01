import Foundation

@MainActor
public final class ObserveDevicesUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() -> AsyncStream<[DeviceSummary]> {
        repository.observeDevices()
    }
}
