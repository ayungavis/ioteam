import DesignSystem
import Domain
import SwiftUI

struct ManageFamilyView: View {
    @Environment(\.getCurrentFamilyUseCase) private var getCurrentFamily
    @Environment(\.createFamilyUseCase) private var createFamily
    @Environment(\.joinFamilyUseCase) private var joinFamily
    @Environment(\.registerDeviceUseCase) private var registerDevice
    @Environment(\.refreshInviteCodeUseCase) private var refreshCode
    @Environment(\.removeMemberUseCase) private var removeMember
    @State private var vm = ManageFamilyViewModel(
        getCurrentFamilyUseCase: GetCurrentFamilyUseCase(client: FamilyPreviewAPI()),
        createFamilyUseCase: CreateFamilyUseCase(client: FamilyPreviewAPI()),
        joinFamilyUseCase: JoinFamilyUseCase(client: FamilyPreviewAPI()),
        registerDeviceUseCase: RegisterDeviceUseCase(client: FamilyPreviewAPI()),
        refreshInviteCodeUseCase: RefreshInviteCodeUseCase(client: FamilyPreviewAPI()),
        removeMemberUseCase: RemoveMemberUseCase(client: FamilyPreviewAPI())
    )

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
            vm = ManageFamilyViewModel(
                getCurrentFamilyUseCase: getCurrentFamily, createFamilyUseCase: createFamily,
                joinFamilyUseCase: joinFamily, registerDeviceUseCase: registerDevice,
                refreshInviteCodeUseCase: refreshCode, removeMemberUseCase: removeMember
            )
            Task { await vm.loadFamily() }
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK") {}
        } message: { Text(vm.errorMessage ?? "") }
    }

    // MARK: - Has Family

    private var familyDetailView: some View {
        List {
            if let family = vm.family {
                Section("Family Info") {
                    LabeledContent("Name", value: family.name)
                    LabeledContent("Members", value: "\(family.memberCount)")
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
                    ForEach(family.members) { member in
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
