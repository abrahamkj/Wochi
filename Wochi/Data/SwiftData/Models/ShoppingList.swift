import Foundation
import SwiftData

@Model
final class ShoppingList {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var sortOrder: Int

    var household: Household?

    @Relationship(deleteRule: .cascade)
    var items: [ShoppingItem]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.sortOrder = 0
        self.items = []
    }

    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isChecked }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var checkedItems: [ShoppingItem] {
        items.filter { $0.isChecked }
    }

    var totalEstimatedCost: Double {
        items.compactMap { $0.estimatedPrice }.reduce(0, +)
    }
}

extension ShoppingList {
    static func sample() -> ShoppingList {
        let list = ShoppingList(name: "Wocheneinkauf")
        let items: [(String, Double, String?)] = [
            ("Milch", 2, "Liter"),
            ("Brot", 1, nil),
            ("Äpfel", 1, "kg"),
            ("Joghurt", 3, "Stück"),
            ("Nudeln", 2, "Packung")
        ]
        for (name, qty, unit) in items {
            let item = ShoppingItem(name: name, quantity: qty, unit: unit)
            list.items.append(item)
        }
        return list
    }
}
