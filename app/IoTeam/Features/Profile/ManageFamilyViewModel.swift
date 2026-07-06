import Domain
import SwiftUI

/// All backend use cases the family management screen needs, grouped so they can be injected as one unit.
struct FamilyUseCases {
    let getCurrentFamily: GetCurrentFamilyUseCase
    let createFamily: CreateFamilyUseCase
    let joinFamily: JoinFamilyUseCase
    let registerDevice: RegisterDeviceUseCase
    let refreshInviteCode: RefreshInviteCodeUseCase
    let removeMember: RemoveMemberUseCase
    let renameFamily: RenameFamilyUseCase
    let getMembers: GetFamilyMembersUseCase
}

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
    var members: [FamilyMember] = []
    var inviteCode = ""
    var isRefreshing = false
    var isRenaming = false

    private let useCases: FamilyUseCases

    init(useCases: FamilyUseCases) {
        self.useCases = useCases
    }

    var hasFamily: Bool { family != nil }

    var isCreateFamilyValid: Bool { !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isJoinFamilyValid: Bool { !familyCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canManageFamily: Bool { family?.role == "owner" || family?.role == "admin" }

    func loadFamily() async {
        isLoading = true
        errorMessage = nil
        do {
            family = try await useCases.getCurrentFamily.execute()
            inviteCode = family?.inviteCode ?? ""
            members = family?.members ?? []
        } catch {
            family = nil
            members = []
        }
        isLoading = false
        await refreshMembers()
    }

    /// Refreshes the member list from the dedicated members endpoint.
    func refreshMembers() async {
        guard let familyId = family?.id else { return }
        do {
            members = try await useCases.getMembers.execute(familyId: familyId)
        } catch {
            // Keep the members that came with the family detail.
        }
    }

    func createFamily() async {
        guard isCreateFamilyValid else { return }
        isCreating = true; errorMessage = nil
        do {
            let summary = try await useCases.createFamily.execute(name: familyName.trimmingCharacters(in: .whitespacesAndNewlines))
            try await finishSetup(familyId: summary.id)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
        isCreating = false
    }

    func joinFamily() async {
        guard isJoinFamilyValid else { return }
        isJoining = true; errorMessage = nil
        do {
            let summary = try await useCases.joinFamily.execute(inviteCode: familyCode.trimmingCharacters(in: .whitespacesAndNewlines))
            try await finishSetup(familyId: summary.id)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
        isJoining = false
    }

    func refreshCode() async {
        guard let familyId = family?.id else { return }
        isRefreshing = true
        do {
            let newCode = try await useCases.refreshInviteCode.execute(familyId: familyId)
            inviteCode = newCode
        } catch { errorMessage = error.localizedDescription }
        isRefreshing = false
    }

    func renameFamily(to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let familyId = family?.id, !trimmed.isEmpty, trimmed != family?.name else { return }
        isRenaming = true
        do {
            _ = try await useCases.renameFamily.execute(familyId: familyId, name: trimmed)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
        isRenaming = false
    }

    func removeMember(memberId: String) async {
        guard let familyId = family?.id else { return }
        do {
            try await useCases.removeMember.execute(familyId: familyId, memberId: memberId)
            await loadFamily()
        } catch { errorMessage = error.localizedDescription }
    }

    func leaveFamily() async {
        guard let familyId = family?.id,
              let email = AppSessionStore.shared.currentUser?.email,
              let myId = members.first(where: { $0.user.email == email })?.id else {
            errorMessage = "Could not find your membership."
            return
        }
        do {
            try await useCases.removeMember.execute(familyId: familyId, memberId: myId)
            family = nil
            members = []
            AppSessionStore.shared.clearFamilyAndDevice()
        } catch { errorMessage = error.localizedDescription }
    }

    private func finishSetup(familyId: String) async throws {
        let device = try await useCases.registerDevice.execute(deviceName: "Default Pill Box")
        AppSessionStore.shared.saveFamilyAndDevice(familyId: familyId, deviceId: device.id, deviceName: device.name)
    }
}
