//
//  OnboardingView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import DesignSystem
import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("Welcome to Hackathon App! 🚀").font(.largeTitle).bold().multilineTextAlignment(.center)
            Text("Offline-first synchronization with SwiftData engine configuration ready.").foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Get Started") { AppLaunchCoordinator.shared.completeOnboarding() }
        }.padding()
    }
}
