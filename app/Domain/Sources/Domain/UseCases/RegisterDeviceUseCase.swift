import Foundation

public final class RegisterDeviceUseCase: Sendable {
    public init(client: APIClientProtocol) {}

    public func execute(deviceName: String) async throws -> FamilyDevice {
        throw NetworkError.badResponse(
            statusCode: 0,
            message: String(localized: "Use the Add Device flow to register a DoseLatch device.")
        )
    }
}
