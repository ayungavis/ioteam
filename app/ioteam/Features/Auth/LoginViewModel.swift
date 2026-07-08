//
//  LoginViewModel.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import Data
import Domain
import SwiftUI

@Observable
public final class LoginViewModel {
    public var isAuthenticating = false
    public var loginErrorMessage: String?
    
    private let appleSignInUseCase: AppleSignInUseCase
    
    public init(appleSignInUseCase: AppleSignInUseCase) {
        self.appleSignInUseCase = appleSignInUseCase
    }
    
    @MainActor
    public func processAppleAuthentication(token: String, fullName: String?) async {
        isAuthenticating = true
        loginErrorMessage = nil
        
        do {
            // Exchange the Apple token with your backend API server
            let session = try await appleSignInUseCase.execute(
                identityToken: token,
                fullName: fullName
            )
            
            // HTTP INTERCEPTOR HOOK: Save token to intercept future API requests
            await URLSessionAPIClient.updateSessionToken(session.accessToken)
            AppLaunchCoordinator.shared.loginSuccess(session: session)
            // Notification permission is requested after onboarding (first dashboard visit),
            // not here — asking mid-login hurts opt-in rates.
            
            isAuthenticating = false
        } catch {
            loginErrorMessage = error.localizedDescription
            isAuthenticating = false
        }
    }
}
