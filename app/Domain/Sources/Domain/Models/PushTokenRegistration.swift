//
//  PushTokenRegistration.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Foundation

public struct PushTokenRegistration: Codable, Sendable, Equatable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct PushTokenRegistrationResponse: Codable, Sendable, Equatable {
    public let success: Bool
    public let data: PushTokenRegistration

    public init(success: Bool, data: PushTokenRegistration) {
        self.success = success
        self.data = data
    }
}
