//
//  AppRouter.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import SwiftUI

public enum AppFlowState { case onboarding, authentication, profileOnboarding, familySetup, dashboard }

@Observable
public final class AppRouter {
    public static let shared = AppRouter()
    public var currentFlow: AppFlowState = .authentication
    private init() {}

    @MainActor public func changeFlow(to newState: AppFlowState) {
        withAnimation(.easeInOut(duration: 0.3)) { self.currentFlow = newState }
    }
}
