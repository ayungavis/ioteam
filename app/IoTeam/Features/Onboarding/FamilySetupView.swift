import DesignSystem
import SwiftUI

struct FamilySetupView: View {
    @State private var familyName: String = ""
    @State private var familyCode: String = ""

    var isCreateFamilyValid: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isJoinFamilyValid: Bool {
        !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.brandSurface
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("Family Setup")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.brandTextPrimary)
                        .padding(.top, 16)

                    Image("family-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .padding(.top, 24)
                        .padding(.bottom, 32)

                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Create Family Section
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Create Family")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.brandTextPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Family Name")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.brandTextPrimary)

                                TextField("Enter Name", text: $familyName)
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

                            PrimaryButton("Continue", isValid: isCreateFamilyValid, icon: .arrow) {
                                AppLaunchCoordinator.shared.completeFamilySetup()
                            }
                        }

                        // MARK: - Divider
                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(Color.brandBorder)
                                .frame(height: 1)

                            Text("or")
                                .font(.system(size: 14))
                                .foregroundColor(Color.brandTextTertiary)

                            Rectangle()
                                .fill(Color.brandBorder)
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)

                        // MARK: - Join Family Section
                        VStack(alignment: .leading, spacing: 24) {
                            Text("Join Family")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.brandTextPrimary)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Family Code")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.brandTextPrimary)

                                TextField("Enter Code", text: $familyCode)
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

                            PrimaryButton("Continue", isValid: isJoinFamilyValid, icon: .arrow) {
                                AppLaunchCoordinator.shared.completeFamilySetup()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

#Preview {
    FamilySetupView()
}
