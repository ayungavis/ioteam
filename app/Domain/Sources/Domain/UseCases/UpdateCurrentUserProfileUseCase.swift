//
//  UpdateCurrentUserProfileUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class UpdateCurrentUserProfileUseCase: Sendable {
    private let client: APIClientProtocol

    private struct UpdateCurrentUserProfileRequest: Encodable {
        let fullName: String
        let dateOfBirth: String
    }

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute(fullName: String, dateOfBirth: String) async throws -> AuthenticatedUser {
        let payload = UpdateCurrentUserProfileRequest(fullName: fullName, dateOfBirth: dateOfBirth)
        let endpoint = APIEndpoint(path: "me", method: .patch, body: try JSONEncoder().encode(payload))
        let response: UserProfileResponse = try await client.request(endpoint)
        return response.data
    }
}
