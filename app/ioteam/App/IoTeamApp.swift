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
    let deviceRepository: DeviceRepositoryProtocol

    init() {
        do {
            let schema = Schema([SDTaskItem.self, SDDeviceRecord.self])
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
            self.deviceRepository = DeviceRepository(
                modelContainer: sharedContainer,
                apiClient: networkClient,
                bleClient: BLEDeviceProvisioningClient()
            )

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
                .environment(\.deviceRepository, deviceRepository)
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

struct DeviceRepositoryKey: EnvironmentKey {
    @MainActor static let defaultValue: DeviceRepositoryProtocol = FakeDeviceRepository()
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

    var deviceRepository: DeviceRepositoryProtocol {
        get { self[DeviceRepositoryKey.self] } set { self[DeviceRepositoryKey.self] = newValue }
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

private final class FakeDeviceRepository: DeviceRepositoryProtocol {
    func getDevices() async throws -> [DeviceSummary] {
        []
    }

    func startScanning() -> AsyncStream<DeviceScanSnapshot> {
        AsyncStream { continuation in
            continuation.yield(DeviceScanSnapshot(discoveredDevices: [], state: .idle))
            continuation.finish()
        }
    }

    func stopScanning() {}

    func pairDevice(discoveryID: UUID, customName: String) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }

    func renameDevice(deviceID: UUID, newName: String) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }

    func setDeviceEnabled(deviceID: UUID, isEnabled: Bool) async throws -> DeviceSummary {
        throw BLEDeviceProvisioningError.deviceNotFound
    }

    func deleteDevice(deviceID: UUID) async throws {
        throw BLEDeviceProvisioningError.deviceNotFound
    }
}
