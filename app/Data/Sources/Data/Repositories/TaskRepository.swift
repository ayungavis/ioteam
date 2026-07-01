//
//  TaskRepository.swift
//  Data
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation
import SwiftData

public final class TaskRepository: TaskRepositoryProtocol {
    private let modelContainer: ModelContainer
    private let apiClient: APIClientProtocol

    public init(modelContainer: ModelContainer, apiClient: APIClientProtocol) {
        self.modelContainer = modelContainer
        self.apiClient = apiClient
    }

    public func getTasks() async throws -> [TaskItem] {
        let store = TaskLocalStore(modelContainer: modelContainer)
        return try await store.fetchAll()
    }

    public func syncTasksWithRemote() async throws {
        let remoteItems: [TaskItem] = try await apiClient.request(APIEndpoint(path: "tasks"))
        let store = TaskLocalStore(modelContainer: modelContainer)
        try await store.saveOrUpdate(remoteItems)
    }
}
