//
//  OnboardingView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import DesignSystem
import SwiftUI

struct OnboardingView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()
            
            // Bottle image centered
            Image("bottle")
                .resizable()
                .scaledToFit()
                .frame(height: 260)
                .scaleEffect(animate ? 1.0 : 0.85)
                .opacity(animate ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        animate = true
                    }
                }
        }
        .contentShape(Rectangle()) // Makes the whole screen tapable
        .onTapGesture {
            AppLaunchCoordinator.shared.completeOnboarding()
        }
    }
}

#Preview {
    OnboardingView()
}


