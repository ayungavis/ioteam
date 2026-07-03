//
//  OnboardingModels.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public struct UserProfileResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: AuthenticatedUser

    public init(success: Bool, data: AuthenticatedUser) {
        self.success = success
        self.data = data
    }
}

public struct FamilySummary: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let inviteCode: String?

    public init(id: String, name: String, inviteCode: String?) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
    }
}

public struct FamilySummaryResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: FamilySummary

    public init(success: Bool, data: FamilySummary) {
        self.success = success
        self.data = data
    }
}

public struct OnboardingCompletion: Codable, Sendable, Equatable {
    public let id: String
    public let onboardingCompleted: Bool

    public init(id: String, onboardingCompleted: Bool) {
        self.id = id
        self.onboardingCompleted = onboardingCompleted
    }
}

public struct OnboardingCompletionResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: OnboardingCompletion

    public init(success: Bool, data: OnboardingCompletion) {
        self.success = success
        self.data = data
    }
}
