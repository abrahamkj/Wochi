import SwiftUI
import SwiftData

struct HouseholdManagementView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let household: Household

    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var removeMemberCandidate: HouseholdMember?
    @State private var showLeaveConfirmation = false
    @State private var isGeneratingInvite = false

    var body: some View {
        NavigationStack {
            List {
                Section("household.section.members") {
                    ForEach(household.members) { member in
                        HStack(spacing: 12) {
                            MemberAvatarView(member: member, size: 36)
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(member.displayName)
                                        .font(.body)
                                    if member.isCurrentDevice {
                                        Text("household.member.you")
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(member.role.localizedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .swipeActions(edge: .trailing) {
                            if !member.isCurrentDevice {
                                Button(role: .destructive) {
                                    removeMemberCandidate = member
                                } label: {
                                    Label("household.member.remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }

                    if household.members.count < Constants.Household.maxMembers {
                        Button {
                            Task { await generateInviteLink() }
                        } label: {
                            if isGeneratingInvite {
                                HStack {
                                    ProgressView()
                                    Text("household.invite.generating")
                                }
                            } else {
                                Label("household.invite.cta", systemImage: "person.badge.plus")
                            }
                        }
                        .disabled(isGeneratingInvite)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLeaveConfirmation = true
                    } label: {
                        Label("household.leave", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(household.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .confirmationDialog(
                Text(verbatim: String(
                    format: String(localized: "household.member.remove.confirm"),
                    removeMemberCandidate?.displayName ?? ""
                )),
                isPresented: .constant(removeMemberCandidate != nil),
                titleVisibility: .visible
            ) {
                Button("household.member.remove", role: .destructive) {
                    if let member = removeMemberCandidate {
                        Task {
                            let repo = HouseholdRepository(context: modelContext)
                            try? await repo.removeMember(member, from: household)
                        }
                    }
                    removeMemberCandidate = nil
                }
                Button("button.cancel", role: .cancel) { removeMemberCandidate = nil }
            }
            .confirmationDialog("household.leave.confirm_title", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
                Button("household.leave.confirm", role: .destructive) {
                    Task { await leaveHousehold() }
                }
                Button("button.cancel", role: .cancel) {}
            }
        }
    }

    private func generateInviteLink() async {
        isGeneratingInvite = true
        defer { isGeneratingInvite = false }
        if let url = try? await HouseholdShareManager.shared.createShareURL(for: household) {
            shareURL = url
        } else {
            shareURL = URL(string: "wochi://invite/\(household.id.uuidString)")
        }
        showShareSheet = true
    }

    private func leaveHousehold() async {
        let repo = HouseholdRepository(context: modelContext)
        try? await repo.leaveHousehold(household)
        appState.currentHousehold = nil
        dismiss()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HouseholdManagementView(household: Household.sample())
        .environmentObject(AppState())
}
