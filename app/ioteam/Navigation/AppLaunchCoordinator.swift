//
//  AppLaunchCoordinator.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Data
import Domain
import SwiftUI

@Observable
public final class AppLaunchCoordinator {
    @MainActor public static let shared = AppLaunchCoordinator()
    private init() {}
    
    @MainActor func determineInitialFlow() -> AppFlowState {
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") { return .onboarding }
        if !AppSessionStore.shared.isAuthenticated { return .authentication }
        if !UserDefaults.standard.bool(forKey: "hasCompletedProfileOnboarding") { return .profileOnboarding }
        if !UserDefaults.standard.bool(forKey: "hasCompletedFamilySetup") { return .familySetup }
        return .dashboard
    }

    @MainActor func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        AppRouter.shared.changeFlow(to: .authentication)
    }

    @MainActor func loginSuccess(session: AuthSession) {
        AppSessionStore.shared.save(session: session)
        UserDefaults.standard.set(true, forKey: "userIsAuthenticated")
        if !UserDefaults.standard.bool(forKey: "hasCompletedProfileOnboarding") {
            AppRouter.shared.changeFlow(to: .profileOnboarding)
        } else if !UserDefaults.standard.bool(forKey: "hasCompletedFamilySetup") {
            AppRouter.shared.changeFlow(to: .familySetup)
        } else {
            AppRouter.shared.changeFlow(to: .dashboard)
        }
    }

    @MainActor func completeProfileOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedProfileOnboarding")
        AppRouter.shared.changeFlow(to: .familySetup)
    }

    @MainActor func completeFamilySetup() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")
        AppRouter.shared.changeFlow(to: .dashboard)
    }

    @MainActor
    func syncCompletedOnboardingFromBackend() {
        AppSessionStore.shared.markOnboardingCompleted()
        UserDefaults.standard.set(true, forKey: "hasCompletedProfileOnboarding")
        UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")
        AppRouter.shared.changeFlow(to: .dashboard)
    }

    @MainActor
    func logout() {
        Task { @MainActor in
            await AppNotificationManager.shared.unregisterCurrentTokenBeforeLogout()

            AppSessionStore.shared.clear()
            UserDefaults.standard.set(false, forKey: "userIsAuthenticated")
            UserDefaults.standard.set(false, forKey: "hasCompletedProfileOnboarding")
            UserDefaults.standard.set(false, forKey: "hasCompletedFamilySetup")

            // Keep the bearer token until APNS cleanup finishes, then clear it.
            await URLSessionAPIClient.clearSessionToken()

            AppRouter.shared.changeFlow(to: .authentication)
        }
    }
}
