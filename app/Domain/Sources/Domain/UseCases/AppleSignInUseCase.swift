//
//  AppleSignInUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public final class AppleSignInUseCase: Sendable {
    private let client: APIClientProtocol
    
    private struct AppleSignInRequest: Encodable {
        let identityToken: String
        let fullName: String?
    }

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(identityToken: String, fullName: String?) async throws -> AuthSession {
        let payload = AppleSignInRequest(identityToken: identityToken, fullName: fullName)
        let jsonBody = try JSONEncoder().encode(payload)

        let endpoint = APIEndpoint(path: "auth/apple", method: .post, body: jsonBody)
        let response: AuthSessionResponse = try await client.request(endpoint)
        return response.data
    }
}
