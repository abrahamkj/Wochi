import UIKit
import CloudKit

// MARK: - WochiAppDelegate
//
// Required so iOS can call `userDidAcceptCloudKitShareWith` when the user
// taps a share link in Messages/Mail and confirms the native "Join Household
// on Wochi?" system sheet.  Without this the system sheet never appears and
// the invitation can only be accepted by pasting the URL inside the app.

final class WochiAppDelegate: NSObject, UIApplicationDelegate {

    // Set by WochiApp after @StateObject creation so the delegate can route
    // the acceptance metadata into the running app.
    weak var appState: AppState?

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        // The system already verified the share exists and showed the dialog;
        // hand the URL straight to AppState so ShareAcceptView opens.
        // (acceptShare will still call container.accept — iOS does NOT auto-accept.)
        guard let url = cloudKitShareMetadata.share.url else { return }
        Task { @MainActor in
            self.appState?.incomingShareURL = url
        }
    }
}
