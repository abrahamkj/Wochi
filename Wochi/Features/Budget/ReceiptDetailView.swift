import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Kassenbon") {
                    LabeledContent("Geschäft", value: receipt.storeName)
                    LabeledContent("Datum", value: receipt.purchaseDate.germanDateString)
                    LabeledContent("Gesamt", value: receipt.totalAmount.eurFormatted)
                    LabeledContent("Gescannt", value: receipt.scannedAt.germanDateString)
                }

                Section("Artikel (\(receipt.items.count))") {
                    ForEach(receipt.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.body)
                                if item.quantity != 1 || item.unit != nil {
                                    Text("\(item.quantity.formatted(.number.precision(.fractionLength(0...1)))) \(item.unit ?? "×") × \(item.unitPrice.eurFormatted)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(item.totalPrice.eurFormatted)
                                    .font(.subheadline.bold())
                                if item.isDiscounted, let orig = item.originalPrice {
                                    Text(orig.eurFormatted)
                                        .font(.caption)
                                        .strikethrough()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kassenbon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReceiptDetailView(receipt: Receipt.sample())
}
