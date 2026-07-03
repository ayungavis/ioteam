//
//  CompleteOnboardingUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public final class CompleteOnboardingUseCase: Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol) {
        self.client = client
    }

    public func execute() async throws -> OnboardingCompletion {
        let endpoint = APIEndpoint(path: "onboarding/complete", method: .post)
        let response: OnboardingCompletionResponse = try await client.request(endpoint)
        return response.data
    }
}
