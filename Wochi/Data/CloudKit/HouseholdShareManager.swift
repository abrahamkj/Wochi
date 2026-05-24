import CloudKit
import Foundation
import SwiftData

// MARK: - HouseholdShareManager

@MainActor
final class HouseholdShareManager {

    // MARK: Singleton

    static let shared = HouseholdShareManager()

    // MARK: Private

    private let container = CKContainer(identifier: Constants.App.cloudKitContainerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase  { container.sharedCloudDatabase }

    // Cache populated by WochiAppDelegate.userDidAcceptCloudKitShareWith so
    // acceptShare(url:) can skip fetchShareMetadata entirely.
    private var metadataCache: [URL: CKShare.Metadata] = [:]

    private init() {}

    // MARK: - Metadata cache (called from AppDelegate)

    /// Called by WochiAppDelegate when iOS delivers share metadata via the
    /// native "Join Household" system sheet so we can bypass fetchShareMetadata.
    func cacheMetadata(_ metadata: CKShare.Metadata, for url: URL) {
        metadataCache[url] = metadata
    }

    // MARK: - Zone

    /// Creates (or re-uses) a custom zone named "wochi-<householdUUID>" in the owner's private DB.
    private func ensureZone(for householdID: UUID) async throws -> CKRecordZone {
        let zoneID = CKRecordZone.ID(
            zoneName: "wochi-\(householdID.uuidString)",
            ownerName: CKCurrentUserDefaultName
        )
        return try await privateDB.save(CKRecordZone(zoneID: zoneID))
    }

    // MARK: - Share creation

    /// Creates (or returns the existing) CloudKit zone + CKShare for the household
    /// and also pushes all household data to the zone so invited members can read it.
    /// Returns a real `https://www.icloud.com/share/…` URL.
    func createShareURL(for household: Household) async throws -> URL {
        let zone = try await ensureZone(for: household.id)
        let recordID = CKRecord.ID(
            recordName: "household-\(household.id.uuidString)",
            zoneID: zone.zoneID
        )

        // If the household record already has a share, return the existing URL
        // and re-push data so the invited member gets the latest snapshot.
        if let existing = try? await privateDB.record(for: recordID),
           let shareRef = existing.share,
           let shareRecord = try? await privateDB.record(for: shareRef.recordID) as? CKShare,
           let url = shareRecord.url {
            try? await CloudKitZoneSyncService.shared.pushHouseholdData(household, zoneID: zone.zoneID)
            return url
        }

        // First time: create the WH_Household record + CKShare together.
        let record = CKRecord(recordType: "WH_Household", recordID: recordID)
        record["id"]   = household.id.uuidString as CKRecordValue
        record["name"] = household.name as CKRecordValue

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue
        share.publicPermission = .none

        let op = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
        op.isAtomic = true

        // Capture the server-confirmed share URL from perRecordSaveBlock.
        var confirmedShareURL: URL?
        op.perRecordSaveBlock = { _, result in
            if case .success(let saved) = result, let s = saved as? CKShare {
                confirmedShareURL = s.url
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success:           cont.resume()
                case .failure(let err):  cont.resume(throwing: err)
                }
            }
            privateDB.add(op)
        }

        guard let url = confirmedShareURL else {
            throw WochiError.cloudKitSyncFailed(
                underlying: NSError(
                    domain: "HouseholdShareManager", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "CloudKit did not confirm the share URL"]
                )
            )
        }

        // Push shopping lists + pantry items into the zone for the invited member to read.
        try? await CloudKitZoneSyncService.shared.pushHouseholdData(household, zoneID: zone.zoneID)

