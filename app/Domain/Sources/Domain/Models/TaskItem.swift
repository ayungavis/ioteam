//
//  TaskItem.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public struct TaskItem: Identifiable, Equatable, Decodable, Sendable {
    public let id: UUID
    public let title: String
    public let isCompleted: Bool

    public init(id: UUID, title: String, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}
