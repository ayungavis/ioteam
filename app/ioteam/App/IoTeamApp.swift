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
    @UIApplicationDelegateAdaptor(IoTeamAppDelegate.self) private var appDelegate

    let sharedContainer: ModelContainer
    let appleSignInUseCase: AppleSignInUseCase
    let getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase
    let updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase
    let createFamilyUseCase: CreateFamilyUseCase
    let joinFamilyUseCase: JoinFamilyUseCase
    let completeOnboardingUseCase: CompleteOnboardingUseCase
    let registerPushTokenUseCase: RegisterPushTokenUseCase
    let registerDeviceUseCase: RegisterDeviceUseCase
    let getMedicinesUseCase: GetMedicinesUseCase
    let previewDosesUseCase: PreviewDosesUseCase
    let createMedicineUseCase: CreateMedicineUseCase
    let getMedicineDosesUseCase: GetMedicineDosesUseCase
    let markDoseTakenUseCase: MarkDoseTakenUseCase
    let getCurrentFamilyUseCase: GetCurrentFamilyUseCase
    let refreshInviteCodeUseCase: RefreshInviteCodeUseCase
    let removeMemberUseCase: RemoveMemberUseCase
    let deviceRepository: DeviceRepositoryProtocol
    let wiFiProvisioningService: WiFiProvisioningServiceProtocol
    let localeManager: LocaleManager

    init() {
        do {
            let schema = Schema([SDDeviceRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.sharedContainer = try ModelContainer(for: schema, configurations: [config])
            let networkClient = URLSessionAPIClient(
                baseURLString: "https://resourceful-generosity-staging.up.railway.app/"
            )

            self.appleSignInUseCase = AppleSignInUseCase(client: networkClient)
            self.getCurrentUserProfileUseCase = GetCurrentUserProfileUseCase(client: networkClient)
            self.updateCurrentUserProfileUseCase = UpdateCurrentUserProfileUseCase(client: networkClient)
            self.createFamilyUseCase = CreateFamilyUseCase(client: networkClient)
            self.joinFamilyUseCase = JoinFamilyUseCase(client: networkClient)
            self.completeOnboardingUseCase = CompleteOnboardingUseCase(client: networkClient)
            self.registerPushTokenUseCase = RegisterPushTokenUseCase(client: networkClient)
            self.registerDeviceUseCase = RegisterDeviceUseCase(client: networkClient)
            self.getMedicinesUseCase = GetMedicinesUseCase(client: networkClient)
            self.previewDosesUseCase = PreviewDosesUseCase(client: networkClient)
            self.createMedicineUseCase = CreateMedicineUseCase(client: networkClient)
            self.getMedicineDosesUseCase = GetMedicineDosesUseCase(client: networkClient)
            self.markDoseTakenUseCase = MarkDoseTakenUseCase(client: networkClient)
            self.getCurrentFamilyUseCase = GetCurrentFamilyUseCase(client: networkClient)
            self.refreshInviteCodeUseCase = RefreshInviteCodeUseCase(client: networkClient)
            self.removeMemberUseCase = RemoveMemberUseCase(client: networkClient)
            self.deviceRepository = DeviceRepository(
                modelContainer: sharedContainer,
                apiClient: networkClient,
                bleClient: BLEDeviceProvisioningClient()
            )
            self.wiFiProvisioningService = WiFiProvisioningService()
            self.localeManager = LocaleManager()
            
            if let accessToken = AppSessionStore.shared.currentSession?.accessToken {
                URLSessionAPIClient.bootstrapSessionToken(accessToken)
            }
            AppNotificationManager.shared.configure(registerPushTokenUseCase: registerPushTokenUseCase)

            AppRouter.shared.currentFlow = AppLaunchCoordinator.shared.determineInitialFlow()
        } catch {
            fatalError("Failed to initialize dependency injection matrix structure: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(AppSessionStore.shared)
                .environment(AppNotificationManager.shared)
                .environment(localeManager)
                .environment(\.appleSignInUseCase, appleSignInUseCase)
                .environment(\.getCurrentUserProfileUseCase, getCurrentUserProfileUseCase)
                .environment(\.updateCurrentUserProfileUseCase, updateCurrentUserProfileUseCase)
                .environment(\.createFamilyUseCase, createFamilyUseCase)
                .environment(\.joinFamilyUseCase, joinFamilyUseCase)
                .environment(\.completeOnboardingUseCase, completeOnboardingUseCase)
                .environment(\.registerDeviceUseCase, registerDeviceUseCase)
                .environment(\.getMedicinesUseCase, getMedicinesUseCase)
                .environment(\.previewDosesUseCase, previewDosesUseCase)
                .environment(\.createMedicineUseCase, createMedicineUseCase)
                .environment(\.getMedicineDosesUseCase, getMedicineDosesUseCase)
                .environment(\.markDoseTakenUseCase, markDoseTakenUseCase)
                .environment(\.getCurrentFamilyUseCase, getCurrentFamilyUseCase)
                .environment(\.refreshInviteCodeUseCase, refreshInviteCodeUseCase)
                .environment(\.removeMemberUseCase, removeMemberUseCase)
                .environment(\.deviceRepository, deviceRepository)
                .environment(\.wiFiProvisioningService, wiFiProvisioningService)
        }
    }
}

struct AppleSignInUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: AppleSignInUseCase = .init(client: FakeAPI())
}

struct DeviceRepositoryKey: EnvironmentKey {
    @MainActor static let defaultValue: DeviceRepositoryProtocol = FakeDeviceRepository()
}

struct GetCurrentUserProfileUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: GetCurrentUserProfileUseCase = .init(client: FakeAPI())
}

struct UpdateCurrentUserProfileUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: UpdateCurrentUserProfileUseCase = .init(client: FakeAPI())
}

struct CreateFamilyUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: CreateFamilyUseCase = .init(client: FakeAPI())
}

struct JoinFamilyUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: JoinFamilyUseCase = .init(client: FakeAPI())
}

struct CompleteOnboardingUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: CompleteOnboardingUseCase = .init(client: FakeAPI())
}

struct RegisterDeviceUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: RegisterDeviceUseCase = .init(client: FakeAPI())
}

struct GetMedicinesUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: GetMedicinesUseCase = .init(client: FakeAPI())
}

struct PreviewDosesUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: PreviewDosesUseCase = .init(client: FakeAPI())
}

struct CreateMedicineUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: CreateMedicineUseCase = .init(client: FakeAPI())
}

struct GetMedicineDosesUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: GetMedicineDosesUseCase = .init(client: FakeAPI())
}

struct MarkDoseTakenUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: MarkDoseTakenUseCase = .init(client: FakeAPI())
}

struct GetCurrentFamilyUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: GetCurrentFamilyUseCase = .init(client: FakeAPI())
}

struct RefreshInviteCodeUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: RefreshInviteCodeUseCase = .init(client: FakeAPI())
}

struct RemoveMemberUseCaseKey: EnvironmentKey {
    @MainActor static let defaultValue: RemoveMemberUseCase = .init(client: FakeAPI())
}

struct WiFiProvisioningServiceKey: EnvironmentKey {
    @MainActor static let defaultValue: WiFiProvisioningServiceProtocol = FakeWiFiProvisioningService()
}

extension EnvironmentValues {
    var appleSignInUseCase: AppleSignInUseCase {
        get { self[AppleSignInUseCaseKey.self] } set { self[AppleSignInUseCaseKey.self] = newValue }
    }

    var getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase {
        get { self[GetCurrentUserProfileUseCaseKey.self] } set { self[GetCurrentUserProfileUseCaseKey.self] = newValue }
    }

    var updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase {
        get { self[UpdateCurrentUserProfileUseCaseKey.self] } set { self[UpdateCurrentUserProfileUseCaseKey.self] = newValue }
    }

    var createFamilyUseCase: CreateFamilyUseCase {
        get { self[CreateFamilyUseCaseKey.self] } set { self[CreateFamilyUseCaseKey.self] = newValue }
    }

    var joinFamilyUseCase: JoinFamilyUseCase {
        get { self[JoinFamilyUseCaseKey.self] } set { self[JoinFamilyUseCaseKey.self] = newValue }
    }

    var completeOnboardingUseCase: CompleteOnboardingUseCase {
        get { self[CompleteOnboardingUseCaseKey.self] } set { self[CompleteOnboardingUseCaseKey.self] = newValue }
    }

    var registerDeviceUseCase: RegisterDeviceUseCase {
        get { self[RegisterDeviceUseCaseKey.self] } set { self[RegisterDeviceUseCaseKey.self] = newValue }
    }

    var getMedicinesUseCase: GetMedicinesUseCase {
        get { self[GetMedicinesUseCaseKey.self] } set { self[GetMedicinesUseCaseKey.self] = newValue }
    }

    var previewDosesUseCase: PreviewDosesUseCase {
        get { self[PreviewDosesUseCaseKey.self] } set { self[PreviewDosesUseCaseKey.self] = newValue }
    }

    var createMedicineUseCase: CreateMedicineUseCase {
        get { self[CreateMedicineUseCaseKey.self] } set { self[CreateMedicineUseCaseKey.self] = newValue }
    }

    var getMedicineDosesUseCase: GetMedicineDosesUseCase {
        get { self[GetMedicineDosesUseCaseKey.self] } set { self[GetMedicineDosesUseCaseKey.self] = newValue }
    }

    var markDoseTakenUseCase: MarkDoseTakenUseCase {
        get { self[MarkDoseTakenUseCaseKey.self] } set { self[MarkDoseTakenUseCaseKey.self] = newValue }
    }

    var getCurrentFamilyUseCase: GetCurrentFamilyUseCase {
        get { self[GetCurrentFamilyUseCaseKey.self] } set { self[GetCurrentFamilyUseCaseKey.self] = newValue }
    }

    var refreshInviteCodeUseCase: RefreshInviteCodeUseCase {
        get { self[RefreshInviteCodeUseCaseKey.self] } set { self[RefreshInviteCodeUseCaseKey.self] = newValue }
    }

    var removeMemberUseCase: RemoveMemberUseCase {
        get { self[RemoveMemberUseCaseKey.self] } set { self[RemoveMemberUseCaseKey.self] = newValue }
    }

    var deviceRepository: DeviceRepositoryProtocol {
        get { self[DeviceRepositoryKey.self] } set { self[DeviceRepositoryKey.self] = newValue }
    }

    var wiFiProvisioningService: WiFiProvisioningServiceProtocol {
        get { self[WiFiProvisioningServiceKey.self] } set { self[WiFiProvisioningServiceKey.self] = newValue }
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

    func pairDevice(discoveryID: UUID, provisioningInfo: DeviceProvisioningInfo) async throws -> DeviceSummary {
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

private final class FakeWiFiProvisioningService: WiFiProvisioningServiceProtocol {
    func currentSSID() async -> String? { nil }
    func joinNetworkIfNeeded(ssid: String, passphrase: String) async throws {
        throw WiFiProvisioningError.unsupported
    }
}
