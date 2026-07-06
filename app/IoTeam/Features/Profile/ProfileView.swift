import DesignSystem
import Domain
import SwiftUI

struct ProfileView: View {
    @Environment(LocaleManager.self) private var localeManager
    @Environment(AppSessionStore.self) private var sessionStore
    @Environment(\.logoutUseCase) private var logoutUseCase
    let observeDevicesUseCase: ObserveDevicesUseCase
    @State private var deviceCount = 0
    @State private var isLoggingOut = false

    var body: some View {
        @Bindable var bindableLocale = localeManager

        ZStack {
            Color.brandSurface.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("Profile")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.brandTextPrimary)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                ScrollView {
                    VStack(spacing: 24) {
                        // MARK: - User Card
                        HStack(spacing: 16) {
                            AvatarCircle(name: displayName)
                                .frame(width: 60, height: 60)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.brandTextPrimary)
                                Text(displayEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(.brandTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.brandCard)
                        .cornerRadius(16)

                        // MARK: - Menu
                        VStack(spacing: 0) {
                            NavigationLink(destination: ManageDevicesView(viewModel: ProfileDevicesViewModel(observeDevicesUseCase: observeDevicesUseCase))) {
                                ProfileMenuRow(iconName: "antenna.radiowaves.left.and.right", title: "Manage Devices", value: "\(deviceCount)", showDivider: true)
                            }

                            NavigationLink(destination: ManageFamilyView()) {
                                ProfileMenuRow(iconName: "person.2", title: "Manage Family", showDivider: true)
                            }

                            NavigationLink(destination: AccountSettingsView()) {
                                ProfileMenuRow(iconName: "person.circle", title: "Manage Account", showDivider: true)
                            }

                            NavigationLink(destination: SettingsView()) {
                                ProfileMenuRow(iconName: "gearshape", title: "Settings", showDivider: false)
                            }
                        }
                        .background(Color.brandCard)
                        .cornerRadius(16)

                        // MARK: - Language
                        HStack(spacing: 16) {
                            Image(systemName: "globe")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.brandTextPrimary)
                                .frame(width: 28, alignment: .center)

                            Text("App Language")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.brandTextPrimary)

                            Spacer()

                            Picker("", selection: $bindableLocale.languageCode) {
                                Text("System").tag(AppLanguage.system.rawValue)
                                Text("English").tag(AppLanguage.english.rawValue)
                                Text("Indonesian").tag(AppLanguage.indonesian.rawValue)
                            }
                            .pickerStyle(.menu)
                            .tint(Color.brandTextSecondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.brandCard)
                        .cornerRadius(16)

                        Spacer(minLength: 20)

                        Button(role: .destructive) {
                            guard !isLoggingOut else { return }
                            isLoggingOut = true
                            Task {
                                // Best-effort server-side logout; always clear locally so
                                // a network failure can't leave the user stuck signed in.
                                try? await logoutUseCase.execute()
                                AppLaunchCoordinator.shared.logout()
                                isLoggingOut = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isLoggingOut {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                }
                                Text("Logout")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            let stream = observeDevicesUseCase.execute()
            for await devices in stream {
                deviceCount = devices.count
            }
        }
    }

    private var displayName: String { sessionStore.currentUser?.fullName ?? "User" }
    private var displayEmail: String { sessionStore.currentUser?.email ?? "" }
}

private struct AvatarCircle: View {
    let name: String
    var initials: String { name.split(separator: " ").compactMap { $0.first }.map { String($0) }.joined().prefix(2).uppercased() }

    var body: some View {
        ZStack {
            Circle().fill(Color.brandAccent)
            Text(initials).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
        }
    }
}

struct ProfileMenuRow: View {
    let iconName: String
    let title: String
    var value: String? = nil
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.brandTextPrimary)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.brandTextPrimary)
                Spacer()
                if let value {
                    Text(value).font(.system(size: 16, weight: .regular)).foregroundColor(.brandTextSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandTextTertiary)
            }
            .padding(.vertical, 16).padding(.horizontal, 16)
            if showDivider { Divider().padding(.leading, 60) }
        }
        .background(Color.brandCard)
    }
}
