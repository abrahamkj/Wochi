import Foundation

struct FlyerPrice: Codable, Identifiable {
    let id: UUID
    let productName: String
    let brand: String?
    let store: String
    let regularPrice: Double
    let dealPrice: Double
    let validFrom: Date
    let validUntil: Date
    let category: String?
    let flyerImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case productName  = "product_name"
        case brand
        case store
        case regularPrice = "regular_price"
        case dealPrice    = "deal_price"
        case validFrom    = "valid_from"
        case validUntil   = "valid_until"
        case category
        case flyerImageURL = "flyer_image_url"
    }

    var savingsPercent: Double {
        guard regularPrice > 0 else { return 0 }
        return ((regularPrice - dealPrice) / regularPrice) * 100
    }

    var isActive: Bool {
        let now = Date()
        return now >= validFrom && now <= validUntil
    }

    var storeChain: StoreChain {
        StoreChain(rawValue: store) ?? .other
    }
}
