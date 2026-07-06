import Foundation

/// PATCH /families/{id} — renames the family (owner or admin only).
public final class RenameFamilyUseCase: Sendable {
    private struct Request: Encodable { let name: String }
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(familyId: String, name: String) async throws -> RenamedFamily {
        let endpoint = APIEndpoint(path: "families/\(familyId)", method: .patch, body: try JSONEncoder().encode(Request(name: name)))
        let response: RenameFamilyResponse = try await client.request(endpoint)
        return response.data
    }
}
