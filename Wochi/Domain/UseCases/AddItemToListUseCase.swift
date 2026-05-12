import Foundation

@MainActor
final class AddItemToListUseCase {
    private let repository: ShoppingListRepositoryProtocol

    init(repository: ShoppingListRepositoryProtocol) {
        self.repository = repository
    }

    func execute(
        name: String,
        quantity: Double = 1,
        unit: String? = nil,
        list: ShoppingList,
        addedBy member: HouseholdMember? = nil,
        source: ItemSourceType = .manual
    ) async throws -> ShoppingItem {
        let item = ShoppingItem(name: name, quantity: quantity, unit: unit)
        item.addedByMemberID = member?.id
        item.sourceType = source
        try await repository.addItem(item, to: list)
        return item
    }
}
