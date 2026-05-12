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
                Task {
                    await HouseholdShareManager.shared.handleIncomingURL(url)
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
