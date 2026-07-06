import Foundation

/// DELETE /me — permanently deletes the authenticated user and all associated data.
public final class DeleteAccountUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute() async throws {
        let _: SimpleSuccessResponse = try await client.request(APIEndpoint(path: "me", method: .delete))
    }
}
