import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ShoppingListViewModel

    let item: ShoppingItem

    @State private var name: String
    @State private var quantity: Double
    @State private var unit: String
    @State private var brand: String
    @State private var brandTier: BrandPreference
    @State private var category: ItemCategory
    @State private var note: String
    @State private var estimatedPrice: String
    @State private var showDeleteConfirmation = false

    private let units = ["Stück", "kg", "g", "Liter", "ml", "Packung", "Flasche", "Dose"]

    init(item: ShoppingItem, viewModel: ShoppingListViewModel) {
        self.item = item
        self.viewModel = viewModel
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _unit = State(initialValue: item.unit ?? "")
        _brand = State(initialValue: item.preferredBrand ?? "")
        _brandTier = State(initialValue: item.brandTier)
        _category = State(initialValue: item.category)
        _note = State(initialValue: item.note ?? "")
        _estimatedPrice = State(initialValue: item.estimatedPrice.map { String($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Artikel") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Menge")
                        Spacer()
                        Stepper("\(quantity.formatted(.number.precision(.fractionLength(0...1))))",
                                value: $quantity, in: 0.5...99, step: 0.5)
                    }
                    Picker("Einheit", selection: $unit) {
                        Text("–").tag("")
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Marke") {
                    TextField("Marke (optional)", text: $brand)
                    Picker("Markenpräferenz", selection: $brandTier) {
                        Label("⭐ Bevorzugt", systemImage: "star.fill").tag(BrandPreference.preferred)
                        Label("✓ Akzeptabel", systemImage: "checkmark").tag(BrandPreference.acceptable)
                        Label("✗ Nie", systemImage: "xmark").tag(BrandPreference.never)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Kategorie & Details") {
                    Picker("Kategorie", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.sfSymbol).tag(cat)
                        }
                    }
                    TextField("Notiz", text: $note)
                    TextField("Geschätzter Preis (€)", text: $estimatedPrice)
                        .keyboardType(.decimalPad)
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
        }
    }

    private func save() {
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.quantity = quantity
        item.unit = unit.isEmpty ? nil : unit
        item.preferredBrand = brand.isEmpty ? nil : brand
        item.brandTier = brandTier
        item.category = category
        item.note = note.isEmpty ? nil : note
        item.estimatedPrice = Double(estimatedPrice.replacingOccurrences(of: ",", with: "."))
        Task { await viewModel.updateItem(item) }
        dismiss()
    }
}

#Preview {
    let item = ShoppingItem(name: "Milch", quantity: 2, unit: "Liter")
    return EditItemView(
        item: item,
        viewModel: ShoppingListViewModel(
            repository: ShoppingListRepository(context: WochiDataContainer.preview.mainContext),
            household: Household.sample()
        )
    )
}
