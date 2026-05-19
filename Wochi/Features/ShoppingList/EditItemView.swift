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
                Section("shopping.item.edit.title") {
                    TextField("shopping.item.edit.name", text: $name)
                    HStack {
                        Text("shopping.item.edit.quantity")
                        Spacer()
                        Stepper("\(quantity.formatted(.number.precision(.fractionLength(0...1))))",
                                value: $quantity, in: 0.5...99, step: 0.5)
                    }
                    Picker("shopping.item.edit.unit", selection: $unit) {
                        Text("–").tag("")
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("shopping.item.edit.brand.section") {
                    TextField("shopping.item.edit.brand", text: $brand)
                    Picker("shopping.item.edit.brand", selection: $brandTier) {
                        Label("shopping.item.edit.brand.preferred", systemImage: "star.fill").tag(BrandPreference.preferred)
                        Label("shopping.item.edit.brand.acceptable", systemImage: "checkmark").tag(BrandPreference.acceptable)
                        Label("shopping.item.edit.brand.never", systemImage: "xmark").tag(BrandPreference.never)
                    }
                    .pickerStyle(.segmented)
                }

                Section("shopping.item.edit.category.section") {
                    Picker("shopping.item.edit.category", selection: $category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.sfSymbol).tag(cat)
                        }
                    }
                    TextField("shopping.item.edit.note", text: $note)
                    TextField("shopping.item.edit.price", text: $estimatedPrice)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Button("button.delete", role: .destructive) { showDeleteConfirmation = true }
                }
            }
            .navigationTitle("shopping.item.edit.title")
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
            .confirmationDialog("shopping.item.delete.confirm", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("button.delete", role: .destructive) {
                    Task { await viewModel.deleteItem(item) }
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
