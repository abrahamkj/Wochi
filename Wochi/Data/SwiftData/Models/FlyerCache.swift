import Foundation
import SwiftData

@Model
final class FlyerCache {
    var id: UUID = UUID()
    var productName: String = ""
    var brand: String?
    var storeName: String = ""
    var regularPrice: Double = 0
    var dealPrice: Double = 0
    var validFrom: Date = Date()
    var validUntil: Date = Date()
    var category: String?
    var flyerImageURL: String?
    var fetchedAt: Date = Date()

    init(from price: FlyerPrice) {
        self.id            = price.id
        self.productName   = price.productName
        self.brand         = price.brand
        self.storeName     = price.store
        self.regularPrice  = price.regularPrice
        self.dealPrice     = price.dealPrice
        self.validFrom     = price.validFrom
        self.validUntil    = price.validUntil
        self.category      = price.category
        self.flyerImageURL = price.flyerImageURL
        self.fetchedAt     = Date()
    }

    var isExpired: Bool { Date() > validUntil }

    var asFlyerPrice: FlyerPrice {
        FlyerPrice(
            id:            id,
            productName:   productName,
            brand:         brand,
            store:         storeName,
            regularPrice:  regularPrice,
            dealPrice:     dealPrice,
            validFrom:     validFrom,
            validUntil:    validUntil,
            category:      category,
            flyerImageURL: flyerImageURL
        )
    }
}
