import SwiftUI
import Charts

struct BudgetView: View {
    @StateObject private var viewModel: BudgetViewModel
    @State private var showScanner = false
    @State private var showReceipts = false
    @State private var selectedTab = 0

    init(viewModel: BudgetViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthSelector

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let record = viewModel.currentRecord, record.receiptCount > 0 {
                        totalCard(record: record)
                        breakdownTabs(record: record)
                        receiptsPreview
                    } else {
                        EmptyStateView(
                            symbol: "receipt",
                            title: "budget.empty.title",
                            subtitle: "budget.empty.subtitle",
                            actionTitle: "Kassenbon scannen"
                        ) {
                            showScanner = true
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle(LocalizedStringKey("tab.budget"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                ReceiptCameraView(scanUseCase: viewModel.scanUseCase, household: viewModel.household)
            }
            .navigationDestination(isPresented: $showReceipts) {
                ReceiptHistoryView(viewModel: viewModel)
            }
            .task { await viewModel.load() }
            .alert("Fehler", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }

    private var monthSelector: some View {
        HStack {
            Button { viewModel.navigateToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            Spacer()
            Text(viewModel.displayMonthTitle)
                .font(.headline)
            Spacer()
            Button { viewModel.navigateToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func totalCard(record: BudgetRecord) -> some View {
        VStack(spacing: 8) {
            Text(record.totalSpent.eurFormatted)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            if let change = viewModel.monthOverMonthChange {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(abs(change).formatted(.number.precision(.fractionLength(0...1)))) % gegenüber letztem Monat")
                        .font(.subheadline)
                }
                .foregroundStyle(change >= 0 ? .red : .green)
            }

            Text("Basierend auf \(record.receiptCount) Kassenbons")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
        .padding(.horizontal)
    }

    private func breakdownTabs(record: BudgetRecord) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Ansicht", selection: $selectedTab) {
                Text("Geschäfte").tag(0)
                Text("Kategorien").tag(1)
                if record.byMember.count > 1 {
                    Text("Mitglieder").tag(2)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            switch selectedTab {
            case 0: StoreBreakdownView(byStore: record.byStore)
            case 1: CategoryBreakdownView(byCategory: record.byCategory)
            default: MemberBreakdownView(byMember: record.byMember)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
        .padding(.horizontal)
    }

    private var receiptsPreview: some View {
        Button {
            showReceipts = true
        } label: {
            HStack {
                Label("Alle Kassenbons", systemImage: "list.bullet.rectangle")
                Spacer()
                Text("\(viewModel.receipts.count)")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

#Preview {
    let context = WochiDataContainer.preview.mainContext
    let household = Household.sample()
    let receiptRepo = ReceiptRepository(context: context)
    let budgetRepo = BudgetRepository(receiptRepository: receiptRepo)
    return BudgetView(viewModel: BudgetViewModel(
        budgetRepository: budgetRepo,
        receiptRepository: receiptRepo,
        household: household
    ))
    .modelContainer(WochiDataContainer.preview)
}
