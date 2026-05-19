import Foundation

enum ComputeBudgetUseCase {
    static func compute(for household: Household, month: Int, year: Int, receipts: [Receipt]) -> BudgetRecord {
        let filtered = receipts.filter { $0.month == month && $0.year == year }
        let total = filtered.reduce(0) { $0 + $1.totalAmount }

        let byStore: [BudgetRecord.StoreSpend]
        let byCategory: [BudgetRecord.CategorySpend]
        let byMember: [BudgetRecord.MemberSpend]

        if total > 0 {
            byStore = Dictionary(grouping: filtered, by: \.storeName)
                .map { storeName, storeReceipts in
                    let amount = storeReceipts.reduce(0) { $0 + $1.totalAmount }
                    return BudgetRecord.StoreSpend(
                        storeName: storeName,
                        amount: amount,
                        percentage: amount / total * 100,
                        receiptCount: storeReceipts.count
                    )
                }
                .sorted { $0.amount > $1.amount }

            let allItems = filtered.flatMap { $0.items ?? [] }
            byCategory = Dictionary(grouping: allItems, by: \.category)
                .map { category, items in
                    let amount = items.reduce(0) { $0 + $1.totalPrice }
                    return BudgetRecord.CategorySpend(
                        category: category,
                        amount: amount,
                        percentage: amount / total * 100
                    )
                }
                .sorted { $0.amount > $1.amount }

            byMember = Dictionary(grouping: filtered, by: \.scannedByMemberID)
                .compactMap { memberID, memberReceipts -> BudgetRecord.MemberSpend? in
                    guard let memberID else { return nil }
                    let member = (household.members ?? []).first { $0.id == memberID }
                    let amount = memberReceipts.reduce(0) { $0 + $1.totalAmount }
                    return BudgetRecord.MemberSpend(
                        memberID: memberID,
                        memberName: member?.displayName ?? "Unbekannt",
                        amount: amount,
                        receiptCount: memberReceipts.count
                    )
                }
                .sorted { $0.amount > $1.amount }
        } else {
            byStore = []
            byCategory = []
            byMember = []
        }

        return BudgetRecord(
            month: month,
            year: year,
            householdID: household.id,
            totalSpent: total,
            currency: household.currency,
            byStore: byStore,
            byCategory: byCategory,
            byMember: byMember,
            receiptCount: filtered.count
        )
    }
}
