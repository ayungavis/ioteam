//
//  HomeTabCoordinatorView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Foundation
import SwiftUI

struct HomeTabCoordinatorView: View {
    @State private var tabRouter = HomeTabRouter()

    // Extracted global DI resolution hooks passed down from App initialization runtime
    @Environment(\.getTasksUseCase) private var getTasksUseCase
    @Environment(\.taskRepository) private var repository

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            NavigationStack(path: $tabRouter.homePath) {
                let viewModel = TaskListViewModel(getTasksUseCase: getTasksUseCase, repository: repository)
                TaskListView(viewModel: viewModel)
                    .navigationDestination(for: HomeNavigationDestination.self) { destination in
                        switch destination {
                        case .taskDetail(let id):
                            Text("Workspace Task ID: \(id.uuidString)").navigationTitle("Detail View")
                        }
                    }
                    .onAppear {
                        viewModel.onSessionExpired = {
                            AppLaunchCoordinator.shared.logout()
                        }
                    }
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }.tag(AppTab.home)

            NavigationStack(path: $tabRouter.profilePath) {
                VStack(spacing: 20) {
                    Text("Profile Dashboard View Layout")
                    Button("Logout Operations Trigger") { AppLaunchCoordinator.shared.logout() }
                }
                .navigationTitle("Profile Control")
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(AppTab.profile)
        }
        .environment(tabRouter)
    }
}
