import SwiftUI

struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel

    init(viewModel: AlertsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.alerts.isEmpty {
                    EmptyStateView(
                        symbol: "tag.slash",
                        title: "Keine Angebote",
                        subtitle: "Keine aktuellen Angebote für deine Produkte."
                    )
                } else {
                    List {
                        ForEach(viewModel.alerts) { alert in
                            AlertCard(alert: alert) { thumbsUp in
                                Task { await viewModel.rate(alert, thumbsUp: thumbsUp) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    Task { await viewModel.dismiss(alert) }
                                } label: {
                                    Label("Ignorieren", systemImage: "xmark.circle")
                                }
                                .tint(.secondary)
                            }
                            .task { await viewModel.markAsRead(alert) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Angebote")
            .task { await viewModel.load() }
        }
    }
}

private struct AlertCard: View {
    let alert: SubstitutionAlert
    let onRate: (Bool) -> Void
    @State private var showRatingPrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(alert.productName)
                    .font(.headline)
                Spacer()
                if !alert.isRead {
                    Text("Neu")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 16) {
                storeTag(name: alert.currentStore.rawValue, price: alert.regularPrice, isRegular: true)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                storeTag(name: alert.dealStore.rawValue, price: alert.dealPrice, isRegular: false)
                Spacer()
                savingsBadge
            }

            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                Text("bis \(alert.validUntil.germanShortDate)")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if showRatingPrompt {
                HStack(spacing: 16) {
                    Text("Hast du es gekauft?")
                        .font(.subheadline)
                    Spacer()
                    Button("👍") { onRate(true); showRatingPrompt = false }
                        .buttonStyle(.bordered)
                    Button("👎") { onRate(false); showRatingPrompt = false }
                        .buttonStyle(.bordered)
                }
            } else {
                Button("Habe ich gekauft") { showRatingPrompt = true }
                    .font(.caption)
                    .foregroundStyle(.accentColor)
            }
        }
        .padding(.vertical, 8)
    }

    private func storeTag(name: String, price: Double, isRegular: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption.bold())
            Text(price.eurFormatted)
                .font(.subheadline)
                .strikethrough(isRegular)
                .foregroundStyle(isRegular ? .secondary : .primary)
        }
    }

    private var savingsBadge: some View {
        Text("-\(alert.savingsPercent.formatted(.number.precision(.fractionLength(0...0)))) %")
            .font(.callout.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())
    }
}

#Preview {
    AlertsView(viewModel: AlertsViewModel(
        household: Household.sample(),
        context: WochiDataContainer.preview.mainContext
    ))
    .modelContainer(WochiDataContainer.preview)
}
