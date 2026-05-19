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
                }
            }
            .navigationTitle("pantry.item.add.title")
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
