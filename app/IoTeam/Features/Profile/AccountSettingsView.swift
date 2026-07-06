import DesignSystem
import Domain
import SwiftUI

@Observable
@MainActor
final class AccountSettingsViewModel {
    var fullName = ""
    var dateOfBirth: Date?
    var isLoading = false
    var isSaving = false
    var isDeleting = false
    var errorMessage: String?
    var didSave = false

    private var originalFullName = ""
    private var originalDateOfBirth: Date?

    private let getProfile: GetCurrentUserProfileUseCase
    private let updateProfile: UpdateCurrentUserProfileUseCase
    private let deleteAccount: DeleteAccountUseCase

    init(getProfile: GetCurrentUserProfileUseCase, updateProfile: UpdateCurrentUserProfileUseCase, deleteAccount: DeleteAccountUseCase) {
        self.getProfile = getProfile
        self.updateProfile = updateProfile
        self.deleteAccount = deleteAccount
    }

    var hasChanges: Bool {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines) != originalFullName || dateOfBirth != originalDateOfBirth
    }

    var canSave: Bool {
        hasChanges && !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dateOfBirth != nil
    }

    func loadProfile() async {
        isLoading = true
        applySessionUser(AppSessionStore.shared.currentUser)
        do {
            let user = try await getProfile.execute()
            AppSessionStore.shared.updateCurrentUser(user)
            applySessionUser(user)
        } catch {
            // Session values already shown; only surface the error if we had nothing at all.
            if originalFullName.isEmpty { errorMessage = error.localizedDescription }
        }
        isLoading = false
    }

    func save() async {
        guard canSave, let dateOfBirth else { return }
        isSaving = true
        do {
            let updated = try await updateProfile.execute(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: Self.apiDateFormatter.string(from: dateOfBirth)
            )
            AppSessionStore.shared.updateCurrentUser(updated)
            applySessionUser(updated)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    func deleteAccountAndLogout() async {
        isDeleting = true
        do {
            try await deleteAccount.execute()
            AppLaunchCoordinator.shared.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
        isDeleting = false
    }

    private func applySessionUser(_ user: AuthenticatedUser?) {
        guard let user else { return }
        fullName = user.fullName ?? ""
        dateOfBirth = user.dateOfBirth.flatMap(Self.apiDateFormatter.date(from:))
        originalFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        originalDateOfBirth = dateOfBirth
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct AccountSettingsView: View {
    @Environment(\.getCurrentUserProfileUseCase) private var getCurrentUserProfileUseCase
    @Environment(\.updateCurrentUserProfileUseCase) private var updateCurrentUserProfileUseCase
    @Environment(\.deleteAccountUseCase) private var deleteAccountUseCase
    @State private var vm: AccountSettingsViewModel?
    @State private var showDatePicker = false
    @State private var isDeleteAlertPresented = false

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            if let vm {
                form(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Manage Account")
        .onAppear {
            guard vm == nil else { return }
            let model = AccountSettingsViewModel(
                getProfile: getCurrentUserProfileUseCase,
                updateProfile: updateCurrentUserProfileUseCase,
                deleteAccount: deleteAccountUseCase
            )
            vm = model
            Task { await model.loadProfile() }
        }
    }

    @ViewBuilder
    private func form(vm: AccountSettingsViewModel) -> some View {
        @Bindable var vm = vm
        List {
            Section("Profile") {
                if vm.isLoading {
                    HStack { ProgressView(); Text("Loading profile…").foregroundColor(.brandTextSecondary).padding(.leading, 8) }
                }

                TextField("Full Name", text: $vm.fullName)
                    .textInputAutocapitalization(.words)
                    .foregroundColor(.brandTextPrimary)

                Button { withAnimation { showDatePicker.toggle() } } label: {
                    HStack { Text("Date of Birth").foregroundColor(.brandTextPrimary); Spacer()
                        if let dob = vm.dateOfBirth {
                            Text(dob, style: .date).foregroundColor(.brandTextSecondary)
                        } else {
                            Text("Not set").foregroundColor(.brandTextTertiary)
                        }
                    }
                }

                if showDatePicker {
                    DatePicker(
                        "",
                        selection: Binding(get: { vm.dateOfBirth ?? Date() }, set: { vm.dateOfBirth = $0 }),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical).tint(Color.brandAccent)
                }

                Button {
                    Task { await vm.save() }
                } label: {
                    if vm.isSaving {
                        HStack { ProgressView(); Text("Saving…").padding(.leading, 8) }
                    } else {
                        Text("Save Changes").fontWeight(.semibold)
                    }
                }
                .disabled(!vm.canSave || vm.isSaving)
                .foregroundColor(vm.canSave ? .brandAccent : .brandTextTertiary)
            }

            Section("Account") {
                if vm.isDeleting {
                    HStack { ProgressView(); Text("Deleting account…").foregroundColor(.brandTextSecondary).padding(.leading, 8) }
                } else {
                    Button("Delete Account", role: .destructive) { isDeleteAlertPresented = true }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .alert("Delete Account", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await vm.deleteAccountAndLogout() } }
        } message: {
            Text("This permanently deletes your account and all associated data. This action cannot be undone.")
        }
        .alert("Profile Saved", isPresented: $vm.didSave) {
            Button("OK") {}
        } message: { Text("Your profile has been updated.") }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
    }
}
