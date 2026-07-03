import SwiftUI
import SwiftData

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [SubstitutionAlert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var unreadCount: Int { alerts.filter { !$0.isRead && !$0.isDismissed }.count }

    private let household: Household
    private let context: ModelContext

    init(household: Household, context: ModelContext) {
        self.household = household
        self.context = context
    }

    // Fetch from Supabase → generate alerts → reload list
    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AlertGenerationService.shared.generateAlerts(
                for: household,
                stores: preferredStores(),
                context: context
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        fetchAlerts()
    }

    // Just reload from SwiftData (fast path for tab appear)
    func load() async {
        fetchAlerts()
        // Also kick off a network refresh in the background
        Task { await refresh() }
    }

    func markAsRead(_ alert: SubstitutionAlert) async {
        alert.isRead = true
        try? context.save()
        fetchAlerts()
    }

    func dismiss(_ alert: SubstitutionAlert) async {
        alert.isDismissed = true
        try? context.save()
        fetchAlerts()
    }

    func rate(_ alert: SubstitutionAlert, thumbsUp: Bool) async {
        if !thumbsUp, let brand = alert.preferredBrand {
            // Mark brand as .never on all household items — in memory to avoid
            // complex optional-chain #Predicate
            let householdID = household.id
            let all = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
            all.filter {
                $0.preferredBrand == brand &&
                $0.list?.household?.id == householdID
            }.forEach { $0.brandTier = .never }
        }
        alert.isDismissed = true
        try? context.save()
        fetchAlerts()
    }

    // MARK: - Helpers

    private func fetchAlerts() {
        // Fetch all non-dismissed alerts, filter by household in memory to avoid
        // optional-chain predicate timeout
        let descriptor = FetchDescriptor<SubstitutionAlert>(
            predicate: #Predicate { !$0.isDismissed },
            sortBy: [SortDescriptor(\.savingsPercent, order: .reverse)]
        )
        let householdID = household.id
        let all = (try? context.fetch(descriptor)) ?? []
        alerts = all.filter { $0.household?.id == householdID }
    }

    private func preferredStores() -> [StoreChain] {
        let active = (household.preferredStores ?? []).filter { $0.isActive }.map { $0.storeChain }
        return active.isEmpty ? StoreChain.allCases.filter { $0 != .other } : active
    }
}
