import SwiftUI

struct HouseholdManagementView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let household: Household

    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var removeMemberCandidate: HouseholdMember?
    @State private var showLeaveConfirmation = false
    @State private var isGeneratingInvite = false

    var canManage: Bool {
        appState.currentMember?.role == .owner || appState.currentMember?.role == .admin
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Mitglieder") {
                    ForEach(household.members) { member in
                        HStack(spacing: 12) {
                            MemberAvatarView(member: member, size: 36)
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(member.displayName)
                                        .font(.body)
                                    if member.isCurrentDevice {
                                        Text("Du")
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
                            swipeActions(for: member)
                        }
                    }

                    if canManage && household.members.count < Constants.Household.maxMembers {
                        Button {
                            Task { await generateInviteLink() }
                        } label: {
                            if isGeneratingInvite {
                                HStack {
                                    ProgressView()
                                    Text("Einladungslink wird erstellt...")
                                }
                            } else {
                                Label("Mitglied einladen", systemImage: "person.badge.plus")
                            }
                        }
                        .disabled(isGeneratingInvite)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLeaveConfirmation = true
                    } label: {
                        Label("Haushalt verlassen", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle(household.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
            .confirmationDialog(
                "Möchtest du \(removeMemberCandidate?.displayName ?? "") wirklich entfernen?",
                isPresented: .constant(removeMemberCandidate != nil),
                titleVisibility: .visible
            ) {
                Button("Entfernen", role: .destructive) {
                    removeMemberCandidate = nil
                }
                Button("Abbrechen", role: .cancel) { removeMemberCandidate = nil }
            }
            .confirmationDialog("Haushalt verlassen?", isPresented: $showLeaveConfirmation, titleVisibility: .visible) {
                Button("Verlassen", role: .destructive) { dismiss() }
                Button("Abbrechen", role: .cancel) {}
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

    @ViewBuilder
    private func swipeActions(for member: HouseholdMember) -> some View {
        if canManage && !member.isCurrentDevice {
            Button(role: .destructive) {
                removeMemberCandidate = member
            } label: {
                Label("Entfernen", systemImage: "person.badge.minus")
            }
        } else {
            EmptyView()
        }
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
