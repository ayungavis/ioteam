import DesignSystem
import SwiftUI

struct ProfileOnboardingView: View {
    @State private var fullName: String = ""
    @State private var dateOfBirth: Date? = nil
    @State private var showDatePicker = false
    @State private var email: String = "kevran.w@icloud.com"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && dateOfBirth != nil
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Complete Your Profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.brandTextPrimary)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                    .padding(.horizontal, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.brandTextPrimary)

                            TextField("Enter Name", text: $fullName)
                                .font(.system(size: 16))
                                .foregroundColor(.brandTextPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.brandCard)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                        }

                        // Date of Birth Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.brandTextPrimary)

                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showDatePicker.toggle()
                                }
                            }) {
                                HStack {
                                    if let dob = dateOfBirth {
                                        Text(dob, formatter: dateFormatter)
                                            .foregroundColor(.brandTextPrimary)
                                    } else {
                                        Text("Date of Birth")
                                            .foregroundColor(Color.brandTextTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar")
                                        .font(.system(size: 18))
                                        .foregroundColor(.brandTextPrimary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.brandCard)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                            }

                            if showDatePicker {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { dateOfBirth ?? Date() },
                                        set: {
                                            dateOfBirth = $0
                                        }
                                    ),
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .tint(Color.brandAccent)
                                .padding(12)
                                .background(Color.brandCard)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.brandBorder, lineWidth: 1)
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // Email Field (Read-only / Disabled)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.brandTextPrimary)

                            Text(email)
                                .font(.system(size: 16))
                                .foregroundColor(Color.brandTextTertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.brandDisabledFill)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                PrimaryButton("Continue", isValid: isFormValid, icon: .arrow) {
                    AppLaunchCoordinator.shared.completeProfileOnboarding()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    ProfileOnboardingView()
}
