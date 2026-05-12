import SwiftUI
import SwiftData

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    @Published var currentHousehold: Household?
    @Published var currentMember: HouseholdMember?
    @Published var isOffline: Bool = false
}

// MARK: - App Entry Point

@main
struct WochiApp: App {
    @StateObject private var appState = AppState()

    private let modelContainer: ModelContainer = {
        do {
            return try WochiDataContainer.create()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(
        forKey: Constants.UserDefaults.onboardingCompleted
    )

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView(showOnboarding: $showOnboarding)
                } else {
                    ContentView()
                }
            }
            .environmentObject(appState)
            .onOpenURL { url in
                HouseholdShareManager.shared.handleIncomingURL(url)
            }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - HouseholdShareManager

/// Manages CloudKit share URLs and deep-link handling for household invitations.
/// The full CloudKit implementation resides in the Sharing feature module;
/// this class provides the minimal interface used at the app level.
@MainActor
final class HouseholdShareManager {
    static let shared = HouseholdShareManager()
    private init() {}

    /// Accepts a wochi:// or CloudKit share deep link and initiates the join flow.
    func handleIncomingURL(_ url: URL) {
        // Implementation provided by the CloudKit/Sharing feature module.
        NotificationCenter.default.post(
            name: .wochiIncomingURL,
            object: url
        )
    }

    /// Creates a CloudKit share URL for the given household.
    func createShareURL(for household: Household) async throws -> URL {
        // Placeholder – real implementation uses CKShare.
        guard let url = URL(string: "wochi://invite/\(household.id.uuidString)") else {
            throw WochiError.invalidInviteLink
        }
        return url
    }

    /// Removes the current device from the CloudKit share for the given household.
    func leaveShare(for household: Household) async throws {
        // Implementation provided by the CloudKit/Sharing feature module.
    }
}

extension Notification.Name {
    static let wochiIncomingURL = Notification.Name("wochiIncomingURL")
}
