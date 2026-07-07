import Foundation

public final class RemoveMemberUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(familyId: String, memberId: String) async throws {
        let endpoint = APIEndpoint(path: "families/\(familyId)/members/\(memberId)", method: .delete)
        let _: EmptySuccessResponse = try await client.request(endpoint)
    }
}

public struct EmptySuccessResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public init(success: Bool) { self.success = success }
}
