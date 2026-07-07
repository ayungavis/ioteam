import DesignSystem
import SwiftUI

struct SettingsView: View {
    @State private var doseReminders = true
    @State private var missedAlerts = true
    @State private var familyActivity = false
    @AppStorage(AppTheme.storageKey) private var appTheme = AppTheme.system.rawValue
    @State private var faceID = false
    @State private var passcode = false

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            Form {
                Section("Notifications") {
                    Toggle("Dose reminders", isOn: $doseReminders).tint(Color.brandAccent)
                    Toggle("Missed dose alerts", isOn: $missedAlerts).tint(Color.brandAccent)
                    Toggle("Family activity", isOn: $familyActivity).tint(Color.brandAccent)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Text("System").tag(AppTheme.system.rawValue)
                        Text("Light").tag(AppTheme.light.rawValue)
                        Text("Dark").tag(AppTheme.dark.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Security") {
                    Toggle("Face ID", isOn: $faceID).tint(Color.brandAccent)
                    Toggle("Passcode", isOn: $passcode).tint(Color.brandAccent)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
        }
    }
}
