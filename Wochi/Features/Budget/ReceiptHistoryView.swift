import SwiftUI

struct ReceiptHistoryView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var selectedReceipt: Receipt?
    @State private var deleteCandidate: Receipt?

    var body: some View {
        List {
            ForEach(viewModel.receipts) { receipt in
                ReceiptRow(receipt: receipt)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedReceipt = receipt }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteCandidate = receipt
                        } label: {
                            Label("button.delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle("receipt.history.title")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.receipts.isEmpty {
                EmptyStateView(
                    symbol: "receipt",
                    title: "budget.empty.title",
                    subtitle: "budget.empty.subtitle"
                )
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            ReceiptDetailView(receipt: receipt)
        }
        .confirmationDialog("receipt.history.delete.confirm", isPresented: .constant(deleteCandidate != nil), titleVisibility: .visible) {
            Button("button.delete", role: .destructive) {
                if let r = deleteCandidate {
                    Task { await viewModel.deleteReceipt(r) }
                    deleteCandidate = nil
                }
            }
            Button("button.cancel", role: .cancel) { deleteCandidate = nil }
        }
    }
}

private struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(storeColor)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(receipt.storeName.prefix(1)))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading) {
                Text(receipt.storeName)
                    .font(.body)
                Text(receipt.purchaseDate.germanDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(receipt.totalAmount.eurFormatted)
                .font(.subheadline.bold())
        }
        .padding(.vertical, 4)
    }

    private var storeColor: Color {
        if let chain = StoreChain.detect(from: receipt.storeName) {
            return Color(hex: chain.primaryColor)
        }
        return .accentColor
    }
}

#Preview {
    let context = WochiDataContainer.preview.mainContext
    let receiptRepo = ReceiptRepository(context: context)
    let budgetRepo = BudgetRepository(receiptRepository: receiptRepo)
    let vm = BudgetViewModel(budgetRepository: budgetRepo, receiptRepository: receiptRepo, household: Household.sample())
    return NavigationStack {
        ReceiptHistoryView(viewModel: vm)
    }
    .modelContainer(WochiDataContainer.preview)
}
