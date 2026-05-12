import SwiftUI
import Charts

struct StoreBreakdownView: View {
    let byStore: [BudgetRecord.StoreSpend]

    var body: some View {
        if byStore.isEmpty {
            Text("Keine Daten")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Chart(byStore) { spend in
                    BarMark(
                        x: .value("Betrag", spend.amount),
                        y: .value("Geschäft", spend.storeName)
                    )
                    .foregroundStyle(barColor(for: spend.storeName))
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.eurFormatted)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(byStore.count) * 44 + 40)
                .padding(.horizontal)

                Divider()

                ForEach(byStore) { spend in
                    HStack {
                        Circle()
                            .fill(barColor(for: spend.storeName))
                            .frame(width: 10, height: 10)
                        Text(spend.storeName)
                            .font(.subheadline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(spend.amount.eurFormatted)
                                .font(.subheadline).bold()
                            Text("\(spend.percentage.formatted(.number.precision(.fractionLength(0...1)))) %")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func barColor(for storeName: String) -> Color {
        if let chain = StoreChain(rawValue: storeName) {
            return Color(hex: chain.primaryColor)
        }
        return .accentColor
    }
}

#Preview {
    StoreBreakdownView(byStore: [
        BudgetRecord.StoreSpend(storeName: "Kaufland", amount: 89.50, percentage: 60, receiptCount: 3),
        BudgetRecord.StoreSpend(storeName: "Lidl", amount: 34.20, percentage: 23, receiptCount: 2),
        BudgetRecord.StoreSpend(storeName: "REWE", amount: 25.00, percentage: 17, receiptCount: 1),
    ])
    .padding()
}
