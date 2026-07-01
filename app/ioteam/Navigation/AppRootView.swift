//
//  AppRootView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import DesignSystem
import Domain
import Foundation
import SwiftUI

struct AppRootView: View {
    @State private var router = AppRouter.shared
    @Environment(\.appleSignInUseCase) private var appleSignInUseCase

    var body: some View {
        Group {
            switch router.currentFlow {
            case .onboarding:
                OnboardingView()
            case .authentication:
                LoginView(viewModel: LoginViewModel(appleSignInUseCase: appleSignInUseCase))
            case .dashboard:
                HomeTabCoordinatorView()
            }
        }
    }
}
