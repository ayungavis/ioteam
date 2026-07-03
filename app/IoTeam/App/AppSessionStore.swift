//
//  AppSessionStore.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Domain
import Foundation
import Observation

@Observable
@MainActor
final class AppSessionStore {
    static let shared = AppSessionStore()
    
    private let sessionKey = "app_user_session"
    
    private(set) var currentSession: AuthSession?
    
    private init() {
        currentSession = loadPersistedSession()
    }
    
    var isAuthenticated: Bool {
        currentSession != nil
    }
    
    var currentUser: AuthenticatedUser? {
        currentSession?.user
    }
    
    func save(session: AuthSession) {
        currentSession = session
        persist(session: session)
    }

    func updateCurrentUser(_ user: AuthenticatedUser) {
        guard let currentSession else {
            return
        }
        save(session: AuthSession(accessToken: currentSession.accessToken, user: user))
    }

    func markOnboardingCompleted() {
        guard let currentUser else {
            return
        }
        let updatedUser = AuthenticatedUser(
            id: currentUser.id,
            email: currentUser.email,
            fullName: currentUser.fullName,
            dateOfBirth: currentUser.dateOfBirth,
            onboardingCompleted: true
        )
        updateCurrentUser(updatedUser)
    }
    
    func clear() {
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
    private func loadPersistedSession() -> AuthSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
    
    private func persist(session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }
        UserDefaults.standard.set(data, forKey: sessionKey)
    }
}
