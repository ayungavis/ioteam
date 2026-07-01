//
//  TaskLocalStore.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation
import SwiftData

@ModelActor
public actor TaskLocalStore {
    public func fetchAll() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<SDTaskItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let records = try modelContext.fetch(descriptor)
        return records.map { $0.toDomain() }
    }

    public func saveOrUpdate(_ remoteItems: [TaskItem]) throws {
        for item in remoteItems {
            let itemID = item.id
            let descriptor = FetchDescriptor<SDTaskItem>(predicate: #Predicate { $0.id == itemID })
            if let existing = try modelContext.fetch(descriptor).first {
                existing.title = item.title
                existing.isCompleted = item.isCompleted
                existing.updatedAt = Date()
            } else {
                modelContext.insert(SDTaskItem(id: item.id, title: item.title, isCompleted: item.isCompleted))
            }
        }
        try modelContext.save()
    }
}
