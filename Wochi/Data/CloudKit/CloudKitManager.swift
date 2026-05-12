import CloudKit
import CoreData
import Foundation
import SwiftData

// MARK: - SyncStatus

enum SyncStatus: Equatable {
    case synced
    case syncing
    case offline
    case error(String)
}

// MARK: - CloudKitManager

@MainActor
final class CloudKitManager: ObservableObject {

    // MARK: Singleton

    static let shared = CloudKitManager()

    // MARK: Published

    @Published var syncStatus: SyncStatus = .synced
    @Published var lastSyncDate: Date?

    // MARK: Private

    private let container = CKContainer(identifier: Constants.App.cloudKitContainerID)
    private var monitoringTokens: [NSObjectProtocol] = []

    // MARK: Init

    private init() {}

    // MARK: Public API

    /// Checks the user's iCloud account status and updates `syncStatus` accordingly.
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                if syncStatus == .offline {
                    syncStatus = .synced
                }
            case .noAccount:
                syncStatus = .error("Kein iCloud-Konto angemeldet.")
            case .restricted:
                syncStatus = .error("iCloud-Zugriff ist eingeschränkt.")
            case .couldNotDetermine:
                syncStatus = .error("iCloud-Status konnte nicht ermittelt werden.")
            case .temporarilyUnavailable:
                syncStatus = .offline
            @unknown default:
                syncStatus = .error("Unbekannter iCloud-Status.")
            }
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    /// Begins observing `NSPersistentCloudKitContainer` import / export notifications.
    func startMonitoring() {
        let importName = NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification")

        let importToken = NotificationCenter.default.addObserver(
            forName: importName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleCloudKitNotification(notification)
            }
        }

        monitoringTokens.append(importToken)
    }

    // MARK: Private helpers

    private func handleCloudKitNotification(_ notification: Notification) {
        // NSPersistentCloudKitContainerEvent is not exposed publicly in SwiftData contexts,
        // so we derive state from the notification name and assume activity means syncing.
        guard let userInfo = notification.userInfo else { return }

        // Key used by NSPersistentCloudKitContainer for the event object.
        let eventKey = "event"
        if let event = userInfo[eventKey] {
            // If there is an event object, we infer in-progress sync.
            // Finished is inferred when no further notifications arrive.
            _ = event
            syncStatus = .syncing
            lastSyncDate = Date()
        } else {
            syncStatus = .synced
            lastSyncDate = Date()
        }
    }
}
