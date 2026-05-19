import Foundation
import SwiftData

@Model
final class ReceiptItem {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String?
    var brand: String?
    var quantity: Double = 1
    var unit: String?
    var unitPrice: Double = 0
    var totalPrice: Double = 0
    var category: ItemCategory = .other
    var isDiscounted: Bool = false
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
