import Foundation
import SwiftData

@Model
final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String?
    var brand: String?
    var quantity: Double
    var unit: String?
    var unitPrice: Double
    var totalPrice: Double
    var category: ItemCategory
    var isDiscounted: Bool
    var originalPrice: Double?

    var receipt: Receipt?
    var matchedPantryItemID: UUID?

    init(name: String, quantity: Double, unitPrice: Double, totalPrice: Double) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = ItemCategory.classify(name: name)
        self.isDiscounted = false
    }
}
