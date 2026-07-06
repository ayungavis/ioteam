import Foundation

public final class RegisterDeviceUseCase: Sendable {
    private let client: APIClientProtocol
    private struct Request: Encodable { let hardwareId: String; let name: String }
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(deviceName: String) async throws -> RegisteredDevice {
        let hwId = "default-\(UUID().uuidString.lowercased().prefix(8))"
        let endpoint = APIEndpoint(path: "devices/register", method: .post, body: try JSONEncoder().encode(Request(hardwareId: String(hwId), name: deviceName)))
        let response: DeviceRegistrationResponse = try await client.request(endpoint)
        return response.data
    }
}
