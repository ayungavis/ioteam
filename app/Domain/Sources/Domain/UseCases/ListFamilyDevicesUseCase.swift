import Foundation

/// Lists the family's registered devices from the backend (GET /devices).
/// Not to be confused with GetDevicesUseCase, which reads locally paired BLE devices.
public final class ListFamilyDevicesUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute() async throws -> [FamilyDevice] {
        let response: FamilyDeviceListResponse = try await client.request(APIEndpoint(path: "devices", method: .get))
        return response.data
    }
}
