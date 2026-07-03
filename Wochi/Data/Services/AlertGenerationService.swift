import Foundation
import CoreLocation
import SwiftData

@MainActor
final class AlertGenerationService {
    static let shared = AlertGenerationService()

    func generateAlerts(
        for household: Household,
        stores: [StoreChain],
        context: ModelContext
    ) async throws {
        // 1. Resolve user location → find which chains are actually nearby
        //    and get postal code for regional deal filtering.
        let location = await LocationManager.shared.currentLocation()
        let postalCode = await resolvePostalCode(from: location)

        let nearbyChains: [StoreChain]
        if let location {
            let detected = await NearbyStoreService.shared.nearbyChains(near: location)
            nearbyChains = detected.isEmpty ? stores : detected
        } else {
            nearbyChains = stores
        }

        let priceRepo = PriceRepository(context: context)

        // 2. Fetch active deals for nearby chains, filtered by postal code.
        let allDeals = try await priceRepo.fetchCurrentFlyers(for: nearbyChains, postalCode: postalCode)
        guard !allDeals.isEmpty else { return }

        // Optionally narrow to products the household has bought recently.
        // If no purchase history exists yet, show every deal (good for new users).
        let recentNames = recentPurchasedItemNames(household: household, context: context)
        let deals: [FlyerPrice]
        if recentNames.isEmpty {
            // No history — show every deal that meets the savings threshold
            deals = allDeals.filter { $0.savingsPercent >= Constants.Budget.dealThresholdPercent }
        } else {
            // History exists — only show deals for products the user actually buys
            let lower = recentNames.map { $0.lowercased() }
            deals = allDeals.filter { price in
                let priceName = price.productName.lowercased()
                let meetsThreshold = price.savingsPercent >= Constants.Budget.dealThresholdPercent
                let matches = lower.contains { n in priceName.contains(n) || n.contains(priceName) }
                return meetsThreshold && matches
            }
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
            alert.preferredBrand = deal.brand
            alert.flyerImageURL  = deal.flyerImageURL
            alert.validFrom      = deal.validFrom
            alert.household      = household
            context.insert(alert)
        }

        try context.save()
    }

    // MARK: - Helpers

    private func recentPurchasedItemNames(household: Household, context: ModelContext) -> [String] {
        let cutoff = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -Constants.Budget.purchaseHistoryWeeks,
            to: Date()
        ) ?? Date()
        let descriptor = FetchDescriptor<ShoppingItem>(predicate: #Predicate { $0.isChecked })
        let items = (try? context.fetch(descriptor)) ?? []
        let householdID = household.id
        return Array(Set(
            items
                .filter { $0.list?.household?.id == householdID && ($0.checkedAt ?? .distantPast) >= cutoff }
                .map { $0.name }
        ))
    }

    private func alertExists(for productName: String, household: Household, context: ModelContext) -> Bool {
        let weekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<SubstitutionAlert>(predicate: #Predicate { $0.productName == productName })
        let householdID = household.id
        let count = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.household?.id == householdID && $0.createdAt >= weekAgo }
            .count
        return count >= Constants.Budget.maxAlertsPerProductPerWeek
    }

    private func resolvePostalCode(from location: CLLocation?) async -> String? {
        guard let location else { return nil }
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.postalCode
    }

    private func isBrandBlocked(brand: String?, household: Household, context: ModelContext) -> Bool {
        guard let brand else { return false }
        let householdID = household.id
        return ((try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? [])
            .contains { $0.preferredBrand == brand && $0.brandTier == .never && $0.list?.household?.id == householdID }
    }
}
