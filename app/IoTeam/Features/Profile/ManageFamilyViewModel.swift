import Domain
import SwiftUI

@Observable
@MainActor
final class ManageFamilyViewModel {
    var familyName = ""
    var familyCode = ""
    var errorMessage: String?
    var isLoading = false
    var isCreating = false
    var isJoining = false

    // Has-family state
    var family: FamilyDetail?
    var inviteCode = ""
    var isRefreshing = false

    private let getCurrentFamilyUseCase: GetCurrentFamilyUseCase
    private let createFamilyUseCase: CreateFamilyUseCase
    private let joinFamilyUseCase: JoinFamilyUseCase
    private let registerDeviceUseCase: RegisterDeviceUseCase
    private let refreshInviteCodeUseCase: RefreshInviteCodeUseCase
    private let removeMemberUseCase: RemoveMemberUseCase

    init(getCurrentFamilyUseCase: GetCurrentFamilyUseCase, createFamilyUseCase: CreateFamilyUseCase, joinFamilyUseCase: JoinFamilyUseCase, registerDeviceUseCase: RegisterDeviceUseCase, refreshInviteCodeUseCase: RefreshInviteCodeUseCase, removeMemberUseCase: RemoveMemberUseCase) {
        self.getCurrentFamilyUseCase = getCurrentFamilyUseCase
        self.createFamilyUseCase = createFamilyUseCase
        self.joinFamilyUseCase = joinFamilyUseCase
        self.registerDeviceUseCase = registerDeviceUseCase
        self.refreshInviteCodeUseCase = refreshInviteCodeUseCase
        self.removeMemberUseCase = removeMemberUseCase
    }

    var hasFamily: Bool { family != nil }

    var isCreateFamilyValid: Bool { !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isJoinFamilyValid: Bool { !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func loadFamily() async {
        isLoading = true
        errorMessage = nil
        do {
            family = try await getCurrentFamilyUseCase.execute()
            inviteCode = family?.inviteCode ?? ""
        } catch {
            family = nil
        }
        isLoading = false
    }

    func createFamily() async {
        guard isCreateFamilyValid else { return }
        isCreating = true; errorMessage = nil
        do {
            let summary = try await createFamilyUseCase.execute(name: familyName.trimmingCharacters(in: .whitespacesAndNewlines))
            try await finishSetup(familyId: summary.id)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
        isCreating = false
    }

    func joinFamily() async {
        guard isJoinFamilyValid else { return }
        isJoining = true; errorMessage = nil
        do {
            let summary = try await joinFamilyUseCase.execute(inviteCode: familyCode.trimmingCharacters(in: .whitespacesAndNewlines))
            try await finishSetup(familyId: summary.id)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
        isJoining = false
    }

    func refreshCode() async {
        guard let familyId = family?.id else { return }
        isRefreshing = true
        do {
            let newCode = try await refreshInviteCodeUseCase.execute(familyId: familyId)
            inviteCode = newCode
        } catch { errorMessage = error.localizedDescription }
        isRefreshing = false
    }

    func removeMember(memberId: String) async {
        guard let familyId = family?.id else { return }
        do {
            try await removeMemberUseCase.execute(familyId: familyId, memberId: memberId)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
    }

    func leaveFamily() async {
        guard let familyId = family?.id,
              let email = AppSessionStore.shared.currentUser?.email,
              let myId = family?.members.first(where: { $0.user.email == email })?.id else {
            errorMessage = "Could not find your membership."
            return
        }
        do {
            try await removeMemberUseCase.execute(familyId: familyId, memberId: myId)
            family = nil
            AppSessionStore.shared.clearFamilyAndDevice()
        } catch { errorMessage = error.localizedDescription }
    }

    private func finishSetup(familyId: String) async throws {
        let device = try await registerDeviceUseCase.execute(deviceName: "Default Pill Box")
        AppSessionStore.shared.saveFamilyAndDevice(familyId: familyId, deviceId: device.id, deviceName: device.name)
    }
}
