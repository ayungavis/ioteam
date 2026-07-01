//
//  GetTaskUseCase.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public final class GetTasksUseCase {
    private let repository: TaskRepositoryProtocol

    public init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() async throws -> [TaskItem] {
        return try await repository.getTasks()
    }
}
