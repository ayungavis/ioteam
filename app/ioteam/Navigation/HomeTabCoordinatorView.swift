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
    @State private var tabRouter = HomeTabRouter()
    @Environment(\.deviceRepository) private var deviceRepository
    @Environment(\.wiFiProvisioningService) private var wiFiProvisioningService

    var body: some View {
        let observeDevicesUseCase = ObserveDevicesUseCase(repository: deviceRepository)
        let startDeviceScanUseCase = StartDeviceScanUseCase(repository: deviceRepository)
        let stopDeviceScanUseCase = StopDeviceScanUseCase(repository: deviceRepository)
        let pairDeviceUseCase = PairDeviceUseCase(repository: deviceRepository)
        let renameDeviceUseCase = RenameDeviceUseCase(repository: deviceRepository)
        let setDeviceEnabledUseCase = SetDeviceEnabledUseCase(repository: deviceRepository)
        let deleteDeviceUseCase = DeleteDeviceUseCase(repository: deviceRepository)

        TabView(selection: $tabRouter.selectedTab) {
            NavigationStack(path: $tabRouter.homePath) {
                HomeView(
                    viewModel: HomeViewModel(
                        observeDevicesUseCase: observeDevicesUseCase,
                        setDeviceEnabledUseCase: setDeviceEnabledUseCase
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

            NavigationStack(path: $tabRouter.medicinePath) {
                MedicineListView()
                    .tint(Color.brandAccent)
                    .navigationDestination(for: HomeNavigationDestination.self) { destination in
                        switch destination {
                        case .medicineDetail(let medicine):
                            MedicineDetailView(mode: .edit(medicine))
                        case .deviceDetail:
                            EmptyView()
                        }
                    }
            }
            .tint(Color.brandAccent)
            .tabItem { Label("Medicine", systemImage: "pills") }.tag(AppTab.medicine)

            NavigationStack(path: $tabRouter.profilePath) {
                ProfileView(observeDevicesUseCase: observeDevicesUseCase)
            }
            .tint(Color.brandAccent)
            .tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .tint(Color.brandAccent)
        .id(localeManager.languageCode)
        .environment(tabRouter)
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
