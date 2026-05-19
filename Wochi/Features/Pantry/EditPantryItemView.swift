import SwiftUI

struct EditPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel
    let item: PantryItem

    @State private var name: String
    @State private var quantity: Double
    @State private var unit: String
    @State private var category: ItemCategory
    @State private var brand: String
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var lowStockThreshold: Double
    @State private var notes: String
    @State private var showDeleteConfirmation = false
    @State private var showUsedUpSheet = false

    private let units = ["Stück", "kg", "g", "Liter", "ml", "Packung", "Flasche", "Dose", "Glas"]

    private func unitDisplayName(_ unit: String) -> String {
        let map: [String: String] = [
            "Stück":   String(localized: "unit.piece"),
            "kg":      String(localized: "unit.kg"),
            "g":       String(localized: "unit.g"),
            "Liter":   String(localized: "unit.liter"),
            "ml":      String(localized: "unit.ml"),
            "Packung": String(localized: "unit.pack"),
            "Flasche": String(localized: "unit.bottle"),
            "Dose":    String(localized: "unit.can"),
            "Glas":    String(localized: "unit.jar"),
        ]
        return map[unit] ?? unit
    }

    init(item: PantryItem, viewModel: PantryViewModel) {
        self.item = item
        self.viewModel = viewModel
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit ?? "")
        _category = State(initialValue: item.category)
        _brand = State(initialValue: item.brand ?? "")
        _hasExpiry = State(initialValue: item.expiryDate != nil)
        _expiryDate = State(initialValue: item.expiryDate ?? Date().addingTimeInterval(7 * 86_400))
        _lowStockThreshold = State(initialValue: item.lowStockThreshold)
        _notes = State(initialValue: item.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("pantry.item.section.article") {
                    TextField("pantry.item.edit.name", text: $name)
                    HStack {
                        Text("pantry.item.edit.quantity")
                        Spacer()
                        Stepper("\(quantity.formatted(.number.precision(.fractionLength(0...1))))", value: $quantity, in: 0...999, step: 1)
                    }
                    Picker("pantry.item.edit.unit", selection: $unit) {
                        Text("–").tag("")
                        ForEach(units, id: \.self) { u in
                            Text(unitDisplayName(u)).tag(u)
                        }
                    }
                    Picker("pantry.item.edit.category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.sfSymbol).tag(cat)
                        }
                    }
                }

                Section("pantry.item.section.details") {
                    TextField("pantry.item.edit.brand", text: $brand)
                    Toggle("pantry.item.edit.expiry.toggle", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("pantry.item.edit.expiry.date", selection: $expiryDate, displayedComponents: .date)
                    }
                    HStack {
                        Text("pantry.item.edit.min_stock")
                        Spacer()
                        Stepper("\(lowStockThreshold.formatted(.number.precision(.fractionLength(0...1))))",
                                value: $lowStockThreshold, in: 0...99, step: 1)
                    }
                    TextField("pantry.item.edit.notes", text: $notes)
                }

                Section {
                    Button(role: .destructive) { showUsedUpSheet = true } label: {
                        Label("pantry.item.used_up.button", systemImage: "trash.slash")
                    }
                }

                Section {
                    Text(verbatim: String(format: String(localized: "pantry.item.edit.last_updated"), item.lastUpdatedAt.germanDateString))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("button.delete", role: .destructive) { showDeleteConfirmation = true }
                }
            }
            .navigationTitle("pantry.item.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("pantry.item.delete.confirm", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("button.delete", role: .destructive) {
                    Task { await viewModel.deleteItem(item) }
                    dismiss()
                }
                Button("button.cancel", role: .cancel) {}
            }
            .confirmationDialog("pantry.item.used_up.confirm", isPresented: $showUsedUpSheet, titleVisibility: .visible) {
                Button("pantry.item.used_up.add_to_list") {
                    Task { await viewModel.markAsUsedUp(item, addToList: nil) }
                    dismiss()
                }
                Button("pantry.item.used_up.mark_only") {
                    Task { await viewModel.markAsUsedUp(item, addToList: nil) }
                    dismiss()
                }
                Button("button.cancel", role: .cancel) {}
            }
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity
        item.unit = unit.isEmpty ? nil : unit
        item.category = category
        item.brand = brand.isEmpty ? nil : brand
        item.expiryDate = hasExpiry ? expiryDate : nil
        item.lowStockThreshold = lowStockThreshold
        item.notes = notes.isEmpty ? nil : notes
        Task { await viewModel.updateItem(item) }
        dismiss()
    }
}

#Preview {
    EditPantryItemView(
        item: PantryItem.sample(),
        viewModel: PantryViewModel(
            pantryRepository: PantryRepository(context: WochiDataContainer.preview.mainContext),
            shoppingRepository: ShoppingListRepository(context: WochiDataContainer.preview.mainContext),
            household: Household.sample()
        )
    )
}
