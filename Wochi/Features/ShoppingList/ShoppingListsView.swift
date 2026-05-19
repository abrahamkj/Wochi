import SwiftData
import SwiftUI

// MARK: - ShoppingListsView

struct ShoppingListsView: View {

    @StateObject private var viewModel: ShoppingListViewModel
    @State private var isShowingNewListSheet = false
    @State private var newListName = ""

    init(repository: ShoppingListRepositoryProtocol, household: Household) {
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(repository: repository, household: household)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.lists.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.lists.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("shopping.nav.title")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isShowingNewListSheet) {
                newListSheet
            }
            .alert(
                "error.generic",
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.error = nil } }
                )
            ) {
                Button("button.cancel", role: .cancel) {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
            .task {
                await viewModel.loadLists()
            }
        }
    }

    // MARK: Subviews

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.lists) { list in
                    NavigationLink(destination: ShoppingListDetailView(list: list, viewModel: viewModel)) {
                        ShoppingListCard(list: list)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await viewModel.archiveList(list) }
                        } label: {
                            Label("shopping.list.archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteList(list) }
                        } label: {
                            Label("button.delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.loadLists()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: "cart",
            title: "shopping.list.empty.title",
            subtitle: "shopping.list.empty.subtitle",
            actionTitle: "shopping.list.empty.action",
            action: { isShowingNewListSheet = true }
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isShowingNewListSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("shopping.list.new")
        }
    }

    private var newListSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("shopping.list.new.name", text: $newListName)
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("shopping.list.new")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        newListName = ""
                        isShowingNewListSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("shopping.list.new.create") {
                        let name = newListName
                        newListName = ""
                        isShowingNewListSheet = false
                        Task { await viewModel.createList(name: name) }
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - ShoppingListCard

private struct ShoppingListCard: View {

    let list: ShoppingList

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(list.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(
                    Self.relativeFormatter.localizedString(
                        for: list.updatedAt,
                        relativeTo: Date()
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label {
                    Text(verbatim: String(format: String(localized: "shopping.item.count"), list.pendingItems.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }

                if list.totalEstimatedCost > 0 {
                    Label {
                        Text(list.totalEstimatedCost, format: .currency(code: "EUR"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "eurosign.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Previews

#Preview("Lists") {
    ShoppingListsView(
        repository: PreviewShoppingListRepository(),
        household: Household.sample()
    )
    .modelContainer(WochiDataContainer.preview)
}

// MARK: - Preview helpers

private final class PreviewShoppingListRepository: ShoppingListRepositoryProtocol {
    private var store: [ShoppingList] = [.sample()]

    func fetchAllLists(for household: Household) async throws -> [ShoppingList] { store }

    func createList(name: String, in household: Household) async throws -> ShoppingList {
        let list = ShoppingList(name: name)
        store.append(list)
        return list
    }

    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws {
        list.items.append(item)
    }

    func updateItem(_ item: ShoppingItem) async throws {}

    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember?) async throws {
        item.isChecked = true
        item.checkedAt = Date()
    }

    func deleteItem(_ item: ShoppingItem) async throws {
        item.list?.items.removeAll { $0.id == item.id }
    }

    func archiveList(_ list: ShoppingList) async throws {
        list.isArchived = true
    }

    func deleteList(_ list: ShoppingList) async throws {
        store.removeAll { $0.id == list.id }
    }
}
