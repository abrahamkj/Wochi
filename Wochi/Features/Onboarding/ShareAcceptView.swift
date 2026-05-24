import SwiftUI
import SwiftData

/// Shown as a sheet when the app is opened via a CloudKit CKShare URL
/// (the invited member taps the link in iMessage/Mail while the app is already installed).
struct ShareAcceptView: View {
    let shareURL: URL

    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(.accent)

                VStack(spacing: 8) {
                    Text("household.join.title")
                        .font(.title2.bold())
                    Text("household.join.invite.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if let error = errorMessage {
                    Text(verbatim: error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await accept() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("household.join.confirm")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)
                .padding(.horizontal, 24)

                Button("button.cancel") { dismiss() }
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
            }
        }
    }

    private func accept() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let repo = HouseholdRepository(context: modelContext)
            let (householdID, name, ownerName) = try await HouseholdShareManager.shared.acceptShare(url: shareURL)

            let household: Household
            if let existing = try await repo.fetchHousehold(byID: householdID) {
                household = existing
            } else {
                household = try await repo.createHousehold(name: name, id: householdID)
                if let member = appState.currentMember {
                    household.members = (household.members ?? []) + [member]
                }
            }

            // Pull shopping lists + pantry items from the shared CloudKit zone
            try? await CloudKitZoneSyncService.shared.pullSharedData(
                householdID: householdID,
                ownerName: ownerName,
                context: modelContext
            )

            UserDefaults.standard.set(household.id.uuidString, forKey: Constants.UserDefaults.householdID)
            appState.currentHousehold = household
            appState.incomingShareURL = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
