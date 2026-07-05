import DesignSystem
import SwiftUI

struct AccountSettingsView: View {
    @State private var fullName = ""
    @State private var dateOfBirth = Date()
    @State private var showDatePicker = false

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
                    Button("Delete Account", role: .destructive) {}
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            .navigationTitle("Manage Account")
        }
    }
}
