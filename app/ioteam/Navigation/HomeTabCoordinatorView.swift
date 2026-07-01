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
    @State private var tabRouter = HomeTabRouter()
    @Environment(\.deviceRepository) private var deviceRepository

    var body: some View {
        let getDevicesUseCase = GetDevicesUseCase(repository: deviceRepository)
        let startDeviceScanUseCase = StartDeviceScanUseCase(repository: deviceRepository)
        let stopDeviceScanUseCase = StopDeviceScanUseCase(repository: deviceRepository)
        let pairDeviceUseCase = PairDeviceUseCase(repository: deviceRepository)
        let renameDeviceUseCase = RenameDeviceUseCase(repository: deviceRepository)
        let setDeviceEnabledUseCase = SetDeviceEnabledUseCase(repository: deviceRepository)
        let deleteDeviceUseCase = DeleteDeviceUseCase(repository: deviceRepository)

        TabView(selection: $tabRouter.selectedTab) {
            NavigationStack(path: $tabRouter.homePath) {
                DeviceListView(
                    viewModel: DeviceListViewModel(getDevicesUseCase: getDevicesUseCase),
                    makeAddDeviceView: {
                        AddDeviceView(
                            viewModel: AddDeviceViewModel(
                                startDeviceScanUseCase: startDeviceScanUseCase,
                                stopDeviceScanUseCase: stopDeviceScanUseCase,
                                pairDeviceUseCase: pairDeviceUseCase
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
                                    getDevicesUseCase: getDevicesUseCase,
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
                DeviceProfileView(getDevicesUseCase: getDevicesUseCase)
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .environment(tabRouter)
    }
}

private struct DeviceProfileView: View {
    let getDevicesUseCase: GetDevicesUseCase
    @State private var deviceCount = 0

    var body: some View {
        Form {
            Section("DoseLatch") {
                LabeledContent("Devices", value: "\(deviceCount)")
                Text("Family and medicine flows are still mocked out for this prototype.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Session") {
                Button("Logout", role: .destructive) {
                    AppLaunchCoordinator.shared.logout()
                }
            }
        }
        .navigationTitle("Profile")
        .task {
            deviceCount = (try? await getDevicesUseCase.execute().count) ?? 0
        }
    }
}
