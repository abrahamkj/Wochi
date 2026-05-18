import AppIntents

struct WochiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddItemToWochiIntent(),
            // itemName is a String parameter (not an AppEntity/AppEnum),
            // so we cannot use the parameter placeholder here. Each
            // utterance MUST include one '.applicationName' token.
            phrases: [
                "Füge etwas zu \(.applicationName) hinzu",
                "Add an item to \(.applicationName)",
                "Füge etwas in \(.applicationName) zur Einkaufsliste hinzu",
                "Füge in \(.applicationName) etwas zur Einkaufsliste hinzu"
            ],
            shortTitle: "Artikel hinzufügen",
            systemImageName: "cart.badge.plus"
        )
    }
}
