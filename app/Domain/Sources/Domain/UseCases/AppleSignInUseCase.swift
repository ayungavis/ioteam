//
//  AppleSignInUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public final class AppleSignInUseCase: Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(identityToken: String, userIdentifier: String) async throws -> AuthToken {
        let payload = ["apple_token": identityToken, "user_id": userIdentifier]
        let jsonBody = try? JSONSerialization.data(withJSONObject: payload)

        let endpoint = APIEndpoint(path: "auth/apple", method: .post, body: jsonBody)
        return try await client.request(endpoint)
    }
}
