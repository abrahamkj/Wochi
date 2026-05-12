import Foundation

// MARK: - ShoppingListViewModel

@MainActor
final class ShoppingListViewModel: ObservableObject {

    // MARK: Published

    @Published var lists: [ShoppingList] = []
    @Published var isLoading = false
    @Published var error: WochiError?
    @Published var groupByCategory = false

    // MARK: Private

    private let repository: ShoppingListRepositoryProtocol
    private let household: Household

    // MARK: Init

    init(repository: ShoppingListRepositoryProtocol, household: Household) {
        self.repository = repository
        self.household = household
    }

    // MARK: List operations

    func loadLists() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await repository.fetchAllLists(for: household)
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func createList(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let newList = try await repository.createList(name: trimmed, in: household)
            lists.insert(newList, at: 0)
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func archiveList(_ list: ShoppingList) async {
        do {
            try await repository.archiveList(list)
            lists.removeAll { $0.id == list.id }
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func deleteList(_ list: ShoppingList) async {
        do {
            try await repository.deleteList(list)
            lists.removeAll { $0.id == list.id }
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    // MARK: Item operations

    func addItem(
        name: String,
        quantity: Double,
        unit: String?,
        to list: ShoppingList
    ) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let item = ShoppingItem(name: trimmed, quantity: quantity, unit: unit)
        do {
            try await repository.addItem(item, to: list)
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func checkOff(_ item: ShoppingItem) async {
        do {
            if item.isChecked {
                item.isChecked = false
                item.checkedAt = nil
                item.checkedByMemberID = nil
                try await repository.updateItem(item)
            } else {
                try await repository.checkOffItem(item, by: nil)
            }
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func deleteItem(_ item: ShoppingItem) async {
        do {
            try await repository.deleteItem(item)
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func clearCheckedItems(from list: ShoppingList) async {
        let checked = list.checkedItems
        for item in checked {
            await deleteItem(item)
        }
    }

    func updateItem(_ item: ShoppingItem) async {
        do {
            try await repository.updateItem(item)
        } catch let wochiError as WochiError {
            error = wochiError
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    // MARK: Grouping

    /// Groups the pending items of a list by `ItemCategory`, preserving category declaration order.
    func groupedItems(for list: ShoppingList) -> [(category: ItemCategory, items: [ShoppingItem])] {
        let pending = list.pendingItems
        var buckets: [ItemCategory: [ShoppingItem]] = [:]
        for item in pending {
            buckets[item.category, default: []].append(item)
        }
        // Return in the canonical order defined by `ItemCategory.allCases`.
        return ItemCategory.allCases.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }
}
