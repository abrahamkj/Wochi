import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .shopping

    @Query(filter: #Predicate<ShoppingItem> { !$0.isChecked })
    private var uncheckedItems: [ShoppingItem]

    private var shoppingBadgeCount: Int { uncheckedItems.count }

    enum Tab {
        case shopping, pantry, budget, settings
    }

    var body: some View {
        if let household = appState.currentHousehold {
            let shoppingRepo = ShoppingListRepository(context: modelContext)
            let pantryRepo = PantryRepository(context: modelContext)
            let receiptRepo = ReceiptRepository(context: modelContext)
            let budgetRepo = BudgetRepository(receiptRepository: receiptRepo)

            TabView(selection: $selectedTab) {
                ShoppingListsView(repository: shoppingRepo, household: household)
                    .tabItem { Label("tab.shopping", systemImage: "cart") }
                    .badge(shoppingBadgeCount > 0 ? shoppingBadgeCount : 0)
                    .tag(Tab.shopping)

                PantryView(viewModel: PantryViewModel(repository: pantryRepo, household: household))
                    .tabItem { Label("tab.pantry", systemImage: "house") }
                    .tag(Tab.pantry)

                BudgetView(viewModel: BudgetViewModel(
                    budgetRepository: budgetRepo,
                    receiptRepository: receiptRepo,
                    household: household
                ))
                .tabItem { Label("tab.budget", systemImage: "chart.bar") }
                .tag(Tab.budget)

                SettingsView()
                    .tabItem { Label("tab.settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(WochiDataContainer.preview)
}
