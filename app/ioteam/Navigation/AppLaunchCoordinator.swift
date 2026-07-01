//
//  AppLaunchCoordinator.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Data
import SwiftUI

@Observable
public final class AppLaunchCoordinator {
    @MainActor public static let shared = AppLaunchCoordinator()
    private init() {}
    
    @MainActor func determineInitialFlow() -> AppFlowState {
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") { return .onboarding }
        if !UserDefaults.standard.bool(forKey: "userIsAuthenticated") { return .authentication }
        return .dashboard
    }
    
    @MainActor func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        AppRouter.shared.changeFlow(to: .authentication)
    }
    
    @MainActor func loginSuccess() {
        UserDefaults.standard.set(true, forKey: "userIsAuthenticated")
        AppRouter.shared.changeFlow(to: .dashboard)
    }
    
    @MainActor
    func logout() {
        UserDefaults.standard.set(false, forKey: "userIsAuthenticated")
        
        Task {
            // Clear runtime bearer headers out immediately to protect user privacy
            await URLSessionAPIClient.clearSessionToken()
        }
        
        AppRouter.shared.changeFlow(to: .authentication)
    }
}
