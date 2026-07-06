import DesignSystem
import Domain
import SwiftUI

struct AccountSettingsView: View {
    @Environment(\.deleteAccountUseCase) private var deleteAccountUseCase
    @State private var fullName = ""
    @State private var dateOfBirth = Date()
    @State private var showDatePicker = false
    @State private var isDeleteAlertPresented = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            List {
                Section("Profile") {
                    HStack { Text("Avatar").foregroundColor(.brandTextPrimary); Spacer(); Text("Tap to change").foregroundColor(.brandTextSecondary) }
                        .contentShape(Rectangle()).onTapGesture {}

                    TextField("Full Name", text: $fullName)
                        .foregroundColor(.brandTextPrimary)

                    Button { withAnimation { showDatePicker.toggle() } } label: {
                        HStack { Text("Date of Birth").foregroundColor(.brandTextPrimary); Spacer()
                            Text(dateOfBirth, style: .date).foregroundColor(.brandTextSecondary) }
                    }

                    if showDatePicker {
                        DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical).tint(Color.brandAccent)
                    }
                }

                Section("Account") {
                    if isDeleting {
                        HStack { ProgressView(); Text("Deleting account…").foregroundColor(.brandTextSecondary).padding(.leading, 8) }
                    } else {
                        Button("Delete Account", role: .destructive) { isDeleteAlertPresented = true }
                    }
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            .navigationTitle("Manage Account")
        }
        .alert("Delete Account", isPresented: $isDeleteAlertPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await deleteAccountUseCase.execute()
                        AppLaunchCoordinator.shared.logout()
                    } catch {
                        deleteErrorMessage = error.localizedDescription
                    }
                    isDeleting = false
                }
            }
        } message: {
            Text("This permanently deletes your account and all associated data. This action cannot be undone.")
        }
        .alert("Error", isPresented: Binding(get: { deleteErrorMessage != nil }, set: { _ in deleteErrorMessage = nil })) {
            Button("OK") {}
        } message: { Text(deleteErrorMessage ?? "") }
    }
}
