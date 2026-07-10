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
    @Environment(LocaleManager.self) private var localeManager
    @Environment(\.appleSignInUseCase) private var appleSignInUseCase
    @Environment(\.getCurrentUserProfileUseCase) private var getCurrentUserProfileUseCase
    @Environment(\.updateCurrentUserProfileUseCase) private var updateCurrentUserProfileUseCase
    @Environment(\.createFamilyUseCase) private var createFamilyUseCase
    @Environment(\.joinFamilyUseCase) private var joinFamilyUseCase
    @Environment(\.completeOnboardingUseCase) private var completeOnboardingUseCase

    var body: some View {
        Group {
            switch router.currentFlow {
            case .onboarding:
                OnboardingView()
            case .authentication:
                LoginView(viewModel: LoginViewModel(appleSignInUseCase: appleSignInUseCase))
            case .profileOnboarding:
                ProfileOnboardingView(
                    viewModel: ProfileOnboardingViewModel(
                        getCurrentUserProfileUseCase: getCurrentUserProfileUseCase,
                        updateCurrentUserProfileUseCase: updateCurrentUserProfileUseCase
                    )
                )
            case .familySetup:
                FamilySetupView(
                    viewModel: FamilySetupViewModel(
                        createFamilyUseCase: createFamilyUseCase,
                        joinFamilyUseCase: joinFamilyUseCase,
                        completeOnboardingUseCase: completeOnboardingUseCase
                    )
                )
            case .dashboard:
                HomeTabCoordinatorView()
            }
        }
        .environment(\.locale, localeManager.locale)
        .keyboardDismissal()
    }
}
