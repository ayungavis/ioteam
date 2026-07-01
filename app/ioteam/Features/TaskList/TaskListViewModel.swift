//
//  TaskListViewModel.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import SwiftUI

@Observable
public final class TaskListViewModel {
    public var tasks: [TaskItem] = []
    public var isLoading = false
    public var alertMessage: String?
    
    private let getTasksUseCase: GetTasksUseCase
    private let repository: TaskRepositoryProtocol
    
    /// A simple delegate or closure routing token callback hook
    @ObservationIgnored
    public var onSessionExpired: (@MainActor () -> Void)?
    
    public init(getTasksUseCase: GetTasksUseCase, repository: TaskRepositoryProtocol) {
        self.getTasksUseCase = getTasksUseCase
        self.repository = repository
    }
    
    @MainActor
    public func loadData() async {
        isLoading = true
        alertMessage = nil
        
        do {
            tasks = try await getTasksUseCase.execute()
            isLoading = false
            try await repository.syncTasksWithRemote()
            tasks = try await getTasksUseCase.execute()
        } catch let error as NetworkError {
            isLoading = false
            if error == .unauthorized {
                onSessionExpired?()
            } else {
                alertMessage = error.localizedDescription
            }
        } catch {
            isLoading = false
            alertMessage = error.localizedDescription
        }
    }
}
