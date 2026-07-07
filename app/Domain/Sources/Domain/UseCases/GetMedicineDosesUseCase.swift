import Foundation

public final class GetMedicineDosesUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute(medicineId: String, statuses: [String] = []) async throws -> [DoseItem] {
        let path = "medicines/\(medicineId)/doses"
        let queryItems: [URLQueryItem]? = statuses.isEmpty ? nil : [URLQueryItem(name: "status", value: statuses.joined(separator: ","))]
        let endpoint = APIEndpoint(path: path, method: .get, queryItems: queryItems)
        let response: DoseListResponse = try await client.request(endpoint)
        return response.data
    }
}
