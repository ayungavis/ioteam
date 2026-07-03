import Domain
import Foundation
import SwiftUI

@Observable
@MainActor
final class ProfileOnboardingViewModel {
    var fullName = ""
    var dateOfBirth: Date?
    var showDatePicker = false
    var email = ""
    var errorMessage: String?
    var isLoadingProfile = false
    var isSavingProfile = false

    @ObservationIgnored
    private var hasLoadedProfile = false

    private let getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase
    private let updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase

    init(
        getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase,
        updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase
    ) {
        self.getCurrentUserProfileUseCase = getCurrentUserProfileUseCase
        self.updateCurrentUserProfileUseCase = updateCurrentUserProfileUseCase
    }

    var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            dateOfBirth != nil
    }

    func loadProfileIfNeeded() async {
        guard !hasLoadedProfile else {
            return
        }
        hasLoadedProfile = true
        isLoadingProfile = true
        errorMessage = nil
        applySessionFallback()

        do {
            let user = try await getCurrentUserProfileUseCase.execute()
            AppSessionStore.shared.updateCurrentUser(user)

            if user.onboardingCompleted {
                isLoadingProfile = false
                AppLaunchCoordinator.shared.syncCompletedOnboardingFromBackend()
                return
            }

            apply(user: user)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingProfile = false
    }

    func submitProfile() async {
        guard isFormValid, let dateOfBirth else {
            return
        }

        isSavingProfile = true
        errorMessage = nil

        do {
            let updatedUser = try await updateCurrentUserProfileUseCase.execute(
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: Self.apiDateFormatter.string(from: dateOfBirth)
            )
            AppSessionStore.shared.updateCurrentUser(updatedUser)

            if updatedUser.onboardingCompleted {
                AppLaunchCoordinator.shared.syncCompletedOnboardingFromBackend()
            } else {
                AppLaunchCoordinator.shared.completeProfileOnboarding()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingProfile = false
    }

    func displayedDateText() -> String {
        guard let dateOfBirth else {
            return "Date of Birth"
        }
        return Self.displayDateFormatter.string(from: dateOfBirth)
    }

    private func applySessionFallback() {
        guard let sessionUser = AppSessionStore.shared.currentUser else {
            return
        }

        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullName = sessionUser.fullName ?? ""
        }
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            email = sessionUser.email
        }
        if dateOfBirth == nil {
            dateOfBirth = sessionUser.dateOfBirth.flatMap(Self.apiDateFormatter.date(from:))
        }
    }

    private func apply(user: AuthenticatedUser) {
        if let fullName = user.fullName, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.fullName = fullName
        }
        email = user.email
        dateOfBirth = user.dateOfBirth.flatMap(Self.apiDateFormatter.date(from:))
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
