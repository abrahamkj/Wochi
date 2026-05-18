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
        ])

        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // cloudKitDatabase: .automatic crashes at startup when the CloudKit
            // container entitlement is not provisioned (e.g. local dev, simulator
            // without iCloud sign-in). Use a plain local store for now.
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }

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
