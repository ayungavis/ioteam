import DesignSystem
import Domain
import SwiftUI

struct ProfileOnboardingView: View {
    @State private var viewModel: ProfileOnboardingViewModel

    init(viewModel: ProfileOnboardingViewModel) {
        _viewModel = State(initialValue: viewModel)
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
                        ProfileFormFields(viewModel: viewModel)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                Spacer()

                PrimaryButton(
                    "Continue",
                    isValid: viewModel.isFormValid,
                    isLoading: viewModel.isSavingProfile,
                    icon: .arrow
                ) {
                    Task { await viewModel.submitProfile() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .task {
            await viewModel.loadProfileIfNeeded()
        }
    }
}

private struct ProfileFormFields: View {
    @Bindable var viewModel: ProfileOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProfileTextField(
                title: "Full Name",
                placeholder: "Enter Name",
                text: $viewModel.fullName
            )
            .textInputAutocapitalization(.words)

            ProfileDateField(viewModel: viewModel)

            ReadOnlyField(title: "Email", value: viewModel.email)
        }
        .overlay {
            if viewModel.isLoadingProfile {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct ProfileDateField: View {
    @Bindable var viewModel: ProfileOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date of Birth")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    viewModel.showDatePicker.toggle()
                }
            } label: {
                HStack {
                    Text(viewModel.displayedDateText())
                        .foregroundStyle(viewModel.dateOfBirth == nil ? Color.brandTextTertiary : Color.brandTextPrimary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brandTextPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandCard)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if viewModel.showDatePicker {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.dateOfBirth ?? Date() },
                        set: { viewModel.dateOfBirth = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color.brandAccent)
                .padding(12)
                .background(Color.brandCard)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct ProfileTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)

            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .foregroundStyle(Color.brandTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandCard)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandBorder, lineWidth: 1)
                }
        }
    }
}

private struct ReadOnlyField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.brandTextPrimary)

            Text(value)
                .font(.system(size: 16))
                .foregroundStyle(Color.brandTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.brandDisabledFill)
                .clipShape(.rect(cornerRadius: 12))
        }
    }
}

#Preview {
    ProfileOnboardingView(
        viewModel: ProfileOnboardingViewModel(
            getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase(client: MockAPIClient()),
            updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase(client: MockAPIClient())
        )
    )
}
