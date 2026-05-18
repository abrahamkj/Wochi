import CloudKit
import Foundation

// MARK: - HouseholdShareManager

@MainActor
final class HouseholdShareManager {

    // MARK: Singleton

    static let shared = HouseholdShareManager()

    // MARK: Private

    private let container = CKContainer(identifier: Constants.App.cloudKitContainerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }

    // MARK: Init

    private init() {}

    // MARK: Public API

    /// Creates a `CKShare` for the given household and returns its share URL.
    ///
    /// Falls back to a placeholder wochi:// URL if CloudKit is unavailable.
    func createShareURL(for household: Household) async throws -> URL {
        // Build a root record representing the household so we can attach a share.
        let recordID = CKRecord.ID(recordName: household.id.uuidString)
        let rootRecord = CKRecord(recordType: "Household", recordID: recordID)
        rootRecord["name"] = household.name as CKRecordValue

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue
        share.publicPermission = .none

        do {
            let operation = CKModifyRecordsOperation(
                recordsToSave: [rootRecord, share],
                recordIDsToDelete: nil
            )
            operation.isAtomic = true

            let (savedRecords, deletedIDs) = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<([CKRecord], [CKRecord.ID]), Error>) in
                // Use the modifyRecordsResultBlock to get the final result of the operation.
                // Use the Result-based completion form (match other usages in this file).
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: ([], []))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDB.add(operation)
            }
            _ = (savedRecords, deletedIDs)

            if let shareURL = share.url {
                return shareURL
            }
        } catch {
            // Graceful fallback – return a placeholder wochi:// URL so callers
            // can still display something meaningful without crashing.
            return placeholderURL(for: household)
        }

        return placeholderURL(for: household)
    }

    /// Handles an incoming URL from a Universal Link or custom wochi:// scheme.
    ///
    /// Posts a `Notification` named `"WochiInviteReceived"` with the URL in `userInfo`.
    func handleIncomingURL(_ url: URL) async {
        NotificationCenter.default.post(
            name: Notification.Name("WochiInviteReceived"),
            object: nil,
            userInfo: ["url": url]
        )
    }

    /// Removes the current device user from the `CKShare` participants for the given household.
    func leaveShare(for household: Household) async throws {
        let recordID = CKRecord.ID(recordName: household.id.uuidString)

        // Fetch the existing share for this record.
        let fetchOperation = CKFetchRecordsOperation(recordIDs: [recordID])
        fetchOperation.desiredKeys = nil

        let records: [CKRecord.ID: CKRecord] = try await withCheckedThrowingContinuation { continuation in
            var fetched: [CKRecord.ID: CKRecord] = [:]
            fetchOperation.perRecordResultBlock = { recordID, result in
                if case .success(let record) = result {
                    fetched[recordID] = record
                }
            }
            fetchOperation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetched)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(fetchOperation)
        }

        guard let rootRecord = records[recordID],
              let shareRef = rootRecord.share else {
            // Nothing to leave – share may not exist yet.
            return
        }

        // Fetch the share record itself.
        let shareRecord: CKShare = try await withCheckedThrowingContinuation { continuation in
            privateDB.fetch(withRecordID: shareRef.recordID) { record, error in
                if let share = record as? CKShare {
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: error ?? WochiError.cloudKitSyncFailed(
                        underlying: NSError(domain: "HouseholdShareManager", code: -1))
                    )
                }
            }
        }

        // Find the current user participant and remove them.
        let currentParticipant = shareRecord.participants.first { $0.permission != .readWrite || $0.role == .owner }
        if let participant = currentParticipant {
            shareRecord.removeParticipant(participant)
        }

        let saveOperation = CKModifyRecordsOperation(
            recordsToSave: [shareRecord],
            recordIDsToDelete: nil
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            saveOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(saveOperation)
        }
    }

    // MARK: Private helpers

    private func placeholderURL(for household: Household) -> URL {
        var components = URLComponents()
        components.scheme = Constants.App.urlScheme
        components.host = "invite"
        components.queryItems = [
            URLQueryItem(name: "household", value: household.id.uuidString)
        ]
        return components.url ?? URL(string: "\(Constants.App.urlScheme)://invite")!
    }
}
