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
