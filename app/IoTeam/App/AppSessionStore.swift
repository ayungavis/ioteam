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
    private let familyIdKey = "app_family_id"
    private let deviceIdKey = "app_device_id"
    private let deviceNameKey = "app_device_name"

    private(set) var currentSession: AuthSession?
    private(set) var familyId: String?
    private(set) var deviceId: String?
    private(set) var deviceName: String?

    private init() {
        currentSession = loadPersistedSession()
        familyId = UserDefaults.standard.string(forKey: familyIdKey)
        deviceId = UserDefaults.standard.string(forKey: deviceIdKey)
        deviceName = UserDefaults.standard.string(forKey: deviceNameKey)
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

    func saveFamilyAndDevice(familyId: String, deviceId: String, deviceName: String) {
        self.familyId = familyId
        self.deviceId = deviceId
        self.deviceName = deviceName
        UserDefaults.standard.set(familyId, forKey: familyIdKey)
        UserDefaults.standard.set(deviceId, forKey: deviceIdKey)
        UserDefaults.standard.set(deviceName, forKey: deviceNameKey)
    }

    func clear() {
        currentSession = nil
        familyId = nil; deviceId = nil; deviceName = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.removeObject(forKey: familyIdKey)
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
        UserDefaults.standard.removeObject(forKey: deviceNameKey)
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
