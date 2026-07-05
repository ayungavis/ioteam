import Foundation

public final class GetCurrentFamilyUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute() async throws -> FamilyDetail {
        let response: FamilyDetailResponse = try await client.request(APIEndpoint(path: "families/current", method: .get))
        return response.data
    }
}
