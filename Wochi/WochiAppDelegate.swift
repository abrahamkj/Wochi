import UIKit
import CloudKit

// MARK: - WochiAppDelegate
//
// Implements `userDidAcceptCloudKitShareWith` so iOS shows the native
// "Join Household on Wochi?" system sheet when the user taps a share link
// in Messages or Mail.
//
// Crucially, iOS hands us the CKShare.Metadata directly here — we cache it
// in HouseholdShareManager so `acceptShare(url:)` can skip `fetchShareMetadata`
// entirely.  This avoids the "share not found" error that occurs when the
// CloudKit CDN hasn't yet propagated a freshly-created share token.

final class WochiAppDelegate: NSObject, UIApplicationDelegate {

    // Injected by WochiApp after @StateObject creation.
    weak var appState: AppState?

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard let url = cloudKitShareMetadata.share.url else { return }
        Task { @MainActor in
            // Cache the metadata so acceptShare(url:) can skip fetchShareMetadata.
            HouseholdShareManager.shared.cacheMetadata(cloudKitShareMetadata, for: url)
            // Trigger ShareAcceptView to appear.
            self.appState?.incomingShareURL = url
        }
    }
}
