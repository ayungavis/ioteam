import DesignSystem
import SwiftUI

struct SettingsView: View {
    @Environment(AppNotificationManager.self) private var notificationManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.system.rawValue
    @AppStorage(NotificationPrefs.quietFamilyAlertsKey) private var quietFamilyAlerts = false

    private var isAuthorized: Bool {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            Form {
                Section("Notifications") {
                    notificationStatusContent
                }

                if isAuthorized {
                    Section("Family alerts while app is open") {
                        Picker("Family alerts while app is open", selection: $quietFamilyAlerts) {
                            Text("Banner + Sound").tag(false)
                            Text("Silent").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Applies only to missed-dose and confirmation alerts, and only while the app is on screen. Silent still delivers them to Notification Center — nothing is muted. When the app is closed, iOS shows alerts normally.")
                            .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag(AppTheme.system.rawValue)
                        Text("Light").tag(AppTheme.light.rawValue)
                        Text("Dark").tag(AppTheme.dark.rawValue)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
        .task { await notificationManager.syncAuthorizationStatus() }
        .onChange(of: scenePhase) { _, phase in
            // Refresh after the user returns from iOS Settings.
            if phase == .active { Task { await notificationManager.syncAuthorizationStatus() } }
        }
    }

    @ViewBuilder
    private var notificationStatusContent: some View {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.brandSuccess)
                Text("Notifications are enabled").foregroundColor(.brandTextPrimary)
            }
            Text("Dose reminders, missed-dose alerts, and confirmation requests are sent to everyone in your family.")
                .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
            Button("Notification Settings") { openSystemSettings() }
                .foregroundColor(.brandAccent)

        case .denied:
            HStack(spacing: 10) {
                Image(systemName: "bell.slash.fill").foregroundColor(.red)
                Text("Notifications are turned off").foregroundColor(.brandTextPrimary)
            }
            Text("You won't receive dose reminders or missed-dose alerts. Enable notifications in iOS Settings.")
                .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
            Button("Open iOS Settings") { openSystemSettings() }
                .foregroundColor(.brandAccent)

        default:
            Text("Get reminded when it's time to take your medication, and alerted when a family member misses a dose.")
                .font(.system(size: 13)).foregroundColor(.brandTextSecondary)
            Button("Enable Notifications") {
                Task { await notificationManager.requestAuthorizationAfterLogin() }
            }
            .foregroundColor(.brandAccent)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
