import SwiftUI

struct MemberBreakdownView: View {
    let byMember: [BudgetRecord.MemberSpend]

    var body: some View {
        if byMember.isEmpty {
            Text("Keine Daten")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Basierend auf gescannten Kassenbons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ForEach(byMember) { spend in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(String(spend.memberName.prefix(1)))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.accentColor)
                            }

                        VStack(alignment: .leading) {
                            Text(spend.memberName)
                                .font(.subheadline)
                            Text("\(spend.receiptCount) Kassenbon(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(spend.amount.eurFormatted)
                            .font(.subheadline).bold()
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    MemberBreakdownView(byMember: [
        BudgetRecord.MemberSpend(memberID: UUID(), memberName: "Max Müller", amount: 89.50, receiptCount: 3),
        BudgetRecord.MemberSpend(memberID: UUID(), memberName: "Lisa Müller", amount: 59.20, receiptCount: 2),
    ])
    .padding()
}
