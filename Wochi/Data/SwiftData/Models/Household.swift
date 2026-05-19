import Foundation
import SwiftData

@Model
final class Household {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var currency: String = "EUR"
    var countryCode: String = "DE"

    @Relationship(deleteRule: .cascade)
    var members: [HouseholdMember]? = nil

    @Relationship(deleteRule: .cascade)
    var shoppingLists: [ShoppingList]? = nil

    @Relationship(deleteRule: .cascade)
    var pantryItems: [PantryItem]? = nil

    @Relationship(deleteRule: .cascade)
    var receipts: [Receipt]? = nil

    @Relationship(deleteRule: .cascade)
    var preferredStores: [PreferredStore]? = nil

    @Relationship(deleteRule: .cascade)
    var substitutionAlerts: [SubstitutionAlert]? = nil

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currency = "EUR"
        self.countryCode = "DE"
        self.members = []
        self.shoppingLists = []
        self.pantryItems = []
        self.receipts = []
        self.preferredStores = []
        self.substitutionAlerts = []
    }
}

extension Household {
    static func sample() -> Household {
        let h = Household(name: "Familie Müller")
        let owner = HouseholdMember(appleUserID: "sample-user-1", displayName: "Max Müller", role: .owner)
        owner.isCurrentDevice = true
        h.members = (h.members ?? []) + [owner]
        h.members = (h.members ?? []) + [HouseholdMember(appleUserID: "sample-user-2", displayName: "Lisa Müller", role: .member)]
        return h
    }
}
