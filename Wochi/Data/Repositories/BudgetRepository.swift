import Foundation

protocol BudgetRepositoryProtocol {
    func fetchBudgetRecord(for household: Household, month: Int, year: Int) async throws -> BudgetRecord
    func fetchBudgetHistory(for household: Household, months: Int) async throws -> [BudgetRecord]
}

@MainActor
final class BudgetRepository: BudgetRepositoryProtocol {
    private let receiptRepository: ReceiptRepositoryProtocol

    init(receiptRepository: ReceiptRepositoryProtocol) {
        self.receiptRepository = receiptRepository
    }

    func fetchBudgetRecord(for household: Household, month: Int, year: Int) async throws -> BudgetRecord {
        let receipts = try await receiptRepository.fetchAllReceipts(for: household)
        return ComputeBudgetUseCase.compute(for: household, month: month, year: year, receipts: receipts)
    }

    func fetchBudgetHistory(for household: Household, months: Int) async throws -> [BudgetRecord] {
        let receipts = try await receiptRepository.fetchAllReceipts(for: household)
        var records: [BudgetRecord] = []
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())

        for _ in 0..<months {
            let month = components.month!
            let year = components.year!
            records.append(ComputeBudgetUseCase.compute(for: household, month: month, year: year, receipts: receipts))
            if components.month == 1 {
                components.month = 12
                components.year = (components.year ?? 2024) - 1
            } else {
                components.month = (components.month ?? 2) - 1
            }
        }
        return records
    }
}