        return url
    }

    // MARK: - Share detection

    /// Returns true if `url` is a real CloudKit share URL (icloud.com/share/…)
    /// as opposed to our own wochi:// deep-link.
    func isCloudKitShareURL(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host.hasSuffix("icloud.com") && url.path.hasPrefix("/share/")
    }

    // MARK: - Share acceptance

    /// Accepts a CloudKit share URL.  Returns the household (id, name, ownerName).
    ///
    /// When the user taps a share link in Messages, iOS calls
    /// `userDidAcceptCloudKitShareWith` (AppDelegate) and hands us the metadata
    /// directly — we cache it so this function can skip `fetchShareMetadata`.
    /// When the URL is pasted manually we fall back to `fetchShareMetadata` with retry.
    func acceptShare(url: URL) async throws -> (id: UUID, name: String, ownerName: String) {
        // 1. Obtain metadata — prefer cache (set by AppDelegate) to avoid the
        //    "share not found" CDN propagation window.
        let metadata: CKShare.Metadata
        if let cached = metadataCache.removeValue(forKey: url) {
            metadata = cached
        } else {
            metadata = try await fetchShareMetadataWithRetry(url: url)
        }

        // 2. Accept the share (alreadyShared → already accepted, treat as success)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            container.accept(metadata) { _, error in
                if let ckErr = error as? CKError, ckErr.code == .alreadyShared {
                    cont.resume()
                } else if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }

        return try parseHouseholdInfo(from: metadata)
    }

    // MARK: - Private helpers

    private func parseHouseholdInfo(from metadata: CKShare.Metadata) throws -> (id: UUID, name: String, ownerName: String) {
        let zoneName = metadata.share.recordID.zoneID.zoneName
        guard zoneName.hasPrefix("wochi-"),
              let householdID = UUID(uuidString: String(zoneName.dropFirst("wochi-".count)))
        else { throw WochiError.invalidInviteLink }

        let ownerName = metadata.ownerIdentity.userRecordID?.recordName ?? CKCurrentUserDefaultName

        let sharedZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(
            recordName: "household-\(householdID.uuidString)",
            zoneID: sharedZoneID
        )

        // Fetch name from shared DB (best-effort — record may not be visible yet)
        let name: String
        do {
            let ckRecord = try await sharedDB.record(for: recordID)
            name = ckRecord["name"] as? String ?? "Shared Household"
        } catch {
            name = "Shared Household"
        }

        return (id: householdID, name: name, ownerName: ownerName)
    }

    /// Retries `fetchShareMetadata` up to 5 times with exponential backoff.
    /// The "share not found" server error is a raw CKDPResponseOperationResult,
    /// so we retry on ANY error from this call (all transient errors look the same).
    private func fetchShareMetadataWithRetry(url: URL) async throws -> CKShare.Metadata {
        let backoffSeconds: [UInt64] = [2, 4, 8, 15]
        var lastError: Error = WochiError.invalidInviteLink

        for attempt in 0...backoffSeconds.count {
            do {
                return try await withCheckedThrowingContinuation { cont in
                    container.fetchShareMetadata(url: url) { metadata, error in
                        if let m = metadata {
                            cont.resume(returning: m)
                        } else {
                            cont.resume(throwing: error ?? WochiError.invalidInviteLink)
                        }
                    }
                }
            } catch {
                lastError = error
                guard attempt < backoffSeconds.count else { break }
                try await Task.sleep(nanoseconds: backoffSeconds[attempt] * 1_000_000_000)
            }
        }
        throw lastError
    }

    // MARK: - Leave share

    func leaveShare(for household: Household) async throws {
        let zoneID = CKRecordZone.ID(
            zoneName: "wochi-\(household.id.uuidString)",
            ownerName: CKCurrentUserDefaultName
        )
        let recordID = CKRecord.ID(
            recordName: "household-\(household.id.uuidString)",
            zoneID: zoneID
        )

        guard let shareRef = try? await privateDB.record(for: recordID).share else { return }
        let shareRecord: CKShare = try await withCheckedThrowingContinuation { cont in
            privateDB.fetch(withRecordID: shareRef.recordID) { record, error in
                if let share = record as? CKShare {
                    cont.resume(returning: share)
                } else {
                    cont.resume(throwing: error ?? WochiError.cloudKitSyncFailed(
                        underlying: NSError(domain: "HouseholdShareManager", code: -2)
                    ))
                }
            }
        }

        let currentParticipant = shareRecord.participants.first { $0.role != .owner }
        if let p = currentParticipant { shareRecord.removeParticipant(p) }

        let saveOp = CKModifyRecordsOperation(recordsToSave: [shareRecord], recordIDsToDelete: nil)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            saveOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success:          cont.resume()
                case .failure(let e):   cont.resume(throwing: e)
                }
            }
            privateDB.add(saveOp)
        }
    }

    // MARK: - Handle incoming URL (legacy deep-link dispatch)

    func handleIncomingURL(_ url: URL) async {
        NotificationCenter.default.post(
            name: Notification.Name("WochiInviteReceived"),
            object: nil,
            userInfo: ["url": url]
        )
    }
}
