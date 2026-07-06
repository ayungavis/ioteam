import Foundation

/// POST /auth/logout — signals logout to the server. The caller is responsible
/// for clearing the local access token afterwards.
public final class LogoutUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute() async throws {
        let _: SimpleSuccessResponse = try await client.request(APIEndpoint(path: "auth/logout", method: .post))
    }
}
