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
            LocalizedStringKey("Alle erledigten Artikel löschen?"),
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("Löschen"), role: .destructive) {
                Task { await viewModel.clearCheckedItems(from: list) }
            }
            Button(LocalizedStringKey("Abbrechen"), role: .cancel) {}
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
                    Text(LocalizedStringKey(group.category.rawValue))
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
            Text(LocalizedStringKey("Erledigt (\(list.checkedItems.count))"))
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
                Label(LocalizedStringKey("Löschen"), systemImage: "trash")
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
                LocalizedStringKey("Alle erledigten löschen"),
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
            Text(LocalizedStringKey("Offline – Änderungen werden synchronisiert, sobald du wieder online bist."))
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
            .accessibilityLabel(LocalizedStringKey("Gruppierung umschalten"))
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isShowingAddItem = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(LocalizedStringKey("Artikel hinzufügen"))
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

                // Member avatar
                if let memberID = item.addedByMemberID {
                    MemberAvatarView(memberID: memberID)
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

// MARK: - MemberAvatarView

private struct MemberAvatarView: View {

    let memberID: UUID

    // Deterministic color from the UUID so the avatar is stable.
    private var color: Color {
        let colors: [Color] = [.green, .blue, .red, .orange, .purple, .teal]
        let index = abs(memberID.hashValue) % colors.count
        return colors[index]
    }

    private var initials: String {
        // We only have the UUID here; show a generic icon.
        "?"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
            Text(initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
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
    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws { list.items.append(item) }
    func updateItem(_ item: ShoppingItem) async throws {}
    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember?) async throws {
        item.isChecked = true; item.checkedAt = Date()
    }
    func deleteItem(_ item: ShoppingItem) async throws {
        item.list?.items.removeAll { $0.id == item.id }
    }
    func archiveList(_ list: ShoppingList) async throws { list.isArchived = true }
    func deleteList(_ list: ShoppingList) async throws {}
}
