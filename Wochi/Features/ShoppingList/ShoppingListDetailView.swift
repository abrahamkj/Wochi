import SwiftUI

// MARK: - ShoppingListDetailView

struct ShoppingListDetailView: View {

    let list: ShoppingList
    @ObservedObject var viewModel: ShoppingListViewModel

    @State private var isShowingAddItem = false
    @State private var itemToEdit: ShoppingItem?
    @State private var checkedSectionExpanded = false
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Pending items
                if viewModel.groupByCategory {
                    groupedPendingSection
                } else {
                    flatPendingSection
                }

                // Checked items (collapsible)
                if !list.checkedItems.isEmpty {
                    checkedSection
                }

                // Clear checked button
                if !list.checkedItems.isEmpty {
                    clearCheckedButton
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .top) {
            if CloudKitManager.shared.syncStatus == .offline {
                offlineBanner
            }
        }
        .sheet(isPresented: $isShowingAddItem) {
            AddItemView(list: list, viewModel: viewModel)
        }
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item, viewModel: viewModel)
        }
        .confirmationDialog(
            "shopping.item.delete.confirm",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("button.delete", role: .destructive) {
                Task { await viewModel.clearCheckedItems(from: list) }
            }
            Button("button.cancel", role: .cancel) {}
        }
    }

    // MARK: Pending – flat

    private var flatPendingSection: some View {
        ForEach(list.pendingItems) { item in
            itemRow(item)
                .padding(.horizontal)
        }
    }

    // MARK: Pending – grouped by category

    private var groupedPendingSection: some View {
        ForEach(viewModel.groupedItems(for: list), id: \.category) { group in
            Section {
                ForEach(group.items) { item in
                    itemRow(item)
                        .padding(.horizontal)
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: group.category.sfSymbol)
                    Text(group.category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: Checked section

    private var checkedSection: some View {
        DisclosureGroup(
            isExpanded: $checkedSectionExpanded
        ) {
            ForEach(list.checkedItems) { item in
                itemRow(item)
                    .padding(.horizontal)
            }
        } label: {
            Text(verbatim: String(format: String(localized: "shopping.detail.checked.section"), list.checkedItems.count))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 4)
        }
        .padding(.horizontal)
    }

    // MARK: Item row

    @ViewBuilder
    private func itemRow(_ item: ShoppingItem) -> some View {
        ShoppingItemRow(item: item) {
            Task {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                await viewModel.checkOff(item)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deleteItem(item) }
            } label: {
                Label("button.delete", systemImage: "trash")
            }
        }
        .onLongPressGesture {
            itemToEdit = item
        }
    }

    // MARK: Clear checked button

    private var clearCheckedButton: some View {
        Button {
            showClearConfirmation = true
        } label: {
            Label(
                "shopping.checked.clear",
                systemImage: "trash"
            )
            .foregroundStyle(.red)
            .font(.subheadline)
        }
    }

    // MARK: Offline banner

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("shopping.detail.offline")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.orange)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                withAnimation {
                    viewModel.groupByCategory.toggle()
                }
            } label: {
                Image(systemName: viewModel.groupByCategory ? "list.bullet.indent" : "list.bullet")
            }
            .accessibilityLabel("shopping.detail.share")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isShowingAddItem = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("shopping.item.add")
        }
    }
}

// MARK: - ShoppingItemRow

private struct ShoppingItemRow: View {

    let item: ShoppingItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category icon
                Image(systemName: item.category.sfSymbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                // Name + quantity
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: item.isChecked)

                    if let unit = item.unit {
                        Text("\(item.quantity.formatted()) \(unit)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if item.quantity != 1 {
                        Text(item.quantity.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Estimated price
                if let price = item.estimatedPrice {
                    Text(price, format: .currency(code: "EUR"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Member avatar (generic icon — full member lookup needs household context)
                if item.addedByMemberID != nil {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 18))
                }

                // Check indicator
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .animation(.spring(duration: 0.25), value: item.isChecked)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider()
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        ShoppingListDetailView(
            list: ShoppingList.sample(),
            viewModel: ShoppingListViewModel(
                repository: PreviewShoppingListRepository(),
                household: Household.sample()
            )
        )
    }
    .modelContainer(WochiDataContainer.preview)
}

// MARK: - Preview helpers

private final class PreviewShoppingListRepository: ShoppingListRepositoryProtocol {
    func fetchAllLists(for household: Household) async throws -> [ShoppingList] { [] }
    func createList(name: String, in household: Household) async throws -> ShoppingList { ShoppingList(name: name) }
    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws { list.items = (list.items ?? []) + [item] }
    func updateItem(_ item: ShoppingItem) async throws {}
    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember?) async throws {
        item.isChecked = true; item.checkedAt = Date()
    }
    func deleteItem(_ item: ShoppingItem) async throws {
        item.list?.items = item.list?.items?.filter { $0.id != item.id }
    }
    func archiveList(_ list: ShoppingList) async throws { list.isArchived = true }
    func deleteList(_ list: ShoppingList) async throws {}
}
