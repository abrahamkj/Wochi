import Foundation
import SwiftData

protocol ShoppingListRepositoryProtocol {
    func fetchAllLists(for household: Household) async throws -> [ShoppingList]
    func createList(name: String, in household: Household) async throws -> ShoppingList
    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws
    func updateItem(_ item: ShoppingItem) async throws
    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember?) async throws
    func deleteItem(_ item: ShoppingItem) async throws
    func archiveList(_ list: ShoppingList) async throws
    func deleteList(_ list: ShoppingList) async throws
}

@MainActor
final class ShoppingListRepository: ShoppingListRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAllLists(for household: Household) async throws -> [ShoppingList] {
        let householdID = household.id
        let descriptor = FetchDescriptor<ShoppingList>(
            predicate: #Predicate { $0.household?.id == householdID && !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func createList(name: String, in household: Household) async throws -> ShoppingList {
        let list = ShoppingList(name: name)
        list.household = household
        context.insert(list)
        try context.save()
        return list
    }

    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws {
        item.list = list
        item.sortOrder = list.items.count
        list.items.append(item)
        list.updatedAt = Date()
        context.insert(item)
        try context.save()
    }

    func updateItem(_ item: ShoppingItem) async throws {
        item.list?.updatedAt = Date()
        try context.save()
    }

    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember?) async throws {
        item.isChecked = true
        item.checkedAt = Date()
        item.checkedByMemberID = member?.id
        item.list?.updatedAt = Date()
        try context.save()
    }

    func deleteItem(_ item: ShoppingItem) async throws {
        item.list?.updatedAt = Date()
        context.delete(item)
        try context.save()
    }

    func archiveList(_ list: ShoppingList) async throws {
        list.isArchived = true
        list.updatedAt = Date()
        try context.save()
    }

    func deleteList(_ list: ShoppingList) async throws {
        context.delete(list)
        try context.save()
    }
}
