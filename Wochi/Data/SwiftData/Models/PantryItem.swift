import Foundation
import SwiftData

@Model
final class PantryItem {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String?
    var category: ItemCategory
    var brand: String?
    var barcode: String?
    var expiryDate: Date?
    var openedDate: Date?
    var lowStockThreshold: Double
    var addedAt: Date
    var lastUpdatedAt: Date
    var lastUpdatedByMemberID: UUID?
    var imageData: Data?
    var notes: String?

    var household: Household?

    init(name: String, quantity: Double = 1, unit: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = ItemCategory.classify(name: name)
        self.lowStockThreshold = Constants.Pantry.defaultLowStockThreshold
        self.addedAt = Date()
        self.lastUpdatedAt = Date()
    }

    var isLowStock: Bool {
        quantity <= lowStockThreshold
    }

    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry <= Date().addingTimeInterval(Double(Constants.Pantry.expiryWarningDays) * 24 * 60 * 60)
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }

    var daysUntilExpiry: Int? {
        guard let expiry = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
    }

    var stockStatus: StockStatus {
        if isExpired { return .expired }
        if isExpiringSoon { return .expiringSoon }
        if isLowStock { return .lowStock }
        return .ok
    }

    enum StockStatus {
        case ok, lowStock, expiringSoon, expired
    }
}

extension PantryItem {
    static func sample() -> PantryItem {
        let item = PantryItem(name: "Milch", quantity: 1, unit: "Liter")
        item.brand = "Alpro"
        item.expiryDate = Date().addingTimeInterval(2 * 24 * 60 * 60)
        item.category = .dairy
        return item
    }
}
