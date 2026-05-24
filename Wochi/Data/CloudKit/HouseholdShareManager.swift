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

    private init() {}

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

    /// Accepts a CloudKit share URL.  Returns the household (id, name, ownerName) from the
    /// shared record so the caller can create a local SwiftData copy and pull zone data.
    func acceptShare(url: URL) async throws -> (id: UUID, name: String, ownerName: String) {
        // 1. Fetch metadata
        let metadata: CKShare.Metadata = try await withCheckedThrowingContinuation { cont in
            container.fetchShareMetadata(url: url) { metadata, error in
                if let m = metadata {
                    cont.resume(returning: m)
                } else {
                    cont.resume(throwing: error ?? WochiError.invalidInviteLink)
                }
            }
        }

        // 2. Accept the share
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            container.accept(metadata) { _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }

        // 3. Parse household UUID from zone name "wochi-<UUID>"
        let zoneName = metadata.share.recordID.zoneID.zoneName
        guard zoneName.hasPrefix("wochi-"),
              let householdID = UUID(uuidString: String(zoneName.dropFirst("wochi-".count)))
        else { throw WochiError.invalidInviteLink }

        // 4. Determine ownerName for use with the shared zone
        let ownerName = metadata.ownerIdentity.userRecordID?.recordName ?? CKCurrentUserDefaultName

        // 5. Fetch the WH_Household record from the shared database to get the household name
        let sharedZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(
            recordName: "household-\(householdID.uuidString)",
            zoneID: sharedZoneID
        )

        do {
            let ckRecord = try await sharedDB.record(for: recordID)
            let name = ckRecord["name"] as? String ?? "Shared Household"
            return (id: householdID, name: name, ownerName: ownerName)
        } catch {
            return (id: householdID, name: "Shared Household", ownerName: ownerName)
        }
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
