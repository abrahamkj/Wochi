import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    let byCategory: [BudgetRecord.CategorySpend]

    private var displayCategories: [BudgetRecord.CategorySpend] {
        var result = byCategory.filter { $0.percentage >= 2 }
        let small = byCategory.filter { $0.percentage < 2 }
        if !small.isEmpty {
            let smallTotal = small.reduce(0) { $0 + $1.amount }
            let smallPct = small.reduce(0) { $0 + $1.percentage }
            result.append(BudgetRecord.CategorySpend(
                category: .other,
                amount: smallTotal,
                percentage: smallPct
            ))
        }
        return result
    }

    var body: some View {
        if byCategory.isEmpty {
            Text("Keine Daten")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            VStack(spacing: 16) {
                Chart(displayCategories) { spend in
                    SectorMark(
                        angle: .value("Betrag", spend.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Kategorie", spend.category.rawValue))
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .padding(.horizontal)

                Divider()

                ForEach(displayCategories) { spend in
                    HStack {
                        Image(systemName: spend.category.sfSymbol)
                            .frame(width: 24)
                            .foregroundStyle(.secondary)
                        Text(spend.category.rawValue)
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
}

#Preview {
    CategoryBreakdownView(byCategory: [
        BudgetRecord.CategorySpend(category: .dairy, amount: 45.0, percentage: 30),
        BudgetRecord.CategorySpend(category: .fruit, amount: 30.0, percentage: 20),
        BudgetRecord.CategorySpend(category: .drinks, amount: 22.5, percentage: 15),
        BudgetRecord.CategorySpend(category: .other, amount: 52.5, percentage: 35),
    ])
    .padding()
}
