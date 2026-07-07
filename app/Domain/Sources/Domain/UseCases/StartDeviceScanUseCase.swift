import Foundation

@MainActor
public final class StartDeviceScanUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() -> AsyncStream<DeviceScanSnapshot> {
        repository.startScanning()
    }
}
