import Foundation
import SwiftData

// MARK: - Protocol

protocol PriceRepositoryProtocol {
    func fetchCurrentFlyers(for stores: [StoreChain]) async throws -> [FlyerPrice]
    func findBestPrice(for productName: String, in stores: [StoreChain]) async throws -> FlyerPrice?
    func checkForDeals(items: [String], stores: [StoreChain]) async throws -> [FlyerPrice]
}

// MARK: - Implementation

final class PriceRepository: PriceRepositoryProtocol {
    private let client: SupabaseClient
    private let context: ModelContext

    init(context: ModelContext, client: SupabaseClient = .shared) {
        self.context = context
        self.client  = client
    }

    // MARK: - Fetch flyers (with 24-hour cache)

    func fetchCurrentFlyers(for stores: [StoreChain]) async throws -> [FlyerPrice] {
        // Return cached prices if fresh (< 24 hours)
        if let cached = try? cachedPrices(for: stores), !cached.isEmpty {
            return cached
        }

        let today = ISO8601DateFormatter().string(from: Date())
        let storeFilter = stores.map { $0.rawValue }.joined(separator: ",")

        let query: [URLQueryItem] = [
            URLQueryItem(name: "valid_until", value: "gte.\(today)"),
            URLQueryItem(name: "store",       value: "in.(\(storeFilter))"),
            URLQueryItem(name: "select",      value: "*"),
        ]

        let prices = try await client.get(
            from: "flyer_prices",
            query: query,
            as: [FlyerPrice].self
        )

        try persistCache(prices)
        return prices
    }

    // MARK: - Find best deal for a product name (fuzzy local match)

    func findBestPrice(for productName: String, in stores: [StoreChain]) async throws -> FlyerPrice? {
        let all = try await fetchCurrentFlyers(for: stores)
        let lower = productName.lowercased()
        let matches = all.filter { $0.productName.lowercased().contains(lower) || lower.contains($0.productName.lowercased()) }
        return matches.min(by: { $0.dealPrice < $1.dealPrice })
    }

    // MARK: - Batch deal check

    func checkForDeals(items: [String], stores: [StoreChain]) async throws -> [FlyerPrice] {
        let all = try await fetchCurrentFlyers(for: stores)
        var results: [FlyerPrice] = []
        for name in items {
            let lower = name.lowercased()
            let matches = all.filter {
                $0.productName.lowercased().contains(lower) || lower.contains($0.productName.lowercased())
            }
            if let best = matches.min(by: { $0.dealPrice < $1.dealPrice }),
               best.savingsPercent >= Constants.Budget.dealThresholdPercent {
                results.append(best)
            }
        }
        return results
    }

    // MARK: - Cache helpers

    private func cachedPrices(for stores: [StoreChain]) throws -> [FlyerPrice]? {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<FlyerCache>(
            predicate: #Predicate { $0.fetchedAt > cutoff && !$0.isExpired }
        )
        let cached = try context.fetch(descriptor)
        guard !cached.isEmpty else { return nil }
        let storeRawValues = stores.map { $0.rawValue }
        return cached
            .filter { storeRawValues.contains($0.storeName) }
            .map { $0.asFlyerPrice }
    }

    private func persistCache(_ prices: [FlyerPrice]) throws {
        // Delete stale entries first
        let old = FetchDescriptor<FlyerCache>()
        let existing = try context.fetch(old)
        existing.forEach { context.delete($0) }

        prices.forEach { context.insert(FlyerCache(from: $0)) }
        try context.save()
    }
}
