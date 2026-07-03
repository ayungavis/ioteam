//
//  GetCurrentUserProfileUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class GetCurrentUserProfileUseCase: Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute() async throws -> AuthenticatedUser {
        let endpoint = APIEndpoint(path: "me")
        let response: UserProfileResponse = try await client.request(endpoint)
        return response.data
    }
}
