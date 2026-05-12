import XCTest
@testable import Wochi

final class ComputeBudgetUseCaseTests: XCTestCase {

    func testEmptyReceiptsReturnsZero() {
        let household = Household(name: "Test")
        let record = ComputeBudgetUseCase.compute(
            for: household, month: 1, year: 2025, receipts: []
        )
        XCTAssertEqual(record.totalSpent, 0)
        XCTAssertEqual(record.receiptCount, 0)
        XCTAssertTrue(record.byStore.isEmpty)
        XCTAssertTrue(record.byCategory.isEmpty)
    }

    func testTotalSumsCorrectly() {
        let household = Household(name: "Test")
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 10
        let date = Calendar.current.date(from: components)!

        let r1 = Receipt(storeName: "Kaufland", purchaseDate: date, totalAmount: 30.00)
        let r2 = Receipt(storeName: "Lidl",     purchaseDate: date, totalAmount: 20.00)

        let record = ComputeBudgetUseCase.compute(
            for: household, month: 3, year: 2025, receipts: [r1, r2]
        )
        XCTAssertEqual(record.totalSpent, 50.00, accuracy: 0.01)
        XCTAssertEqual(record.receiptCount, 2)
    }

    func testByStorePercentages() {
        let household = Household(name: "Test")
        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 1
        let date = Calendar.current.date(from: comps)!

        let r1 = Receipt(storeName: "REWE",     purchaseDate: date, totalAmount: 60.00)
        let r2 = Receipt(storeName: "Kaufland", purchaseDate: date, totalAmount: 40.00)

        let record = ComputeBudgetUseCase.compute(
            for: household, month: 3, year: 2025, receipts: [r1, r2]
        )
        // Sorted descending by amount: REWE first
        XCTAssertEqual(record.byStore.first?.storeName, "REWE")
        XCTAssertEqual(record.byStore.first?.percentage, 60.0, accuracy: 0.1)
        XCTAssertEqual(record.byStore.last?.percentage,  40.0, accuracy: 0.1)
    }

    func testReceiptsFromOtherMonthExcluded() {
        let household = Household(name: "Test")

        var jan = DateComponents(); jan.year = 2025; jan.month = 1; jan.day = 5
        var feb = DateComponents(); feb.year = 2025; feb.month = 2; feb.day = 5

        let rJan = Receipt(storeName: "Lidl", purchaseDate: Calendar.current.date(from: jan)!, totalAmount: 50)
        let rFeb = Receipt(storeName: "REWE", purchaseDate: Calendar.current.date(from: feb)!, totalAmount: 70)

        let record = ComputeBudgetUseCase.compute(
            for: household, month: 1, year: 2025, receipts: [rJan, rFeb]
        )
        XCTAssertEqual(record.totalSpent, 50.0, accuracy: 0.01)
        XCTAssertEqual(record.receiptCount, 1)
    }

    func testItemCategoryClassifier() {
        XCTAssertEqual(ItemCategory.classify(name: "Milch"),   .dairy)
        XCTAssertEqual(ItemCategory.classify(name: "Äpfel"),   .fruit)
        XCTAssertEqual(ItemCategory.classify(name: "Brot"),    .bakery)
        XCTAssertEqual(ItemCategory.classify(name: "Cola"),    .drinks)
        XCTAssertEqual(ItemCategory.classify(name: "Chips"),   .snacks)
        XCTAssertEqual(ItemCategory.classify(name: "Nudeln"),  .pantryDry)
        XCTAssertEqual(ItemCategory.classify(name: "Spülmittel"), .cleaning)
        XCTAssertEqual(ItemCategory.classify(name: "XYZ123"), .other)
    }

    func testPantryItemStockStatus() {
        let item = PantryItem(name: "Milch", quantity: 1)
        item.lowStockThreshold = 1.0
        XCTAssertTrue(item.isLowStock)

        item.quantity = 2.0
        XCTAssertFalse(item.isLowStock)

        item.expiryDate = Date().addingTimeInterval(-86_400) // yesterday
        XCTAssertTrue(item.isExpired)

        item.expiryDate = Date().addingTimeInterval(2 * 86_400) // 2 days
        XCTAssertTrue(item.isExpiringSoon)
        XCTAssertFalse(item.isExpired)
    }
}
