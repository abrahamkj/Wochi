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
                Section("Artikel") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Menge")
                        Spacer()
                        Stepper("\(quantity.formatted(.number.precision(.fractionLength(0...1))))", value: $quantity, in: 0...999, step: 1)
                    }
                    Picker("Einheit", selection: $unit) {
                        Text("–").tag("")
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Kategorie", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.sfSymbol).tag(cat)
                        }
                    }
                }

                Section("Details") {
                    TextField("Marke (optional)", text: $brand)
                    Toggle("Ablaufdatum", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Datum", selection: $expiryDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "de_DE"))
                    }
                    HStack {
                        Text("Mindestbestand")
                        Spacer()
                        Stepper("\(lowStockThreshold.formatted(.number.precision(.fractionLength(0...1))))",
                                value: $lowStockThreshold, in: 0...99, step: 1)
                    }
                    TextField("Notiz", text: $notes)
                }

                Section {
                    Button(role: .destructive) { showUsedUpSheet = true } label: {
                        Label("Aufgebraucht", systemImage: "trash.slash")
                    }
                }

                Section {
                    Text("Zuletzt geändert: \(item.lastUpdatedAt.germanDateString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Löschen", role: .destructive) { showDeleteConfirmation = true }
                }
            }
            .navigationTitle("Artikel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Artikel löschen?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    Task { await viewModel.deleteItem(item) }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .confirmationDialog("Aufgebraucht — zur Liste hinzufügen?", isPresented: $showUsedUpSheet, titleVisibility: .visible) {
                Button("Zur Einkaufsliste hinzufügen") {
                    Task { await viewModel.markAsUsedUp(item, addToList: nil) }
                    dismiss()
                }
                Button("Nur als aufgebraucht markieren") {
                    Task { await viewModel.markAsUsedUp(item, addToList: nil) }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
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
