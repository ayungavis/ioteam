import DesignSystem
import SwiftUI

struct ManageFamilyView: View {
    @State private var inviteCode = "A3X9K2"
    @State private var familyName = "My Family"
    @State private var members: [(name: String, role: String)] = [
        ("You", "Owner"),
        ("Mom", "Member")
    ]

    var body: some View {
        ZStack { Color.brandSurface.ignoresSafeArea()
            List {
                Section("Family Info") {
                    LabeledContent("Name", value: familyName)
                    LabeledContent("Members", value: "\(members.count)")
                }

                Section("Invite Code") {
                    HStack {
                        Text(inviteCode).font(.system(size: 20, weight: .bold)).monospaced().foregroundColor(.brandAccent)
                        Spacer()
                        Button("Copy") { UIPasteboard.general.string = inviteCode }
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.brandAccent)
                    }
                }

                Section("Members") {
                    ForEach(members, id: \.name) { member in
                        HStack {
                            Text(member.name).foregroundColor(.brandTextPrimary)
                            Spacer()
                            Text(member.role)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.brandAccent.opacity(0.12))
                                .foregroundColor(.brandAccent)
                                .clipShape(Capsule())
                        }
                    }
                }

                Section {
                    Button("Leave Family", role: .destructive) {}
                }
            }
            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            .navigationTitle("Manage Family")
        }
    }
}
