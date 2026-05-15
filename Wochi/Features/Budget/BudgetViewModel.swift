import SwiftUI
import Foundation

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published var currentRecord: BudgetRecord?
    @Published var previousRecord: BudgetRecord?
    @Published var selectedMonth: Int
    @Published var selectedYear: Int
    @Published var receipts: [Receipt] = []
    @Published var isLoading = false
    @Published var error: WochiError?

    private let budgetRepository: BudgetRepositoryProtocol
    private let receiptRepository: ReceiptRepositoryProtocol
    let household: Household
    let scanUseCase: ScanReceiptUseCase

    init(budgetRepository: BudgetRepositoryProtocol,
         receiptRepository: ReceiptRepositoryProtocol,
         household: Household) {
        self.budgetRepository = budgetRepository
        self.receiptRepository = receiptRepository
        self.household = household
        self.scanUseCase = ScanReceiptUseCase(repository: receiptRepository)
        let now = Calendar.current.dateComponents([.month, .year], from: Date())
        self.selectedMonth = now.month ?? 1
        self.selectedYear = now.year ?? 2025
    }

    var monthOverMonthChange: Double? {
        guard let cur = currentRecord, let prev = previousRecord,
              prev.totalSpent > 0 else { return nil }
        return (cur.totalSpent - prev.totalSpent) / prev.totalSpent * 100
    }

    var displayMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "MMMM yyyy"
        var comps = DateComponents()
        comps.month = selectedMonth
        comps.year = selectedYear
        comps.day = 1
        let date = Calendar.current.date(from: comps) ?? Date()
        return formatter.string(from: date)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let cur = budgetRepository.fetchBudgetRecord(for: household, month: selectedMonth, year: selectedYear)
            async let prevMonth = previousMonthComponents
            currentRecord = try await cur
            let (pm, py) = prevMonth
            previousRecord = try await budgetRepository.fetchBudgetRecord(for: household, month: pm, year: py)
            receipts = try await receiptRepository.fetchReceipts(for: household, month: selectedMonth, year: selectedYear)
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func navigateToPreviousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        Task { await load() }
    }

    func navigateToNextMonth() {
        let now = Calendar.current.dateComponents([.month, .year], from: Date())
        if selectedYear == now.year && selectedMonth == now.month { return }
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        Task { await load() }
    }

    func deleteReceipt(_ receipt: Receipt) async {
        do {
            try await receiptRepository.deleteReceipt(receipt)
            await load()
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    private var previousMonthComponents: (Int, Int) {
        if selectedMonth == 1 { return (12, selectedYear - 1) }
        return (selectedMonth - 1, selectedYear)
    }
}
