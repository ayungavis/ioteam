//
//  JoinFamilyUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class JoinFamilyUseCase: Sendable {
    private let client: APIClientProtocol

    private struct JoinFamilyRequest: Encodable {
        let inviteCode: String
    }

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(inviteCode: String) async throws -> FamilySummary {
        let payload = JoinFamilyRequest(inviteCode: inviteCode)
        let endpoint = APIEndpoint(path: "families/join", method: .post, body: try JSONEncoder().encode(payload))
        let response: FamilySummaryResponse = try await client.request(endpoint)
        return response.data
    }
}
