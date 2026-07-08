//
//  AppNotificationManager.swift
//  IoTeam
//
//  Created by Wahyu Kurniawan on 03/07/26.
//

import Domain
import Foundation
import Observation
import SwiftUI
import UIKit
import UserNotifications

struct PendingNotificationRoute: Equatable, Sendable {
    let doseId: String
    let kind: String
}

/// User-facing notification preference, stored locally per phone —
/// the backend broadcasts identically to the whole family, so this
/// presentation choice lives entirely on-device.
enum NotificationPrefs {
    /// How family alerts (missed / needs confirmation) present while the app is open on screen.
    static let quietFamilyAlertsKey = "notif_quiet_family_alerts"

    static var quietFamilyAlerts: Bool {
        UserDefaults.standard.bool(forKey: quietFamilyAlertsKey)
    }
}


@Observable
@MainActor
final class AppNotificationManager {
    static let shared = AppNotificationManager()
    
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var pendingRoute: PendingNotificationRoute?
    
    private var currentDeviceToken: String?
    private var registerPushTokenUseCase: RegisterPushTokenUseCase?

    private init() {}

    func configure(registerPushTokenUseCase: RegisterPushTokenUseCase) {
        self.registerPushTokenUseCase = registerPushTokenUseCase
    }
    
    func syncAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }
    
    func requestAuthorizationAfterLogin() async {
        await syncAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            await registerCurrentTokenIfPossible()
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
                await syncAuthorizationStatus()
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("Failed to request notification authorization: \(error.localizedDescription)")
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }
    
    func refreshRemoteNotificationsIfPossible() async {
        await syncAuthorizationStatus()
        guard AppSessionStore.shared.isAuthenticated else {
            return
        }
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            await registerCurrentTokenIfPossible()
        case .notDetermined, .denied:
            break
        @unknown default:
            break
        }
    }
    
    func handleRegisteredDeviceToken(_ deviceToken: Data) {
        currentDeviceToken = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            await registerCurrentTokenIfPossible()
        }
    }
    
    func handleRemoteNotificationRegistrationFailure(_ error: Error) {
        print("Remote notification registration failed: \(error.localizedDescription)")
    }
    
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let route = makePendingRoute(from: userInfo) else {
            return
        }
        pendingRoute = route
    }

    /// Switches to the Home tab (which hosts the schedule); the schedule section then
    /// consumes the route via `takePendingDoseRoute()` and shows a one-tap confirmation.
    func consumePendingRoute(using tabRouter: HomeTabRouter) {
        guard pendingRoute != nil else {
            return
        }
        tabRouter.selectedTab = .home
        tabRouter.homePath = NavigationPath()
    }

    func takePendingDoseRoute() -> PendingNotificationRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    // MARK: - Foreground presentation

    /// How a notification presents while the app is in the foreground:
    /// dose reminders stay prominent; family alerts (missed / confirmation) can be quiet.
    nonisolated static func presentationOptions(forKind kind: String?) -> UNNotificationPresentationOptions {
        switch kind {
        case "missed", "needs_confirmation":
            return NotificationPrefs.quietFamilyAlerts ? [.list] : [.banner, .list, .sound]
        default:
            return [.banner, .list, .sound]
        }
    }
    
    private func registerCurrentTokenIfPossible() async {
        guard AppSessionStore.shared.isAuthenticated,
              let registerPushTokenUseCase,
              let currentDeviceToken
        else {
            return
        }
        do {
            try await registerPushTokenUseCase.execute(token: currentDeviceToken)
        } catch {
            print("Failed to register APNS token: \(error.localizedDescription)")
        }
    }
    
    private func makePendingRoute(from userInfo: [AnyHashable: Any]) -> PendingNotificationRoute? {
        guard let doseId = userInfo["doseId"] as? String,
              let kind = userInfo["kind"] as? String
        else {
            return nil
        }
        return PendingNotificationRoute(doseId: doseId, kind: kind)
    }
}
