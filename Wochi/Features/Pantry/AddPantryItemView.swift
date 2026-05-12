import SwiftUI

struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PantryViewModel

    @State private var name = ""
    @State private var quantity = 1.0
    @State private var unit = ""
    @State private var category: ItemCategory = .other
    @State private var brand = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(7 * 86_400)
    @State private var lowStockThreshold = 1.0

    private let units = ["Stück", "kg", "g", "Liter", "ml", "Packung", "Flasche", "Dose", "Glas"]

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
                }
            }
            .navigationTitle("Artikel hinzufügen")
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
        }
    }

    private func save() {
        let item = PantryItem(name: name.trimmingCharacters(in: .whitespaces),
                              quantity: quantity,
                              unit: unit.isEmpty ? nil : unit)
        item.category = category
        item.brand = brand.isEmpty ? nil : brand
        item.expiryDate = hasExpiry ? expiryDate : nil
        item.lowStockThreshold = lowStockThreshold
        Task { await viewModel.addItem(item) }
        dismiss()
    }
}

#Preview {
    AddPantryItemView(viewModel: PantryViewModel(
        pantryRepository: PantryRepository(context: WochiDataContainer.preview.mainContext),
        shoppingRepository: ShoppingListRepository(context: WochiDataContainer.preview.mainContext),
        household: Household.sample()
    ))
}
