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

// MARK: - Family Detail

public struct FamilyDetail: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let inviteCode: String?
    public let memberCount: Int
    public let role: String
    public let members: [FamilyMember]

    public init(id: String, name: String, inviteCode: String?, memberCount: Int, role: String, members: [FamilyMember]) {
        self.id = id; self.name = name; self.inviteCode = inviteCode; self.memberCount = memberCount; self.role = role; self.members = members
    }
}

public struct FamilyMember: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let role: String
    public let joinedAt: String
    public let user: FamilyMemberUser

    public init(id: String, role: String, joinedAt: String, user: FamilyMemberUser) {
        self.id = id; self.role = role; self.joinedAt = joinedAt; self.user = user
    }
}

public struct FamilyMemberUser: Codable, Sendable, Equatable {
    public let id: String
    public let fullName: String?
    public let email: String?
    public let avatarUrl: String?

    public init(id: String, fullName: String?, email: String?, avatarUrl: String?) {
        self.id = id; self.fullName = fullName; self.email = email; self.avatarUrl = avatarUrl
    }
}

public struct FamilyDetailResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: FamilyDetail

    public init(success: Bool, data: FamilyDetail) { self.success = success; self.data = data }
}

public struct InviteCodeResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: InviteCodeData

    public init(success: Bool, data: InviteCodeData) { self.success = success; self.data = data }
}

public struct InviteCodeData: Codable, Sendable, Equatable {
    public let inviteCode: String

    public init(inviteCode: String) { self.inviteCode = inviteCode }
}
