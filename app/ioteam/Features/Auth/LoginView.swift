//
//  LoginView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import AuthenticationServices
import DesignSystem
import Domain
import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Bottle image (B&W) in the center of the top half
                Image("bottle-bnw")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding(.bottom, 40)
                
                // Title and Subtitle text block
                VStack(spacing: 16) {
                    Text("Smart Box. Simple Tracking.\nSafe Family.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.brandAccentStrong)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Text("Connect your smart pill box to track real intake, not just reminders. Accurate health tracking for you and your loved ones.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 50)
                
                // Login Buttons
                VStack(spacing: 12) {

                    // Apple Sign-In Button (Production flow)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                let userId = credential.user
                                let tokenStr = credential.identityToken
                                    .flatMap { String(data: $0, encoding: .utf8) }
                                    ?? ""
                                Task { await viewModel.processAppleAuthentication(token: tokenStr, userId: userId) }
                            } else {
                                viewModel.loginErrorMessage = "Could not retrieve Apple credentials."
                            }
                        case .failure(let err):
                            if let authError = err as? ASAuthorizationError {
                                switch authError.code {
                                case .canceled:
                                    viewModel.loginErrorMessage = "Sign-in canceled. On the Simulator, sign in to your Apple Account under Settings → Apple Account, then try again."
                                case .failed, .notHandled, .notInteractive:
                                    viewModel.loginErrorMessage = "Apple sign-in failed (code \(authError.code.rawValue)): \(authError.localizedDescription)"
                                @unknown default:
                                    viewModel.loginErrorMessage = "Apple sign-in failed (code \(authError.code.rawValue)): \(authError.localizedDescription)"
                                }
                            } else {
                                viewModel.loginErrorMessage = err.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(Capsule())

                    #if DEBUG
                    Button {
                        Task { await viewModel.processAppleAuthentication(token: "mock-token", userId: "mock-user") }
                    } label: {
                        Text("Skip sign-in (Debug)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.brandAccentStrong)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                Capsule().stroke(Color.brandAccentStrong, lineWidth: 1.5)
                            )
                    }
                    #endif
                }
                .padding(.horizontal, 24)

                // Error display
                if let error = viewModel.loginErrorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                if viewModel.isAuthenticating {
                    ProgressView("Signing in...")
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Footer
                HStack(spacing: 4) {
                    Text("Don’t have an account?")
                        .font(.system(size: 14))
                        .foregroundColor(Color.brandTextSecondary)
                    Button(action: {
                        // Reset onboarding and transition to OnboardingView for easier testing
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                        AppRouter.shared.changeFlow(to: .onboarding)
                    }) {
                        Text("Get Started")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.brandAccentStrong)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel(appleSignInUseCase: AppleSignInUseCase(client: MockAPIClient())))
}
