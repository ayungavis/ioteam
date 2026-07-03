//
//  RegisterPushTokenUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class RegisterPushTokenUseCase: Sendable {
    private let client: APIClientProtocol
    
    private struct RegisterPushTokenRequest: Encodable {
        let token: String
    }

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(token: String) async throws {
        let payload = RegisterPushTokenRequest(token: token)
        let jsonBody = try JSONEncoder().encode(payload)
        let endpoint = APIEndpoint(path: "notifications/tokens", method: .post, body: jsonBody)
        let _: PushTokenRegistrationResponse = try await client.request(endpoint)
    }
}
