//
//  SDTaskItem.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation
import SwiftData

@Model
public final class SDTaskItem {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var updatedAt: Date

    public init(id: UUID, title: String, isCompleted: Bool, updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.updatedAt = updatedAt
    }

    public func toDomain() -> TaskItem {
        return TaskItem(id: self.id, title: self.title, isCompleted: self.isCompleted)
    }
}
