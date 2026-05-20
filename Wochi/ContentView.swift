import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: Tab = .shopping
    @Environment(\.modelContext) private var context

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
            ShoppingListsView(
                repository: ShoppingListRepository(context: context),
                household: appState.currentHousehold ?? Household.sample()
            )
                .tabItem {
                    Label("tab.shopping", systemImage: "cart")
                }
                .badge(shoppingBadgeCount > 0 ? shoppingBadgeCount : 0)
                .tag(Tab.shopping)

            PantryView(viewModel: PantryViewModel(
                pantryRepository: PantryRepository(context: context),
                shoppingRepository: ShoppingListRepository(context: context),
                household: appState.currentHousehold ?? Household.sample()
            ))
                .tabItem {
                    Label("tab.pantry", systemImage: "house")
                }
                .tag(Tab.pantry)

            BudgetView(viewModel: BudgetViewModel(
                budgetRepository: BudgetRepository(receiptRepository: ReceiptRepository(context: context)),
                receiptRepository: ReceiptRepository(context: context),
                household: appState.currentHousehold ?? Household.sample()
            ))
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
        .task {
            guard appState.currentHousehold == nil else { return }
            let repo = HouseholdRepository(context: context)
            appState.currentHousehold = try? await repo.fetchCurrentHousehold()
        }
        .sheet(isPresented: Binding(
            get: { appState.incomingShareURL != nil },
            set: { if !$0 { appState.incomingShareURL = nil } }
        )) {
            if let url = appState.incomingShareURL {
                ShareAcceptView(shareURL: url)
                    .environmentObject(appState)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .modelContainer(WochiDataContainer.preview)
}
