import Foundation

@MainActor
final class CheckOffItemUseCase {
    private let repository: ShoppingListRepositoryProtocol
    private let notificationManager: NotificationManager

    init(repository: ShoppingListRepositoryProtocol, notificationManager: NotificationManager = .shared) {
        self.repository = repository
        self.notificationManager = notificationManager
    }

    func execute(_ item: ShoppingItem, by member: HouseholdMember?) async throws {
        if item.isChecked {
            item.isChecked = false
            item.checkedAt = nil
            item.checkedByMemberID = nil
            try await repository.updateItem(item)
        } else {
            try await repository.checkOffItem(item, by: member)
        }
    }
}
