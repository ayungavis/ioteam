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
    public func processAppleAuthentication(token: String, userId: String) async {
        isAuthenticating = true
        loginErrorMessage = nil
        
        do {
            // Exchange the Apple token with your backend API server
            let sessionTokenPayload = try await appleSignInUseCase.execute(
                identityToken: token,
                userIdentifier: userId
            )
            
            // HTTP INTERCEPTOR HOOK: Save token to intercept future API requests
            await URLSessionAPIClient.updateSessionToken(sessionTokenPayload.accessToken)
            
            // Move the user directly to the app dashboard
            AppLaunchCoordinator.shared.loginSuccess()
            isAuthenticating = false
        } catch {
            loginErrorMessage = error.localizedDescription
            isAuthenticating = false
        }
    }
}
