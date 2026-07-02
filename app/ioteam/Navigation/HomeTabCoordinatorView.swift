//
//  HomeTabCoordinatorView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Domain
import Foundation
import SwiftUI

struct HomeTabCoordinatorView: View {
    @AppStorage("appLanguageCode") private var appLanguageCode = AppLanguage.system.rawValue
    @State private var tabRouter = HomeTabRouter()
    @State private var wiFiProvisioningService = WiFiProvisioningService()
    @Environment(\.deviceRepository) private var deviceRepository

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
                DeviceListView(
                    viewModel: DeviceListViewModel(observeDevicesUseCase: observeDevicesUseCase),
                    makeAddDeviceView: {
                        AddDeviceView(
                            viewModel: AddDeviceViewModel(
                                startDeviceScanUseCase: startDeviceScanUseCase,
                                stopDeviceScanUseCase: stopDeviceScanUseCase,
                                pairDeviceUseCase: pairDeviceUseCase,
                                wiFiProvisioningService: wiFiProvisioningService
                            )
                        )
                    }
                )
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
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)

            NavigationStack(path: $tabRouter.profilePath) {
                DeviceProfileView(observeDevicesUseCase: observeDevicesUseCase)
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .id(appLanguageCode)
        .environment(tabRouter)
    }
}

private struct DeviceProfileView: View {
    @AppStorage("appLanguageCode") private var appLanguageCode = AppLanguage.system.rawValue
    let observeDevicesUseCase: ObserveDevicesUseCase
    @State private var deviceCount = 0

    var body: some View {
        Form {
            Section("DoseLatch") {
                LabeledContent("Devices", value: deviceCount.formatted())
                Text("Family and medicine flows are still mocked out for this prototype.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("App Language") {
                Picker("App Language", selection: $appLanguageCode) {
                    Text("System").tag(AppLanguage.system.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                    Text("Indonesian").tag(AppLanguage.indonesian.rawValue)
                }
            }

            Section("Session") {
                Button("Logout", role: .destructive) {
                    AppLaunchCoordinator.shared.logout()
                }
            }
        }
        .navigationTitle("Profile")
        .task {
            let stream = observeDevicesUseCase.execute()
            for await devices in stream {
                deviceCount = devices.count
            }
        }
    }
}
