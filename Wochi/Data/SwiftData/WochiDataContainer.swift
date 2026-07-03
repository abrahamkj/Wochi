import Foundation
import SwiftData

@MainActor
enum WochiDataContainer {
    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Household.self,
            HouseholdMember.self,
            ShoppingList.self,
            ShoppingItem.self,
            PantryItem.self,
            Receipt.self,
            ReceiptItem.self,
            PreferredStore.self,
            SubstitutionAlert.self,
            FlyerCache.self,
        ])

        // Use CloudKit private database for sync across the current user's devices.
        // @Attribute(.unique) has been removed from all model IDs because CloudKit
        // does not support unique constraints — UUID uniqueness is guaranteed by
        // the generator. Cross-account household sharing requires CKShare (Phase 2).
        let cloudKit: ModelConfiguration.CloudKitDatabase = inMemory ? .none : .private("iCloud.com.abram.wochi")
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit
        )

        return try ModelContainer(for: schema, configurations: [config])
    }

    // Preview container with sample data
    static var preview: ModelContainer = {
        let container = try! create(inMemory: true)
        let context = container.mainContext

        let household = Household.sample()
        context.insert(household)

        let list = ShoppingList.sample()
        list.household = household
        context.insert(list)

        let pantryItem = PantryItem.sample()
        pantryItem.household = household
        context.insert(pantryItem)

        let receipt = Receipt.sample()
        receipt.household = household
        context.insert(receipt)

        let alert = SubstitutionAlert.sample()
        alert.household = household
        context.insert(alert)

        try! context.save()
        return container
    }()
}
