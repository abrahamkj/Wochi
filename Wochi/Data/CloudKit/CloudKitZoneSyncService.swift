import CloudKit
import SwiftData
import Foundation

// MARK: - CloudKitZoneSyncService
//
// Pushes household data (shopping lists, items, pantry) as WH_* CKRecords
// into the owner's custom zone so invited members can read them after
// accepting the CKShare. This is separate from SwiftData's automatic private-DB
// sync, which only works within the same Apple ID.

@MainActor
final class CloudKitZoneSyncService {

    // MARK: Singleton

    static let shared = CloudKitZoneSyncService()

    // MARK: Private

    private let container = CKContainer(identifier: Constants.App.cloudKitContainerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase  { container.sharedCloudDatabase }

    private init() {}

    // MARK: - Push (owner → zone)

    /// Snapshot all shopping lists + pantry items into the shared CloudKit zone
    /// so members with a different Apple ID can read them after accepting the share.
    /// Uses savePolicy .allKeys — owner data is always authoritative for this zone.
    func pushHouseholdData(_ household: Household, zoneID: CKRecordZone.ID) async throws {
        var records: [CKRecord] = []

        for list in household.shoppingLists ?? [] {
            let listRecord = CKRecord(
                recordType: "WH_ShoppingList",
                recordID: CKRecord.ID(recordName: "list-\(list.id.uuidString)", zoneID: zoneID)
            )
            listRecord["id"]          = list.id.uuidString as CKRecordValue
            listRecord["name"]        = list.name as CKRecordValue
            listRecord["isArchived"]  = NSNumber(value: list.isArchived)
            listRecord["createdAt"]   = list.createdAt as CKRecordValue
            listRecord["householdID"] = household.id.uuidString as CKRecordValue
            records.append(listRecord)

            for item in list.items ?? [] {
                let itemRecord = CKRecord(
                    recordType: "WH_ShoppingItem",
                    recordID: CKRecord.ID(recordName: "item-\(item.id.uuidString)", zoneID: zoneID)
                )
                itemRecord["id"]        = item.id.uuidString as CKRecordValue
                itemRecord["name"]      = item.name as CKRecordValue
                itemRecord["quantity"]  = NSNumber(value: item.quantity)
                itemRecord["isChecked"] = NSNumber(value: item.isChecked)
                itemRecord["listID"]    = list.id.uuidString as CKRecordValue
                itemRecord["category"]  = item.category.rawValue as CKRecordValue
                itemRecord["sortOrder"] = NSNumber(value: item.sortOrder)
                if let unit  = item.unit           { itemRecord["unit"]  = unit as CKRecordValue }
                if let note  = item.note           { itemRecord["note"]  = note as CKRecordValue }
                if let price = item.estimatedPrice { itemRecord["estimatedPrice"] = NSNumber(value: price) }
                if let brand = item.preferredBrand { itemRecord["preferredBrand"] = brand as CKRecordValue }
                records.append(itemRecord)
            }
        }

        for item in household.pantryItems ?? [] {
            let record = CKRecord(
                recordType: "WH_PantryItem",
                recordID: CKRecord.ID(recordName: "pantry-\(item.id.uuidString)", zoneID: zoneID)
            )
            record["id"]               = item.id.uuidString as CKRecordValue
            record["name"]             = item.name as CKRecordValue
            record["quantity"]         = NSNumber(value: item.quantity)
            record["category"]         = item.category.rawValue as CKRecordValue
            record["lowStockThreshold"] = NSNumber(value: item.lowStockThreshold)
            record["householdID"]      = household.id.uuidString as CKRecordValue
            if let unit   = item.unit        { record["unit"]       = unit as CKRecordValue }
            if let brand  = item.brand       { record["brand"]      = brand as CKRecordValue }
            if let expiry = item.expiryDate  { record["expiryDate"] = expiry as CKRecordValue }
            if let notes  = item.notes       { record["notes"]      = notes as CKRecordValue }
            records.append(record)
        }

        guard !records.isEmpty else { return }

        // CloudKit: max 400 records per operation
        let batchSize = 400
        for offset in stride(from: 0, to: records.count, by: batchSize) {
            let batch = Array(records[offset..<min(offset + batchSize, records.count)])
            let op = CKModifyRecordsOperation(recordsToSave: batch, recordIDsToDelete: nil)
            op.savePolicy = .allKeys
            op.isAtomic   = false
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:          cont.resume()
                    case .failure(let err): cont.resume(throwing: err)
                    }
                }
                self.privateDB.add(op)
            }
        }
    }

    // MARK: - Pull (invited member ← shared zone)

    /// Fetch all WH_* records from the shared zone and create/update
    /// the corresponding SwiftData objects in `context`.
    func pullSharedData(
        householdID: UUID,
        ownerName: String,
        context: ModelContext
    ) async throws {
        let zoneID = CKRecordZone.ID(
            zoneName: "wochi-\(householdID.uuidString)",
            ownerName: ownerName
        )

        let allHouseholds = try context.fetch(FetchDescriptor<Household>())
        guard let household = allHouseholds.first(where: { $0.id == householdID }) else { return }

        // MARK: Shopping lists

        let listQuery = CKQuery(recordType: "WH_ShoppingList", predicate: NSPredicate(value: true))
        let (listResults, _) = try await sharedDB.records(
            matching: listQuery, inZoneWith: zoneID, resultsLimit: 1_000
        )

        let existingLists = try context.fetch(FetchDescriptor<ShoppingList>())
        var listByID: [String: ShoppingList] = [:]

        for (_, result) in listResults {
            guard case .success(let r) = result,
                  let idStr = r["id"] as? String,
                  let id    = UUID(uuidString: idStr),
                  let name  = r["name"] as? String else { continue }

            let list: ShoppingList
            if let existing = existingLists.first(where: { $0.id == id }) {
                existing.name       = name
                existing.isArchived = (r["isArchived"] as? NSNumber)?.boolValue ?? false
                list = existing
            } else {
                list            = ShoppingList(name: name)
                list.id         = id
                list.isArchived = (r["isArchived"] as? NSNumber)?.boolValue ?? false
                list.household  = household
                context.insert(list)
                household.shoppingLists = (household.shoppingLists ?? []) + [list]
            }
            listByID[idStr] = list
        }

        // MARK: Shopping items

        let itemQuery = CKQuery(recordType: "WH_ShoppingItem", predicate: NSPredicate(value: true))
        let (itemResults, _) = try await sharedDB.records(
            matching: itemQuery, inZoneWith: zoneID, resultsLimit: 1_000
        )

        let existingItems = try context.fetch(FetchDescriptor<ShoppingItem>())

        for (_, result) in itemResults {
            guard case .success(let r) = result,
                  let idStr     = r["id"] as? String,
                  let id        = UUID(uuidString: idStr),
                  let name      = r["name"] as? String,
                  let listIDStr = r["listID"] as? String,
                  let parent    = listByID[listIDStr] else { continue }

            let qty       = (r["quantity"]  as? NSNumber)?.doubleValue ?? 1
            let isChecked = (r["isChecked"] as? NSNumber)?.boolValue  ?? false

            if let existing = existingItems.first(where: { $0.id == id }) {
                existing.name      = name
                existing.quantity  = qty
                existing.unit      = r["unit"] as? String
                existing.isChecked = isChecked
                if let catStr = r["category"] as? String,
                   let cat = ItemCategory(rawValue: catStr) { existing.category = cat }
            } else {
                let item      = ShoppingItem(name: name, quantity: qty, unit: r["unit"] as? String)
                item.id        = id
                item.isChecked = isChecked
                item.sortOrder = (r["sortOrder"] as? NSNumber)?.intValue ?? 0
                item.note      = r["note"] as? String
                if let catStr = r["category"] as? String,
                   let cat = ItemCategory(rawValue: catStr) { item.category = cat }
                item.list = parent
                parent.items = (parent.items ?? []) + [item]
                context.insert(item)
            }
        }

        // MARK: Pantry items

        let pantryQuery = CKQuery(recordType: "WH_PantryItem", predicate: NSPredicate(value: true))
        let (pantryResults, _) = try await sharedDB.records(
            matching: pantryQuery, inZoneWith: zoneID, resultsLimit: 1_000
        )

        let existingPantry = try context.fetch(FetchDescriptor<PantryItem>())

        for (_, result) in pantryResults {
            guard case .success(let r) = result,
                  let idStr = r["id"] as? String,
                  let id    = UUID(uuidString: idStr),
                  let name  = r["name"] as? String else { continue }

            let qty = (r["quantity"] as? NSNumber)?.doubleValue ?? 1

            if let existing = existingPantry.first(where: { $0.id == id }) {
                existing.name             = name
                existing.quantity         = qty
                existing.unit             = r["unit"] as? String
                existing.expiryDate       = r["expiryDate"] as? Date
                existing.notes            = r["notes"] as? String
                if let catStr = r["category"] as? String,
                   let cat = ItemCategory(rawValue: catStr) { existing.category = cat }
            } else {
                let item = PantryItem(name: name, quantity: qty, unit: r["unit"] as? String)
                item.id                = id
                item.lowStockThreshold = (r["lowStockThreshold"] as? NSNumber)?.doubleValue ?? 1
                item.brand             = r["brand"] as? String
                item.expiryDate        = r["expiryDate"] as? Date
                item.notes             = r["notes"] as? String
                if let catStr = r["category"] as? String,
                   let cat = ItemCategory(rawValue: catStr) { item.category = cat }
                item.household = household
                context.insert(item)
                household.pantryItems = (household.pantryItems ?? []) + [item]
            }
        }

        try context.save()
    }
}
