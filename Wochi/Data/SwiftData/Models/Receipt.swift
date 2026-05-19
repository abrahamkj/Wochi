import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID = UUID()
    var storeName: String = ""
    var storeAddress: String?
    var purchaseDate: Date = Date()
    var totalAmount: Double = 0
    var currency: String = "EUR"
    var scannedAt: Date = Date()
    var scannedByMemberID: UUID?
    var rawOCRText: String?
    var imageData: Data?
    var isVerified: Bool = false

    var household: Household?

    @Relationship(deleteRule: .cascade)
    var items: [ReceiptItem]? = nil

    init(storeName: String, purchaseDate: Date, totalAmount: Double) {
        self.id = UUID()
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.currency = "EUR"
        self.scannedAt = Date()
        self.isVerified = false
        self.items = []
    }

    var month: Int { Calendar.current.component(.month, from: purchaseDate) }
    var year: Int { Calendar.current.component(.year, from: purchaseDate) }
}

extension Receipt {
    static func sample() -> Receipt {
        let r = Receipt(storeName: "Kaufland", purchaseDate: Date(), totalAmount: 47.83)
        r.isVerified = true
        let i1 = ReceiptItem(name: "Milch 1L", quantity: 2, unitPrice: 1.09, totalPrice: 2.18)
        i1.category = .dairy
        let i2 = ReceiptItem(name: "Bio Äpfel", quantity: 1.5, unitPrice: 2.99, totalPrice: 4.49)
        i2.category = .fruit
        r.items = [i1, i2]
        return r
    }
}
