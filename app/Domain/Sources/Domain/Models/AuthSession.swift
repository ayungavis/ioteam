//
//  AuthSession.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public struct AuthenticatedUser: Codable, Sendable, Equatable {
    public let id: String
    public let email: String
    public let fullName: String?
    public let dateOfBirth: String?
    public let onboardingCompleted: Bool

    public init(
        id: String,
        email: String,
        fullName: String?,
        dateOfBirth: String?,
        onboardingCompleted: Bool
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.dateOfBirth = dateOfBirth
        self.onboardingCompleted = onboardingCompleted
    }
}

public struct AuthSession: Codable, Sendable, Equatable {
    public let accessToken: String
    public let user: AuthenticatedUser

    public init(accessToken: String, user: AuthenticatedUser) {
        self.accessToken = accessToken
        self.user = user
    }
}

public struct AuthSessionResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: AuthSession

    public init(success: Bool, data: AuthSession) {
        self.success = success
        self.data = data
    }
}
