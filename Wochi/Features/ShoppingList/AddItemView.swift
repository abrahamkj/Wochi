import SwiftUI

// MARK: - AddItemView

struct AddItemView: View {

    let list: ShoppingList
    @ObservedObject var viewModel: ShoppingListViewModel

    @Environment(\.dismiss) private var dismiss

    // MARK: Form state

    @State private var name = ""
    @State private var quantity: Double = 1
    @State private var selectedUnit = "Stück"
    @State private var brand = ""
    @State private var note = ""
    @State private var showSuggestions = false

    // MARK: Constants

    private let units = ["Stück", "kg", "g", "Liter", "ml", "Packung", "Flasche", "Dose"]

    private let suggestions = [
        "Milch", "Brot", "Eier", "Butter", "Käse", "Joghurt",
        "Äpfel", "Bananen", "Tomaten", "Nudeln", "Reis", "Kaffee",
        "Tee", "Zucker", "Salz", "Mehl", "Öl", "Zwiebeln",
        "Knoblauch", "Kartoffeln"
    ]

    private var filteredSuggestions: [String] {
        guard !name.isEmpty else { return [] }
        return suggestions.filter {
            $0.localizedCaseInsensitiveContains(name) && $0.localizedCaseInsensitiveCompare(name) != .orderedSame
        }
    }

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                quantitySection
                optionalSection
            }
            .navigationTitle("shopping.item.add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var nameSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                TextField("shopping.item.edit.name", text: $name)
                    .autocorrectionDisabled(false)
                    .onChange(of: name) { _, newValue in
                        showSuggestions = !newValue.isEmpty && !filteredSuggestions.isEmpty
                    }

                if showSuggestions {
                    Divider().padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredSuggestions, id: \.self) { suggestion in
                                Button {
                                    name = suggestion
                                    showSuggestions = false
                                } label: {
                                    Text(suggestion)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        } header: {
            Text("shopping.item.edit.name")
        }
    }

    private var quantitySection: some View {
        Section {
            Stepper(
                value: $quantity,
                in: 0.5...99,
                step: 0.5
            ) {
                HStack {
                    Text("shopping.item.edit.quantity")
                    Spacer()
                    Text(quantity.formatted())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Picker("shopping.item.edit.unit", selection: $selectedUnit) {
                ForEach(units, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
            }
        } header: {
            Text("shopping.item.edit.quantity")
        }
    }

    private var optionalSection: some View {
        Section {
            TextField("shopping.item.edit.brand", text: $brand)
            TextField("shopping.item.edit.note", text: $note, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("shopping.item.edit.brand.section")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("button.cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Menu {
                Button("button.add.more") {
                    addItem()
                    resetForm()
                }
                .disabled(!isNameValid)

                Button("button.add") {
                    addItem()
                    dismiss()
                }
                .disabled(!isNameValid)
            } label: {
                Text("button.add")
                    .fontWeight(.semibold)
            }
            .disabled(!isNameValid)
        }
    }

    // MARK: Helpers

    private func addItem() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let unit: String? = selectedUnit == "Stück" ? nil : selectedUnit
        Task {
            await viewModel.addItem(
                name: trimmedName,
                quantity: quantity,
                unit: unit,
                to: list
            )
        }
    }

    private func resetForm() {
        name = ""
        quantity = 1
        selectedUnit = "Stück"
        brand = ""
        note = ""
        showSuggestions = false
    }
}

// MARK: - Preview

#Preview {
    AddItemView(
        list: ShoppingList.sample(),
        viewModel: ShoppingListViewModel(
            repository: PreviewShoppingListRepository(),
            household: Household.sample()
        )
    )
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
