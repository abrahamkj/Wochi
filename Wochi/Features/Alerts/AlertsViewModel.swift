import SwiftUI
import SwiftData

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published var alerts: [SubstitutionAlert] = []
    @Published var isLoading = false

    var unreadCount: Int { alerts.filter { !$0.isRead && !$0.isDismissed }.count }

    private let household: Household
    private let context: ModelContext

    init(household: Household, context: ModelContext) {
        self.household = household
        self.context = context
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let householdID = household.id
        let descriptor = FetchDescriptor<SubstitutionAlert>(
            predicate: #Predicate { $0.household?.id == householdID && !$0.isDismissed },
            sortBy: [SortDescriptor(\.savingsPercent, order: .reverse)]
        )
        alerts = (try? context.fetch(descriptor)) ?? []
    }

    func markAsRead(_ alert: SubstitutionAlert) async {
        alert.isRead = true
        try? context.save()
        await load()
    }

    func dismiss(_ alert: SubstitutionAlert) async {
        alert.isDismissed = true
        try? context.save()
        await load()
    }

    func rate(_ alert: SubstitutionAlert, thumbsUp: Bool) async {
        // Update brand preference for matching shopping items
        // thumbsDown → mark brand as .never in household's items
        if !thumbsUp {
            let householdID = household.id
            let descriptor = FetchDescriptor<ShoppingItem>(
                predicate: #Predicate {
                    $0.list?.household?.id == householdID &&
                    $0.preferredBrand == alert.preferredBrand
                }
            )
            if let items = try? context.fetch(descriptor) {
                items.forEach { $0.brandTier = thumbsUp ? .preferred : .never }
            }
        }
        alert.isDismissed = true
        try? context.save()
        await load()
    }
}
