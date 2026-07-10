import Foundation

@MainActor
public final class ReconfigureDeviceWiFiUseCase {
    private let repository: DeviceRepositoryProtocol

    public init(repository: DeviceRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(
        deviceID: UUID,
        discoveryID: UUID,
        provisioningInfo: DeviceProvisioningInfo
    ) async throws -> DeviceSummary {
        try await repository.reconfigureDeviceWiFi(
            deviceID: deviceID,
            discoveryID: discoveryID,
            provisioningInfo: provisioningInfo
        )
    }
}
