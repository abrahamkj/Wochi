import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .shopping

    // Badge count – driven by unchecked items across all active lists.
    @Query(filter: #Predicate<ShoppingItem> { !$0.isChecked })
    private var uncheckedItems: [ShoppingItem]

    private var shoppingBadgeCount: Int {
        uncheckedItems.count
    }

    enum Tab {
        case shopping, pantry, budget, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ShoppingListsView()
                .tabItem {
                    Label("tab.shopping", systemImage: "cart")
                }
                .badge(shoppingBadgeCount > 0 ? shoppingBadgeCount : 0)
                .tag(Tab.shopping)

            PantryView()
                .tabItem {
                    Label("tab.pantry", systemImage: "house")
                }
                .tag(Tab.pantry)

            BudgetView()
                .tabItem {
                    Label("tab.budget", systemImage: "chart.bar")
                }
                .tag(Tab.budget)

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(WochiDataContainer.preview)
}
