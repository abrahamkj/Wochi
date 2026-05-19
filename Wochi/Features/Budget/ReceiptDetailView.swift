import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("receipt.detail.title") {
                    LabeledContent(String(localized: "receipt.review.store"), value: receipt.storeName)
                    LabeledContent(String(localized: "receipt.review.date"), value: receipt.purchaseDate.germanDateString)
                    LabeledContent(String(localized: "receipt.detail.total"), value: receipt.totalAmount.eurFormatted)
                    LabeledContent(String(localized: "receipt.review.scanned"), value: receipt.scannedAt.germanDateString)
                }

                Section(String(format: String(localized: "receipt.detail.items"), (receipt.items ?? []).count)) {
                    ForEach(receipt.items ?? []) { item in
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
            .navigationTitle("receipt.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReceiptDetailView(receipt: Receipt.sample())
}
