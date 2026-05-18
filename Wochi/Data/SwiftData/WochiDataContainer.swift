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

        // cloudKitDatabase defaults to .automatic — must be set to .none explicitly
        // to prevent SwiftData from trying CloudKit even when only local storage
        // is wanted. CloudKit also requires all model attributes to be optional
        // and all relationships to be optional with inverses, which our models
        // don't satisfy yet.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
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
