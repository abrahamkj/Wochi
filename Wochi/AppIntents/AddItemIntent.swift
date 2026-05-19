import AppIntents
import SwiftData

struct AddItemToWochiIntent: AppIntent {
    static var title: LocalizedStringResource = "Artikel zu Wochi hinzufügen"
    static var description = IntentDescription("Fügt einen Artikel zu deiner Wochi-Einkaufsliste hinzu.")

    @Parameter(title: "Artikel")
    var itemName: String

    @Parameter(title: "Menge", default: 1.0)
    var quantity: Double

    @Parameter(title: "Einheit")
    var unit: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try await WochiDataContainer.create()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ShoppingList>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        guard let list = try context.fetch(descriptor).first else {
            return .result(dialog: "Keine aktive Einkaufsliste gefunden. Bitte öffne Wochi und erstelle eine Liste.")
        }
        let item = ShoppingItem(name: itemName, quantity: quantity, unit: unit)
        item.sourceType = .voice
        item.list = list
        list.items = (list.items ?? []) + [item]
        context.insert(item)
        try context.save()
        let unitText = unit.map { " \($0)" } ?? ""
        return .result(dialog: "\(quantity.formatted())\(unitText) \(itemName) wurde zu deiner Einkaufsliste hinzugefügt.")
    }
}
