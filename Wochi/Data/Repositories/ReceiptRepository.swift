import Foundation
import SwiftData

protocol ReceiptRepositoryProtocol {
    func saveReceipt(_ receipt: Receipt, for household: Household) async throws
    func fetchReceipts(for household: Household, month: Int, year: Int) async throws -> [Receipt]
    func fetchAllReceipts(for household: Household) async throws -> [Receipt]
    func deleteReceipt(_ receipt: Receipt) async throws
}

@MainActor
final class ReceiptRepository: ReceiptRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveReceipt(_ receipt: Receipt, for household: Household) async throws {
        receipt.household = household
        household.receipts.append(receipt)
        context.insert(receipt)
        try context.save()
    }

    func fetchReceipts(for household: Household, month: Int, year: Int) async throws -> [Receipt] {
        let all = try await fetchAllReceipts(for: household)
        return all.filter { $0.month == month && $0.year == year }
    }

    func fetchAllReceipts(for household: Household) async throws -> [Receipt] {
        let householdID = household.id
        let descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.household?.id == householdID },
            sortBy: [SortDescriptor(\.purchaseDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func deleteReceipt(_ receipt: Receipt) async throws {
        context.delete(receipt)
        try context.save()
    }
}
