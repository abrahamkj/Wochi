import Foundation
import SwiftData

protocol PantryRepositoryProtocol {
    func fetchAllItems(for household: Household) async throws -> [PantryItem]
    func addItem(_ item: PantryItem, to household: Household) async throws
    func updateItem(_ item: PantryItem) async throws
    func deleteItem(_ item: PantryItem) async throws
    func fetchExpiringItems(within days: Int, for household: Household) async throws -> [PantryItem]
    func fetchLowStockItems(for household: Household) async throws -> [PantryItem]
}

@MainActor
final class PantryRepository: PantryRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAllItems(for household: Household) async throws -> [PantryItem] {
        let householdID = household.id
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate { $0.household?.id == householdID },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func addItem(_ item: PantryItem, to household: Household) async throws {
        item.household = household
        household.pantryItems.append(item)
        context.insert(item)
        try context.save()
    }

    func updateItem(_ item: PantryItem) async throws {
        item.lastUpdatedAt = Date()
        try context.save()
    }

    func deleteItem(_ item: PantryItem) async throws {
        context.delete(item)
        try context.save()
    }

    func fetchExpiringItems(within days: Int, for household: Household) async throws -> [PantryItem] {
        let all = try await fetchAllItems(for: household)
        let cutoff = Date().addingTimeInterval(Double(days) * 24 * 60 * 60)
        return all.filter { item in
            guard let expiry = item.expiryDate else { return false }
            return expiry <= cutoff
        }
    }

    func fetchLowStockItems(for household: Household) async throws -> [PantryItem] {
        let all = try await fetchAllItems(for: household)
        return all.filter { $0.isLowStock }
    }
}
