import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor
private final class HouseholdSetupViewModel: ObservableObject {
    @Published var householdName: String = ""
    @Published var inviteURL: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    var repository: HouseholdRepositoryProtocol

    init(repository: HouseholdRepositoryProtocol) {
        self.repository = repository
    }

    func createHousehold(appState: AppState) async -> Household? {
        guard !householdName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        isLoading = true
        defer { isLoading = false }
        do {
            let household = try await repository.createHousehold(
                name: householdName.trimmingCharacters(in: .whitespaces)
            )
            if let member = appState.currentMember {
                household.members.append(member)
                member.household = household
            }
            UserDefaults.standard.set(household.id.uuidString, forKey: Constants.UserDefaults.householdID)
            appState.currentHousehold = household
            return household
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    func joinHousehold(via urlString: String, appState: AppState) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed) else {
            errorMessage = WochiError.invalidInviteLink.localizedDescription
            showError = true
            return
        }

        // Parse household UUID from wochi://invite/<uuid> or wochi://invite?household=<uuid>
        let uuidString: String?
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let item = items.first(where: { $0.name == "household" }) {
            uuidString = item.value
        } else {
            let last = url.lastPathComponent
            uuidString = last.isEmpty ? nil : last
        }

        guard let idString = uuidString, let householdID = UUID(uuidString: idString) else {
            errorMessage = WochiError.invalidInviteLink.localizedDescription
            showError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if let household = try await repository.fetchHousehold(byID: householdID) {
                UserDefaults.standard.set(household.id.uuidString, forKey: Constants.UserDefaults.householdID)
                appState.currentHousehold = household
            } else {
                errorMessage = WochiError.householdNotFound.localizedDescription
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - HouseholdSetupView

struct HouseholdSetupView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = HouseholdSetupViewModel(
        repository: _PlaceholderHouseholdRepository()
    )

    @State private var path: SetupPath = .choice

    private enum SetupPath {
        case choice, create, join
    }

    var body: some View {
        NavigationStack {
            Group {
                switch path {
                case .choice:
                    choiceView
                case .create:
                    createView
                case .join:
                    joinView
                }
            }
            .navigationTitle(
                path == .create
                    ? LocalizedStringKey("household.create.title")
                    : path == .join
                        ? LocalizedStringKey("household.join.title")
                        : LocalizedStringKey("household.create.title")
            )
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            viewModel.repository = HouseholdRepository(context: modelContext)
        }
        .alert(
            Text(verbatim: viewModel.errorMessage ?? ""),
            isPresented: $viewModel.showError
        ) {
            Button("button.confirm", role: .cancel) { }
        }
        .onChange(of: appState.currentHousehold) { _, household in
            if household != nil {
                showOnboarding = false
            }
        }
    }

    // MARK: Choice screen

    private var choiceView: some View {
        VStack(spacing: 24) {
            Spacer()

            actionCard(
                icon: "plus.circle.fill",
                titleKey: "household.create.title",
                color: .accentColor
            ) {
                withAnimation { path = .create }
            }

            actionCard(
                icon: "person.badge.plus",
                titleKey: "household.join.title",
                color: .orange
            ) {
                withAnimation { path = .join }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func actionCard(
        icon: String,
        titleKey: LocalizedStringKey,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(color)

                Text(titleKey)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: Create screen

    private var createView: some View {
        VStack(spacing: 32) {
            Spacer()

            TextField("household.name.placeholder", text: $viewModel.householdName)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal, 24)
                .autocorrectionDisabled(false)
                .textInputAutocapitalization(.words)

            Button {
                Task {
                    let household = await viewModel.createHousehold(appState: appState)
                    if household != nil { showOnboarding = false }
                }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("button.confirm")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    viewModel.householdName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray
                        : Color.accentColor
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(
                viewModel.householdName.trimmingCharacters(in: .whitespaces).isEmpty
                    || viewModel.isLoading
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    withAnimation { path = .choice }
                }
            }
        }
    }

    // MARK: Join screen

    private var joinView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("household.join.title")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("wochi://invite/...", text: $viewModel.inviteURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            .padding(.horizontal, 24)

            Button {
                Task {
                    await viewModel.joinHousehold(via: viewModel.inviteURL, appState: appState)
                }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("button.confirm")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    viewModel.inviteURL.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.gray
                        : Color.orange
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(
                viewModel.inviteURL.trimmingCharacters(in: .whitespaces).isEmpty
                    || viewModel.isLoading
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel") {
                    withAnimation { path = .choice }
                }
            }
        }
    }
}

// MARK: - Placeholder repository (used until model context is injected via .task)

private final class _PlaceholderHouseholdRepository: HouseholdRepositoryProtocol {
    func fetchCurrentHousehold() async throws -> Household? { nil }
    func fetchHousehold(byID id: UUID) async throws -> Household? { nil }
    func createHousehold(name: String) async throws -> Household { Household(name: name) }
    func inviteMember(to household: Household) async throws -> URL {
        guard let url = URL(string: "wochi://invite/\(household.id.uuidString)") else {
            throw WochiError.invalidInviteLink
        }
        return url
    }
    func removeMember(_ member: HouseholdMember, from household: Household) async throws {}
    func updateMemberRole(_ member: HouseholdMember, role: MemberRole) async throws {}
    func leaveHousehold(_ household: Household) async throws {}
}

// MARK: - Preview

#Preview {
    HouseholdSetupView(showOnboarding: .constant(true))
        .environmentObject(AppState())
        .modelContainer(WochiDataContainer.preview)
}
