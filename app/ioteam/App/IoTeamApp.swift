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
    @AppStorage("appLanguageCode") private var appLanguageCode = AppLanguage.system.rawValue
    let sharedContainer: ModelContainer
    let appleSignInUseCase: AppleSignInUseCase
    let deviceRepository: DeviceRepositoryProtocol

    init() {
        do {
            let schema = Schema([SDDeviceRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.sharedContainer = try ModelContainer(for: schema, configurations: [config])

            #if DEBUG
            let networkClient: APIClientProtocol = MockAPIClient()
            #else
            let networkClient = URLSessionAPIClient(baseURLString: "https://yourdomain.com")
            #endif

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
                .environment(\.locale, selectedLocale)
                .environment(\.appleSignInUseCase, appleSignInUseCase)
                .environment(\.deviceRepository, deviceRepository)
        }
    }

    private var selectedLocale: Locale {
        guard let language = AppLanguage(rawValue: appLanguageCode) else {
            return .autoupdatingCurrent
        }

        switch language {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .indonesian:
            return Locale(identifier: "id")
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case indonesian

    var id: String { rawValue }
}

struct AppleSignInUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: AppleSignInUseCase = .init(client: FakeAPI())
}

struct DeviceRepositoryKey: EnvironmentKey {
    @MainActor static let defaultValue: DeviceRepositoryProtocol = FakeDeviceRepository()
}

extension EnvironmentValues {
    var appleSignInUseCase: AppleSignInUseCase {
        get { self[AppleSignInUseCaseKey.self] } set { self[AppleSignInUseCaseKey.self] = newValue }
    }

    var deviceRepository: DeviceRepositoryProtocol {
        get { self[DeviceRepositoryKey.self] } set { self[DeviceRepositoryKey.self] = newValue }
    }
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

    func observeDevices() -> AsyncStream<[DeviceSummary]> {
        AsyncStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
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
