import Domain
import SwiftUI

@Observable
@MainActor
final class FamilySetupViewModel {
    var familyName = ""
    var familyCode = ""
    var errorMessage: String?
    var isCreatingFamily = false
    var isJoiningFamily = false

    private let createFamilyUseCase: CreateFamilyUseCase
    private let joinFamilyUseCase: JoinFamilyUseCase
    private let completeOnboardingUseCase: CompleteOnboardingUseCase

    init(
        createFamilyUseCase: CreateFamilyUseCase,
        joinFamilyUseCase: JoinFamilyUseCase,
        completeOnboardingUseCase: CompleteOnboardingUseCase
    ) {
        self.createFamilyUseCase = createFamilyUseCase
        self.joinFamilyUseCase = joinFamilyUseCase
        self.completeOnboardingUseCase = completeOnboardingUseCase
    }

    var isCreateFamilyValid: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isJoinFamilyValid: Bool {
        !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createFamily() async {
        guard isCreateFamilyValid else {
            return
        }

        isCreatingFamily = true
        errorMessage = nil

        do {
            _ = try await createFamilyUseCase.execute(
                name: familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try await finishOnboarding()
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreatingFamily = false
    }

    func joinFamily() async {
        guard isJoinFamilyValid else {
            return
        }

        isJoiningFamily = true
        errorMessage = nil

        do {
            _ = try await joinFamilyUseCase.execute(
                inviteCode: familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try await finishOnboarding()
        } catch {
            errorMessage = error.localizedDescription
        }

        isJoiningFamily = false
    }

    private func finishOnboarding() async throws {
        let result = try await completeOnboardingUseCase.execute()
        guard result.onboardingCompleted else {
            throw NetworkError.badResponse(statusCode: 200, message: "Could not complete onboarding.")
        }
        AppLaunchCoordinator.shared.syncCompletedOnboardingFromBackend()
    }
}
