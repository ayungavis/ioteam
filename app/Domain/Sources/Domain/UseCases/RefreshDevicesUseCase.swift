import Foundation

/// Forces a device-list re-sync from the backend (pull-to-refresh).
@MainActor
public final class RefreshDevicesUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async {
        await repository.refreshFromBackend()
    }
}
