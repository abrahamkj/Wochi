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

// MARK: - Placeholder feature views (stubs until feature files are created)

struct ShoppingListsView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                symbol: "cart",
                title: "shopping.empty.title",
                subtitle: "shopping.empty.subtitle"
            )
            .navigationTitle(LocalizedStringKey("tab.shopping"))
        }
    }
}

struct PantryView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                symbol: "house",
                title: "pantry.empty.title",
                subtitle: "pantry.empty.subtitle"
            )
            .navigationTitle(LocalizedStringKey("tab.pantry"))
        }
    }
}

struct BudgetView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                symbol: "chart.bar",
                title: "budget.empty.title",
                subtitle: "budget.empty.subtitle"
            )
            .navigationTitle(LocalizedStringKey("tab.budget"))
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("settings.household", systemImage: "house.fill")
                Label("settings.notifications", systemImage: "bell")
                Label("settings.icloud", systemImage: "icloud")
                Label("settings.siri", systemImage: "mic")
                Label("settings.about", systemImage: "info.circle")
            }
            .navigationTitle(LocalizedStringKey("tab.settings"))
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(WochiDataContainer.preview)
}
