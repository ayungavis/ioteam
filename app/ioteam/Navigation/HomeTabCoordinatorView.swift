//
//  HomeTabCoordinatorView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import DesignSystem
import Domain
import Foundation
import SwiftUI

struct HomeTabCoordinatorView: View {
    @Environment(LocaleManager.self) private var localeManager
    @Environment(AppNotificationManager.self) private var notificationManager
    @Environment(\.deviceRepository) private var deviceRepository
    @Environment(\.wiFiProvisioningService) private var wiFiProvisioningService
    @Environment(\.getMedicinesUseCase) private var getMedicinesUseCase
    @Environment(\.getMedicineDosesUseCase) private var getMedicineDosesUseCase
    @Environment(\.markDoseTakenUseCase) private var markDoseTakenUseCase

    var body: some View {
        let observeDevicesUseCase = ObserveDevicesUseCase(repository: deviceRepository)
        let startDeviceScanUseCase = StartDeviceScanUseCase(repository: deviceRepository)
        let stopDeviceScanUseCase = StopDeviceScanUseCase(repository: deviceRepository)
        let pairDeviceUseCase = PairDeviceUseCase(repository: deviceRepository)
        let renameDeviceUseCase = RenameDeviceUseCase(repository: deviceRepository)
        let setDeviceEnabledUseCase = SetDeviceEnabledUseCase(repository: deviceRepository)
        let deleteDeviceUseCase = DeleteDeviceUseCase(repository: deviceRepository)

        TabView(selection: Binding(get: { HomeTabRouter.shared.selectedTab }, set: { HomeTabRouter.shared.selectedTab = $0 })) {
            NavigationStack(path: Binding(get: { HomeTabRouter.shared.homePath }, set: { HomeTabRouter.shared.homePath = $0 })) {
                HomeView(
                    viewModel: HomeViewModel(
                        observeDevicesUseCase: observeDevicesUseCase,
                        setDeviceEnabledUseCase: setDeviceEnabledUseCase,
                        refreshDevicesUseCase: RefreshDevicesUseCase(repository: deviceRepository)
                    ),
                    doseAttentionViewModel: DoseAttentionViewModel(
                        getMedicinesUseCase: getMedicinesUseCase,
                        getMedicineDosesUseCase: getMedicineDosesUseCase,
                        markDoseTakenUseCase: markDoseTakenUseCase
                    ),
                    scheduleViewModel: ScheduleViewModel(
                        getMedicinesUseCase: getMedicinesUseCase,
                        getMedicineDosesUseCase: getMedicineDosesUseCase,
                        markDoseTakenUseCase: markDoseTakenUseCase
                    ),
                    makeConnectDeviceView: {
                        ConnectDeviceView(
                            viewModel: AddDeviceViewModel(
                                startDeviceScanUseCase: startDeviceScanUseCase,
                                stopDeviceScanUseCase: stopDeviceScanUseCase,
                                pairDeviceUseCase: pairDeviceUseCase,
                                wiFiProvisioningService: wiFiProvisioningService
                            ),
                            onComplete: {}
                        )
                    }
                )
                    .tint(Color.brandAccent)
                    .navigationDestination(for: HomeNavigationDestination.self) { destination in
                        switch destination {
                        case .deviceDetail(let id):
                            DeviceDetailView(
                                viewModel: DeviceDetailViewModel(
                                    deviceID: id,
                                    observeDevicesUseCase: observeDevicesUseCase,
                                    renameDeviceUseCase: renameDeviceUseCase,
                                    setDeviceEnabledUseCase: setDeviceEnabledUseCase,
                                    deleteDeviceUseCase: deleteDeviceUseCase
                                )
                            )
                        case .medicineDetail:
                            EmptyView()
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)

            NavigationStack(path: Binding(get: { HomeTabRouter.shared.medicinePath }, set: { HomeTabRouter.shared.medicinePath = $0 })) {
                MedicineListView()
                    .tint(Color.brandAccent)
                    .navigationDestination(for: HomeNavigationDestination.self) { destination in
                        switch destination {
                        case .medicineDetail(let medicineID, let filterRaw):
                            MedicineDetailView(
                                mode: .edit(medicineID: medicineID),
                                initialDoseFilter: filterRaw.flatMap { DoseFilter(rawValue: $0) }
                            )
                        default:
                            EmptyView()
                        }
                    }
            }
            .tint(Color.brandAccent)
            .tabItem { Label("Medicine", systemImage: "pills") }.tag(AppTab.medicine)

            NavigationStack(path: Binding(get: { HomeTabRouter.shared.profilePath }, set: { HomeTabRouter.shared.profilePath = $0 })) {
                ProfileView(observeDevicesUseCase: observeDevicesUseCase)
            }
            .tint(Color.brandAccent)
            .tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .tint(Color.brandAccent)
        .id(localeManager.languageCode)
        .environment(HomeTabRouter.shared)
        .task {
            await notificationManager.requestAuthorizationAfterLogin()
            await notificationManager.refreshRemoteNotificationsIfPossible()
            notificationManager.consumePendingRoute(using: HomeTabRouter.shared)
        }
        .onChange(of: notificationManager.pendingRoute) { _, _ in
            notificationManager.consumePendingRoute(using: HomeTabRouter.shared)
        }
    }
}

//private struct DeviceProfileView: View {
//    @Environment(LocaleManager.self) private var localeManager
//    let observeDevicesUseCase: ObserveDevicesUseCase
//    @State private var deviceCount = 0
//
//    var body: some View {
//        Form {
//            Section("DoseLatch") {
//                LabeledContent("Devices", value: deviceCount.formatted())
//                Text("Family and medicine flows are still mocked out for this prototype.")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//            }
//
//            Section("App Language") {
//                @Bindable var localeManager = localeManager
//                Picker("App Language", selection: $localeManager.languageCode) {
//                    Text("System").tag(AppLanguage.system.rawValue)
//                    Text("English").tag(AppLanguage.english.rawValue)
//                    Text("Indonesian").tag(AppLanguage.indonesian.rawValue)
//                }
//            }
//
//            Section("Session") {
//                Button("Logout", role: .destructive) {
//                    AppLaunchCoordinator.shared.logout()
//                }
//            }
//        }
//        .navigationTitle("Profile")
//        .task {
//            let stream = observeDevicesUseCase.execute()
//            for await devices in stream {
//                deviceCount = devices.count
//            }
//        }
//    }
//}
