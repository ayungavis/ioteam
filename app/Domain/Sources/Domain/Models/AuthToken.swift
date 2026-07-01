//
//  AuthToken.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public struct AuthToken: Decodable, Sendable {
    public let accessToken: String
    public let userId: String

    public init(accessToken: String, userId: String) {
        self.accessToken = accessToken
        self.userId = userId
    }
}
