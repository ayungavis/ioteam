//
//  LoginView.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 01/07/26.
//

import AuthenticationServices
import DesignSystem
import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 25) {
            Text("Secure Access Gateway").font(.title).bold()
            
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        let userId = credential.user
                        if let tokenData = credential.identityToken, let tokenStr = String(data: tokenData, encoding: .utf8) {
                            Task { await viewModel.processAppleAuthentication(token: tokenStr, userId: userId) }
                        }
                    }
                case .failure(let err):
                    viewModel.loginErrorMessage = err.localizedDescription
                }
            }
            .frame(height: 50).padding(.horizontal)
            
            if let error = viewModel.loginErrorMessage {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }
}
