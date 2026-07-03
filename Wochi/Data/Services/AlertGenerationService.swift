import Foundation
import SwiftData

// MARK: - AlertGenerationService
//
// Compares recent purchase history against current flyer deals,
// then inserts new SubstitutionAlerts for items that qualify
// (≥15% savings, not brand-blocked, not already alerted this week).

@MainActor
final class AlertGenerationService {
    static let shared = AlertGenerationService()

    func generateAlerts(
        for household: Household,
        stores: [StoreChain],
        context: ModelContext
    ) async {
        let priceRepo = PriceRepository(context: context)
        let recentItems = recentPurchasedItemNames(household: household, context: context)
        guard !recentItems.isEmpty else { return }

        let deals: [FlyerPrice]
        do {
            deals = try await priceRepo.checkForDeals(items: recentItems, stores: stores)
        } catch {
            return
        }

        for deal in deals {
            guard !alertExists(for: deal.productName, household: household, context: context) else { continue }
            guard !isBrandBlocked(brand: deal.brand, household: household, context: context) else { continue }

            let alert = SubstitutionAlert(
                productName:  deal.productName,
                dealStore:    deal.storeChain,
                regularPrice: deal.regularPrice,
                dealPrice:    deal.dealPrice,
                validUntil:   deal.validUntil
            )
            alert.preferredBrand  = deal.brand
            alert.flyerImageURL   = deal.flyerImageURL
            alert.validFrom       = deal.validFrom
            alert.household       = household
            context.insert(alert)
        }

        try? context.save()
    }

    // MARK: - Helpers

    private func recentPurchasedItemNames(
        household: Household,
        context: ModelContext
    ) -> [String] {
        let cutoff = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -Constants.Budget.purchaseHistoryWeeks,
            to: Date()
        ) ?? Date()

        // Fetch only checked items; filter by household and date in memory to avoid
        // predicate type-check timeouts from deep optional chains + nil-coalescing.
        let descriptor = FetchDescriptor<ShoppingItem>(
            predicate: #Predicate { $0.isChecked }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        let householdID = household.id
        let unique = Set(
            items
                .filter {
                    $0.list?.household?.id == householdID &&
                    ($0.checkedAt ?? .distantPast) >= cutoff
                }
                .map { $0.name }
        )
        return Array(unique)
    }

    private func alertExists(
        for productName: String,
        household: Household,
        context: ModelContext
    ) -> Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        // Fetch by productName only; filter household + date in memory.
        let descriptor = FetchDescriptor<SubstitutionAlert>(
            predicate: #Predicate { $0.productName == productName }
        )
        let householdID = household.id
        let matches = (try? context.fetch(descriptor)) ?? []
        let count = matches.filter {
            $0.household?.id == householdID && $0.createdAt >= weekAgo
        }.count
        return count >= Constants.Budget.maxAlertsPerProductPerWeek
    }

    private func isBrandBlocked(
        brand: String?,
        household: Household,
        context: ModelContext
    ) -> Bool {
        guard let brand else { return false }
        // Fetch items with this brand; check household + brandTier in memory.
        let descriptor = FetchDescriptor<ShoppingItem>(
            predicate: #Predicate { $0.preferredBrand == brand }
        )
        let householdID = household.id
        let items = (try? context.fetch(descriptor)) ?? []
        return items.contains {
            $0.list?.household?.id == householdID &&
            $0.brandTier == .never
        }
    }
}
