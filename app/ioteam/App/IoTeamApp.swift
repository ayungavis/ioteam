//
//  IoTeamApp.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Data
import Domain
import SwiftData
import SwiftUI

@main
struct IoTeamApp: App {
    let sharedContainer: ModelContainer
    let repository: TaskRepository
    let getTasksUseCase: GetTasksUseCase
    let appleSignInUseCase: AppleSignInUseCase

    init() {
        do {
            let schema = Schema([SDTaskItem.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.sharedContainer = try ModelContainer(for: schema, configurations: [config])

            #if DEBUG
            let networkClient: APIClientProtocol = MockAPIClient()
            #else
            let networkClient = URLSessionAPIClient(baseURLString: "https://yourdomain.com")
            #endif
            
            self.repository = TaskRepository(modelContainer: sharedContainer, apiClient: networkClient)
            self.getTasksUseCase = GetTasksUseCase(repository: repository)
            self.appleSignInUseCase = AppleSignInUseCase(client: networkClient)

            AppRouter.shared.currentFlow = AppLaunchCoordinator.shared.determineInitialFlow()
        } catch {
            fatalError("Failed to initialize dependency injection matrix structure: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.getTasksUseCase, getTasksUseCase)
                .environment(\.taskRepository, repository)
                .environment(\.appleSignInUseCase, appleSignInUseCase)
        }
    }
}

/// Environment Abstraction Extensions to handle strict safe dependency passing
struct GetTasksUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: GetTasksUseCase = .init(repository: FakeRepository())
}

struct TaskRepositoryKey: EnvironmentKey {
    @MainActor static let defaultValue: TaskRepositoryProtocol = FakeRepository()
}

struct AppleSignInUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: AppleSignInUseCase = .init(client: FakeAPI())
}

extension EnvironmentValues {
    var getTasksUseCase: GetTasksUseCase {
        get { self[GetTasksUseCaseKey.self] } set { self[GetTasksUseCaseKey.self] = newValue }
    }

    var taskRepository: TaskRepositoryProtocol {
        get { self[TaskRepositoryKey.self] } set { self[TaskRepositoryKey.self] = newValue }
    }

    var appleSignInUseCase: AppleSignInUseCase {
        get { self[AppleSignInUseCaseKey.self] } set { self[AppleSignInUseCaseKey.self] = newValue }
    }
}

private final class FakeRepository: TaskRepositoryProtocol {
    func getTasks() async throws -> [TaskItem] {
        []
    }

    func syncTasksWithRemote() async throws {}
}

private final class FakeAPI: APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        throw NetworkError.invalidURL
    }
}
