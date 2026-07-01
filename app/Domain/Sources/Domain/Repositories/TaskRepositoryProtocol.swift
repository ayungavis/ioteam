//
//  TaskRepositoryProtocol.swift
//  Domain
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation

public protocol TaskRepositoryProtocol {
    func getTasks() async throws -> [TaskItem]
    func syncTasksWithRemote() async throws
}
