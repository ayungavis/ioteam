import Foundation

public final class GetMedicinesUseCase: Sendable {
    private let client: APIClientProtocol
    public init(client: APIClientProtocol) { self.client = client }
    public func execute() async throws -> [MedicineItem] {
        let response: MedicineListResponse = try await client.request(APIEndpoint(path: "medicines", method: .get))
        return response.data
    }
}
