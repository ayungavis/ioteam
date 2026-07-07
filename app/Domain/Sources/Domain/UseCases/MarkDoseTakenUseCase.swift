import Foundation

public final class MarkDoseTakenUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(doseId: String) async throws -> MarkTakenData {
        let endpoint = APIEndpoint(path: "doses/\(doseId)/mark-taken", method: .post)
        let response: MarkTakenResponse = try await client.request(endpoint)
        return response.data
    }
}
