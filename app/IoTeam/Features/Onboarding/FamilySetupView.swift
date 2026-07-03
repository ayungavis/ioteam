import DesignSystem
import Domain
import SwiftUI

struct FamilySetupView: View {
    @State private var viewModel: FamilySetupViewModel

    init(viewModel: FamilySetupViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("Family Setup")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.brandTextPrimary)
                        .padding(.top, 16)

                    Image("family-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .padding(.top, 24)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 24) {
                        CreateFamilySection(viewModel: viewModel)

                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(Color.brandBorder)
                                .frame(height: 1)

                            Text("or")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.brandTextTertiary)

                            Rectangle()
                                .fill(Color.brandBorder)
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)

                        JoinFamilySection(viewModel: viewModel)

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

private struct CreateFamilySection: View {
    @Bindable var viewModel: FamilySetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Create Family")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.brandTextPrimary)

            ProfileTextField(
                title: "Family Name",
                placeholder: "Enter Name",
                text: $viewModel.familyName
            )
            .textInputAutocapitalization(.words)

            PrimaryButton(
                "Continue",
                isValid: viewModel.isCreateFamilyValid,
                isLoading: viewModel.isCreatingFamily,
                icon: .arrow
            ) {
                Task { await viewModel.createFamily() }
            }
        }
    }
}

private struct JoinFamilySection: View {
    @Bindable var viewModel: FamilySetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Join Family")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.brandTextPrimary)

            ProfileTextField(
                title: "Family Code",
                placeholder: "Enter Code",
                text: $viewModel.familyCode
            )
            .textInputAutocapitalization(.characters)

            PrimaryButton(
                "Continue",
                isValid: viewModel.isJoinFamilyValid,
                isLoading: viewModel.isJoiningFamily,
                icon: .arrow
            ) {
                Task { await viewModel.joinFamily() }
            }
        }
    }
}

#Preview {
    FamilySetupView(
        viewModel: FamilySetupViewModel(
            createFamilyUseCase: CreateFamilyUseCase(client: MockAPIClient()),
            joinFamilyUseCase: JoinFamilyUseCase(client: MockAPIClient()),
            completeOnboardingUseCase: CompleteOnboardingUseCase(client: MockAPIClient())
        )
    )
}
