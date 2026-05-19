import Foundation
import SwiftData

@Model
final class SubstitutionAlert {
    var id: UUID = UUID()
    var productName: String = ""
    var preferredBrand: String?
    var currentStore: StoreChain = .other
    var dealStore: StoreChain = .other
    var regularPrice: Double = 0
    var dealPrice: Double = 0
    var savingsPercent: Double = 0
    var validFrom: Date = Date()
    var validUntil: Date = Date()
    var flyerImageURL: String?
    var isRead: Bool = false
    var isDismissed: Bool = false
    var createdAt: Date = Date()

    @Relationship var household: Household?

    init(productName: String, dealStore: StoreChain, regularPrice: Double, dealPrice: Double, validUntil: Date) {
        self.id = UUID()
        self.productName = productName
        self.currentStore = .kaufland
        self.dealStore = dealStore
        self.regularPrice = regularPrice
        self.dealPrice = dealPrice
        self.savingsPercent = ((regularPrice - dealPrice) / regularPrice) * 100
        self.validFrom = Date()
        self.validUntil = validUntil
        self.isRead = false
        self.isDismissed = false
        self.createdAt = Date()
    }

    var isActive: Bool {
        Date() >= validFrom && Date() <= validUntil
    }

    var savingsAmount: Double {
        regularPrice - dealPrice
    }
}

extension SubstitutionAlert {
    static func sample() -> SubstitutionAlert {
        SubstitutionAlert(
            productName: "Barilla Penne",
            dealStore: .lidl,
            regularPrice: 2.49,
            dealPrice: 1.49,
            validUntil: Date().addingTimeInterval(5 * 24 * 60 * 60)
        )
    }
}
