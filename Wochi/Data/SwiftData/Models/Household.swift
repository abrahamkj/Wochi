import Foundation
import SwiftData

@Model
final class Household {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var currency: String
    var countryCode: String

    @Relationship(deleteRule: .cascade)
    var members: [HouseholdMember]

    @Relationship(deleteRule: .cascade)
    var shoppingLists: [ShoppingList]

    @Relationship(deleteRule: .cascade)
    var pantryItems: [PantryItem]

    @Relationship(deleteRule: .cascade)
    var receipts: [Receipt]

    @Relationship(deleteRule: .cascade)
    var preferredStores: [PreferredStore]

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
    }
}

extension Household {
    static func sample() -> Household {
        let h = Household(name: "Familie Müller")
        let owner = HouseholdMember(appleUserID: "sample-user-1", displayName: "Max Müller", role: .owner)
        owner.isCurrentDevice = true
        h.members.append(owner)
        h.members.append(HouseholdMember(appleUserID: "sample-user-2", displayName: "Lisa Müller", role: .member))
        return h
    }
}
