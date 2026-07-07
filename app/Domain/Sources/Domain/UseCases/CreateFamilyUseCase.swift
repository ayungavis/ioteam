//
//  CreateFamilyUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class CreateFamilyUseCase: Sendable {
    private let client: APIClientProtocol

    private struct CreateFamilyRequest: Encodable {
        let name: String
    }

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(name: String) async throws -> FamilySummary {
        let payload = CreateFamilyRequest(name: name)
        let endpoint = APIEndpoint(path: "families", method: .post, body: try JSONEncoder().encode(payload))
        let response: FamilySummaryResponse = try await client.request(endpoint)
        return response.data
    }
}
