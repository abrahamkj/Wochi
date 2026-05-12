import SwiftUI

struct PantryView: View {
    @StateObject private var viewModel: PantryViewModel
    @State private var showAddItem = false
    @State private var selectedItem: PantryItem?

    init(viewModel: PantryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredItems.isEmpty && viewModel.searchText.isEmpty && viewModel.filter == .all {
                    EmptyStateView(
                        symbol: "cabinet",
                        title: "pantry.empty.title",
                        subtitle: "pantry.empty.subtitle",
                        actionTitle: "Ersten Artikel hinzufügen"
                    ) {
                        showAddItem = true
                    }
                } else {
                    pantryList
                }
            }
            .navigationTitle(LocalizedStringKey("tab.pantry"))
            .searchable(text: $viewModel.searchText, prompt: "Artikel suchen")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddItem = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddPantryItemView(viewModel: viewModel)
            }
            .sheet(item: $selectedItem) { item in
                EditPantryItemView(item: item, viewModel: viewModel)
            }
            .task { await viewModel.loadItems() }
            .alert("Fehler", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PantryViewModel.PantryFilter.allCases, id: \.self) { f in
                    Button {
                        viewModel.filter = f
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.filter == f ? Color.accentColor : Color(.systemGray5))
                            .foregroundStyle(viewModel.filter == f ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var pantryList: some View {
        List {
            filterChips
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            ForEach(viewModel.groupedItems, id: \.category) { group in
                Section(group.category.rawValue) {
                    ForEach(group.items) { item in
                        PantryItemRow(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await viewModel.loadItems() }
    }
}

private struct PantryItemRow: View {
    let item: PantryItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                if let brand = item.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(quantityText)
                    .font(.subheadline)
                    .monospacedDigit()
                if let days = item.daysUntilExpiry {
                    Text(expiryText(days: days))
                        .font(.caption)
                        .foregroundStyle(expiryColor(days: days))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var quantityText: String {
        if let unit = item.unit {
            return "\(item.quantity.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
        }
        return item.quantity.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func expiryText(days: Int) -> String {
        if days < 0 { return "Abgelaufen" }
        if days == 0 { return "Heute" }
        return "noch \(days)d"
    }

    private func expiryColor(days: Int) -> Color {
        if days < 0 { return .red }
        if days <= 3 { return .orange }
        return .secondary
    }

    private var statusColor: Color {
        switch item.stockStatus {
        case .ok:          return .green
        case .lowStock:    return .yellow
        case .expiringSoon: return .orange
        case .expired:     return .red
        }
    }
}

#Preview {
    PantryView(viewModel: PantryViewModel(
        pantryRepository: PantryRepository(context: WochiDataContainer.preview.mainContext),
        shoppingRepository: ShoppingListRepository(context: WochiDataContainer.preview.mainContext),
        household: Household.sample()
    ))
    .modelContainer(WochiDataContainer.preview)
}
