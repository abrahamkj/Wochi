import Foundation

struct BudgetRecord {
    let month: Int
    let year: Int
    let householdID: UUID
    let totalSpent: Double
    let currency: String

    let byStore: [StoreSpend]
    let byCategory: [CategorySpend]
    let byMember: [MemberSpend]
    let receiptCount: Int

    struct StoreSpend: Identifiable {
        let id = UUID()
        let storeName: String
        let amount: Double
        let percentage: Double
        let receiptCount: Int
    }

    struct CategorySpend: Identifiable {
        let id = UUID()
        let category: ItemCategory
        let amount: Double
        let percentage: Double
    }

    struct MemberSpend: Identifiable {
        let id = UUID()
        let memberID: UUID
        let memberName: String
        let amount: Double
        let receiptCount: Int
    }
}

struct FlyerPrice: Codable, Identifiable {
    let id: UUID
    let storeChain: String
    let productName: String
    let brand: String?
    let price: Double
    let unit: String?
    let unitPrice: Double?
    let isDiscounted: Bool
    let originalPrice: Double?
    let discountPercent: Double?
    let validFrom: String
    let validUntil: String
    let flyerPageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, brand, price, unit
        case storeChain = "store_chain"
        case productName = "product_name"
        case unitPrice = "unit_price"
        case isDiscounted = "is_discounted"
        case originalPrice = "original_price"
        case discountPercent = "discount_percent"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case flyerPageURL = "flyer_page_url"
    }
}
