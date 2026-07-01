import Foundation

@MainActor
public final class StopDeviceScanUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() {
        repository.stopScanning()
    }
}
