import SwiftUI

// MARK: - ReceiptReviewView

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let scanUseCase: ScanReceiptUseCase
    let household: Household
    let onDismiss: () -> Void

    // Editable receipt fields
    @State private var storeName: String
    @State private var selectedChain: StoreChain?
    @State private var customStoreName: String
    @State private var purchaseDate: Date
    @State private var editableItems: [EditableReceiptItem]
    @State private var parsedTotal: Double

    @State private var isSaving = false
    @State private var showPantryPrompt = false
    @State private var saveError: WochiError?
    @State private var showErrorAlert = false
    @State private var showAddItem = false

    init(receipt: Receipt, scanUseCase: ScanReceiptUseCase, household: Household, onDismiss: @escaping () -> Void) {
        self.scanUseCase = scanUseCase
        self.household = household
        self.onDismiss = onDismiss

        let detectedChain = StoreChain.allCases.first {
            receipt.storeName.localizedCaseInsensitiveContains($0.rawValue)
        }
        _selectedChain = State(initialValue: detectedChain)
        _storeName = State(initialValue: receipt.storeName)
        _customStoreName = State(initialValue: detectedChain == nil ? receipt.storeName : "")
        _purchaseDate = State(initialValue: receipt.purchaseDate)
        _editableItems = State(initialValue: receipt.items.map { EditableReceiptItem(from: $0) })
        _parsedTotal = State(initialValue: receipt.totalAmount)
    }

    // MARK: - Computed

    private var itemsSum: Double {
        editableItems.reduce(0) { $0 + ($1.totalPrice ?? 0) }
    }

    private var totalMismatch: Bool {
        guard parsedTotal > 0 else { return false }
        return abs(itemsSum - parsedTotal) / parsedTotal > 0.10
    }

    private var resolvedStoreName: String {
        if let chain = selectedChain, chain != .other {
            return chain.rawValue
        }
        return customStoreName.isEmpty ? "Sonstiges" : customStoreName
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                storeSection
                dateSection
                itemsSection
                totalSection
            }
            .navigationTitle(LocalizedStringKey("Kassenbon prüfen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Erneut scannen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Bestätigen") {
                            Task { await saveReceipt() }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Fehler", isPresented: $showErrorAlert, presenting: saveError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .confirmationDialog(
                "Vorrat aktualisieren?",
                isPresented: $showPantryPrompt,
                titleVisibility: .visible
            ) {
                Button("Ja, Vorrat aktualisieren") { onDismiss() }
                Button("Nein, danke") { onDismiss() }
            } message: {
                Text("Möchtest du deinen Vorrat mit den Artikeln aus diesem Bon aktualisieren?")
            }
        }
    }

    // MARK: - Sections

    private var storeSection: some View {
        Section(header: Text("Geschäft")) {
            Picker("Kette", selection: $selectedChain) {
                Text("Sonstiges").tag(StoreChain?.none)
                ForEach(StoreChain.allCases, id: \.self) { chain in
                    Text(chain.rawValue).tag(Optional(chain))
                }
            }
            if selectedChain == nil || selectedChain == .other {
                TextField("Geschäftsname", text: $customStoreName)
            }
        }
    }

    private var dateSection: some View {
        Section(header: Text("Datum")) {
            DatePicker(
                "Einkaufsdatum",
                selection: $purchaseDate,
                displayedComponents: .date
            )
            .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }

    private var itemsSection: some View {
        Section(header: Text("Artikel")) {
            ForEach($editableItems) { $item in
                ReceiptItemRow(item: $item)
            }
            .onDelete { indexSet in
                editableItems.remove(atOffsets: indexSet)
            }

            Button {
                showAddItem = true
            } label: {
                Label("Artikel hinzufügen", systemImage: "plus.circle")
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddReceiptItemSheet { newItem in
                editableItems.append(newItem)
            }
        }
    }

    private var totalSection: some View {
        Section(header: Text("Gesamtbetrag")) {
            HStack {
                Text("Gescannt")
                Spacer()
                Text(parsedTotal, format: .currency(code: "EUR"))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Summe Artikel")
                Spacer()
                Text(itemsSum, format: .currency(code: "EUR"))
                    .foregroundStyle(totalMismatch ? .orange : .primary)
            }
            if totalMismatch {
                Label(
                    "Differenz >10% – bitte Artikel prüfen",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Save

    private func saveReceipt() async {
        isSaving = true
        defer { isSaving = false }

        let receipt = Receipt(
            storeName: resolvedStoreName,
            purchaseDate: purchaseDate,
            totalAmount: parsedTotal > 0 ? parsedTotal : itemsSum
        )
        receipt.isVerified = true
        receipt.items = editableItems.compactMap { $0.toReceiptItem() }

        do {
            try await scanUseCase.save(receipt, for: household)
            showPantryPrompt = true
        } catch let wochiErr as WochiError {
            saveError = wochiErr
            showErrorAlert = true
        } catch {
            saveError = .receiptParsingFailed
            showErrorAlert = true
        }
    }
}

// MARK: - EditableReceiptItem

struct EditableReceiptItem: Identifiable {
    let id: UUID
    var name: String
    var quantity: Double
    var unitPrice: Double?
    var totalPrice: Double?
    var category: ItemCategory

    init(from item: ReceiptItem) {
        self.id = item.id
        self.name = item.name
        self.quantity = item.quantity
        self.unitPrice = item.unitPrice
        self.totalPrice = item.totalPrice
        self.category = item.category
    }

    init() {
        self.id = UUID()
        self.name = ""
        self.quantity = 1
        self.unitPrice = nil
        self.totalPrice = nil
        self.category = .other
    }

    func toReceiptItem() -> ReceiptItem? {
        guard !name.isEmpty else { return nil }
        let unit = unitPrice ?? 0
        let total = totalPrice ?? unit * quantity
        return ReceiptItem(name: name, quantity: quantity, unitPrice: unit, totalPrice: total)
    }
}

// MARK: - ReceiptItemRow

private struct ReceiptItemRow: View {
    @Binding var item: EditableReceiptItem

    @State private var priceText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Artikelname", text: $item.name)
                .font(.body)

            HStack(spacing: 12) {
                Stepper(
                    value: $item.quantity,
                    in: 0.5...99,
                    step: 0.5
                ) {
                    Text("Menge: \(item.quantity.formatted(.number.precision(.fractionLength(0...1))))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Preis", text: $priceText)
                    .keyboardType(.decimalPad)
                    .font(.caption)
                    .frame(width: 70)
                    .onAppear {
                        if let total = item.totalPrice {
                            priceText = String(format: "%.2f", total)
                        }
                    }
                    .onChange(of: priceText) { _, newValue in
                        let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(normalized) {
                            item.totalPrice = value
                            item.unitPrice = value / max(item.quantity, 0.5)
                        }
                    }
                Text("€")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddReceiptItemSheet

private struct AddReceiptItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (EditableReceiptItem) -> Void

    @State private var newItem = EditableReceiptItem()
    @State private var priceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Artikelname", text: $newItem.name)
                    Stepper(
                        "Menge: \(newItem.quantity.formatted(.number.precision(.fractionLength(0...1))))",
                        value: $newItem.quantity,
                        in: 0.5...99,
                        step: 0.5
                    )
                    HStack {
                        TextField("Preis", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text("€")
                    }
                    Picker("Kategorie", selection: $newItem.category) {
                        ForEach(ItemCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
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
                    Button("Hinzufügen") {
                        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
                        if let price = Double(normalized) {
                            newItem.totalPrice = price
                            newItem.unitPrice = price / max(newItem.quantity, 0.5)
                        }
                        if let item = newItem.toReceiptItem() {
                            var editable = EditableReceiptItem(from: item)
                            editable.name = newItem.name
                            editable.category = newItem.category
                            onAdd(editable)
                        }
                        dismiss()
                    }
                    .disabled(newItem.name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReceiptReviewView(
        receipt: Receipt.sample(),
        scanUseCase: {
            // ScanReceiptUseCase requires a ReceiptRepositoryProtocol at init
            let container = WochiDataContainer.preview
            let repo = ReceiptRepository(context: container.mainContext)
            return ScanReceiptUseCase(repository: repo)
        }(),
        household: Household.sample(),
        onDismiss: {}
    )
}
