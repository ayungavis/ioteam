import Foundation

public final class RefreshInviteCodeUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(familyId: String) async throws -> String {
        let endpoint = APIEndpoint(path: "families/\(familyId)/invite-code", method: .post)
        let response: InviteCodeResponse = try await client.request(endpoint)
        return response.data.inviteCode
    }
}
