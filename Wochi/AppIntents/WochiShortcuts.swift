import AppIntents

struct WochiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddItemToWochiIntent(),
            phrases: [
                "Füge \(\.$itemName) zu Wochi hinzu",
                "Add \(\.$itemName) to Wochi",
                "Wochi \(\.$itemName) hinzufügen",
                "Füge \(\.$itemName) zur Einkaufsliste hinzu in \(.applicationName)"
            ],
            shortTitle: "Artikel hinzufügen",
            systemImageName: "cart.badge.plus"
        )
    }
}
