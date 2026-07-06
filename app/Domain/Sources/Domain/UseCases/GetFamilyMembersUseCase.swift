import Foundation

/// GET /families/{id}/members — lists all members with their user profiles.
public final class GetFamilyMembersUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(familyId: String) async throws -> [FamilyMember] {
        let response: FamilyMembersResponse = try await client.request(APIEndpoint(path: "families/\(familyId)/members", method: .get))
        return response.data
    }
}
