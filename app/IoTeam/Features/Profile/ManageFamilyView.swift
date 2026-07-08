import DesignSystem
import Domain
import SwiftUI

struct ManageFamilyView: View {
    @Environment(\.getCurrentFamilyUseCase) private var getCurrentFamily
    @Environment(\.createFamilyUseCase) private var createFamily
    @Environment(\.joinFamilyUseCase) private var joinFamily
    @Environment(\.refreshInviteCodeUseCase) private var refreshCode
    @Environment(\.removeMemberUseCase) private var removeMember
    @Environment(\.renameFamilyUseCase) private var renameFamily
    @Environment(\.getFamilyMembersUseCase) private var getFamilyMembers
    @State private var vm = ManageFamilyViewModel(useCases: FamilyUseCases(
        getCurrentFamily: GetCurrentFamilyUseCase(client: FamilyPreviewAPI()),
        createFamily: CreateFamilyUseCase(client: FamilyPreviewAPI()),
        joinFamily: JoinFamilyUseCase(client: FamilyPreviewAPI()),
        refreshInviteCode: RefreshInviteCodeUseCase(client: FamilyPreviewAPI()),
        removeMember: RemoveMemberUseCase(client: FamilyPreviewAPI()),
        renameFamily: RenameFamilyUseCase(client: FamilyPreviewAPI()),
        getMembers: GetFamilyMembersUseCase(client: FamilyPreviewAPI())
    ))
    @State private var isRenamePresented = false
    @State private var renameText = ""

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, alignment: .center)
            } else if vm.hasFamily {
                familyDetailView
            } else {
                createJoinView
            }
        }
        .navigationTitle("Manage Family")
        .onAppear {
            vm = ManageFamilyViewModel(useCases: FamilyUseCases(
                getCurrentFamily: getCurrentFamily,
                createFamily: createFamily,
                joinFamily: joinFamily,
                refreshInviteCode: refreshCode,
                removeMember: removeMember,
                renameFamily: renameFamily,
                getMembers: getFamilyMembers
            ))
            Task { await vm.loadFamily() }
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
        .alert("Rename Family", isPresented: $isRenamePresented) {
            TextField("Family name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { Task { await vm.renameFamily(to: renameText) } }
        } message: { Text("Only owners and admins can rename the family.") }
    }

    // MARK: - Has Family

    private var familyDetailView: some View {
        List {
            if let family = vm.family {
                Section("Family Info") {
                    HStack {
                        Text("Name").foregroundColor(.brandTextPrimary)
                        Spacer()
                        Text(family.name).foregroundColor(.brandTextSecondary)
                        if vm.canManageFamily {
                            if vm.isRenaming {
                                ProgressView().padding(.leading, 4)
                            } else {
                                Button {
                                    renameText = family.name
                                    isRenamePresented = true
                                } label: {
                                    Image(systemName: "pencil").foregroundColor(.brandAccent).font(.system(size: 14))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    LabeledContent("Members", value: "\(vm.members.count)")
                    LabeledContent("Your Role", value: family.role.capitalized)
                }

                Section("Invite Code") {
                    HStack {
                        Text(vm.inviteCode).font(.system(size: 20, weight: .bold)).monospaced()
                            .foregroundColor(.brandAccent)
                        Spacer()
                        Button("Copy") { UIPasteboard.general.string = vm.inviteCode }
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.brandAccent)
                        if vm.isRefreshing { ProgressView().padding(.leading, 8) }
                        Button("Refresh") { Task { await vm.refreshCode() } }
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.brandTextSecondary)
                    }
                }

                Section("Members") {
                    ForEach(vm.members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.user.fullName ?? "Unknown")
                                    .font(.system(size: 15, weight: .medium)).foregroundColor(.brandTextPrimary)
                                Text(member.user.email ?? "").font(.system(size: 12)).foregroundColor(.brandTextSecondary)
                            }
                            Spacer()
                            Text(member.role.capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.brandAccent.opacity(0.12)).foregroundColor(.brandAccent)
                                .clipShape(Capsule())
                            if family.role == "owner" || family.role == "admin" {
                                Button { Task { await vm.removeMember(memberId: member.id) } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.red).font(.system(size: 16))
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Leave Family", role: .destructive) { Task { await vm.leaveFamily() } }
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .refreshable { await vm.loadFamily() }
    }

    // MARK: - No Family

    private var createJoinView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Family Setup").font(.system(size: 28, weight: .bold)).foregroundColor(.brandTextPrimary)
                    .padding(.horizontal, 24).padding(.top, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Family").font(.system(size: 20, weight: .bold)).foregroundColor(.brandTextPrimary)
                    TextField("Family Name", text: $vm.familyName)
                        .font(.system(size: 16)).foregroundColor(.brandTextPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.brandCard).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                    PrimaryButton("Continue", isValid: vm.isCreateFamilyValid, isLoading: vm.isCreating, icon: .arrow) {
                        Task { await vm.createFamily() }
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 16) {
                    Rectangle().fill(Color.brandBorder).frame(height: 1)
                    Text("or").font(.system(size: 14)).foregroundColor(.brandTextTertiary)
                    Rectangle().fill(Color.brandBorder).frame(height: 1)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Join Family").font(.system(size: 20, weight: .bold)).foregroundColor(.brandTextPrimary)
                    TextField("Family Code", text: $vm.familyCode)
                        .font(.system(size: 16)).foregroundColor(.brandTextPrimary)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.brandCard).cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandBorder, lineWidth: 1))
                    PrimaryButton("Continue", isValid: vm.isJoinFamilyValid, isLoading: vm.isJoining, icon: .arrow) {
                        Task { await vm.joinFamily() }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

private final class FamilyPreviewAPI: APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T { throw NetworkError.invalidURL }
}
