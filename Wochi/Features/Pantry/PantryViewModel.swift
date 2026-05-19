import SwiftUI
import SwiftData

@MainActor
final class PantryViewModel: ObservableObject {
    enum PantryFilter: String, CaseIterable {
        case all        = "Alle"
        case expiring   = "Ablaufend"
        case lowStock   = "Wenig vorrätig"

        var label: String {
            switch self {
            case .all:      return String(localized: "pantry.filter.all")
            case .expiring: return String(localized: "pantry.filter.expiring")
            case .lowStock: return String(localized: "pantry.filter.low")
            }
        }
    }

    @Published var items: [PantryItem] = []
    @Published var filter: PantryFilter = .all
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var error: WochiError?

    private let pantryRepository: PantryRepositoryProtocol
    private let shoppingRepository: ShoppingListRepositoryProtocol
    private let household: Household

    init(pantryRepository: PantryRepositoryProtocol,
         shoppingRepository: ShoppingListRepositoryProtocol,
         household: Household) {
        self.pantryRepository = pantryRepository
        self.shoppingRepository = shoppingRepository
        self.household = household
    }

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await pantryRepository.fetchAllItems(for: household)
        } catch {
            self.error = .householdNotFound
        }
    }

    func addItem(_ item: PantryItem) async {
        do {
            try await pantryRepository.addItem(item, to: household)
            await loadItems()
            NotificationManager.shared.scheduleExpiryNotification(for: item)
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func updateItem(_ item: PantryItem) async {
        do {
            try await pantryRepository.updateItem(item)
            NotificationManager.shared.scheduleExpiryNotification(for: item)
            if item.isLowStock {
                NotificationManager.shared.scheduleLowStockNotification(for: item)
            }
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func deleteItem(_ item: PantryItem) async {
        do {
            NotificationManager.shared.cancelNotifications(for: item)
            try await pantryRepository.deleteItem(item)
            await loadItems()
        } catch {
            self.error = .cloudKitSyncFailed(underlying: error)
        }
    }

    func markAsUsedUp(_ item: PantryItem, addToList: ShoppingList?) async {
        item.quantity = 0
        await updateItem(item)
        if let list = addToList {
            let shopping = ShoppingItem(name: item.name, quantity: 1, unit: item.unit)
            shopping.sourceType = .pantryAlert
            do {
                try await shoppingRepository.addItem(shopping, to: list)
            } catch {
                self.error = .cloudKitSyncFailed(underlying: error)
            }
        }
    }

    var filteredItems: [PantryItem] {
        var result = items
        switch filter {
        case .all: break
        case .expiring: result = result.filter { $0.isExpiringSoon || $0.isExpired }
        case .lowStock:  result = result.filter { $0.isLowStock }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var groupedItems: [(category: ItemCategory, items: [PantryItem])] {
        let grouped = Dictionary(grouping: filteredItems, by: \.category)
        return ItemCategory.allCases
            .compactMap { cat -> (ItemCategory, [PantryItem])? in
                guard let items = grouped[cat], !items.isEmpty else { return nil }
                return (cat, items.sorted { $0.name < $1.name })
            }
    }
}
