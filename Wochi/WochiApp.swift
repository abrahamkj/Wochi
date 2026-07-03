import SwiftUI
import SwiftData
import BackgroundTasks

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    @Published var currentHousehold: Household?
    @Published var currentMember: HouseholdMember?
    @Published var isOffline: Bool = false
    /// Set when the app is opened via a CKShare URL so any screen can present the join flow.
    @Published var incomingShareURL: URL? = nil
}

// MARK: - App Entry Point

@main
struct WochiApp: App {
    @UIApplicationDelegateAdaptor(WochiAppDelegate.self) private var appDelegate

    @StateObject private var appState = AppState()

    private let modelContainer: ModelContainer = {
        do {
            let container = try WochiDataContainer.create()
            FlyerRefreshTask.register(modelContainer: container)
            return container
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
                // Handles URLs pasted in-app or opened from Safari.
                // The AppDelegate handles the native iOS share-accept sheet.
                if HouseholdShareManager.shared.isCloudKitShareURL(url) {
                    appState.incomingShareURL = url
                } else {
                    Task { await HouseholdShareManager.shared.handleIncomingURL(url) }
                }
            }
            .task {
                // Inject AppState into the delegate so it can route CKShare
                // acceptance events from the system sheet into the running app.
                appDelegate.appState = appState
                // Schedule the first background flyer refresh.
                FlyerRefreshTask.schedule()
            }
        }
        .modelContainer(modelContainer)
    }
}
