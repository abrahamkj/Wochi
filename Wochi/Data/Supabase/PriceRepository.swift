import Foundation
import CoreLocation
import SwiftData

// MARK: - Protocol

protocol PriceRepositoryProtocol {
    func fetchCurrentFlyers(for stores: [StoreChain], postalCode: String?) async throws -> [FlyerPrice]
    func findBestPrice(for productName: String, in stores: [StoreChain], postalCode: String?) async throws -> FlyerPrice?
    func checkForDeals(items: [String], stores: [StoreChain], postalCode: String?) async throws -> [FlyerPrice]
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

    func fetchCurrentFlyers(for stores: [StoreChain], postalCode: String? = nil) async throws -> [FlyerPrice] {
        if let cached = try? cachedPrices(for: stores, postalCode: postalCode), !cached.isEmpty {
            return cached
        }

        let today = ISO8601DateFormatter().string(from: Date())
        let storeFilter = stores.map { $0.rawValue }.joined(separator: ",")

        var query: [URLQueryItem] = [
            URLQueryItem(name: "valid_until", value: "gte.\(today)"),
            URLQueryItem(name: "store",       value: "in.(\(storeFilter))"),
            URLQueryItem(name: "select",      value: "*"),
        ]

        // If we know the user's postal code, request deals for that area OR
        // nationwide deals (postal_code is null)
        if let postalCode {
            query.append(URLQueryItem(name: "or", value: "(postal_code.eq.\(postalCode),postal_code.is.null)"))
        }

        let prices = try await client.get(from: "flyer_prices", query: query, as: [FlyerPrice].self)
        try persistCache(prices)
        return prices
    }

    // MARK: - Find best deal for a product name (fuzzy local match)

    func findBestPrice(for productName: String, in stores: [StoreChain], postalCode: String? = nil) async throws -> FlyerPrice? {
        let all = try await fetchCurrentFlyers(for: stores, postalCode: postalCode)
        let lower = productName.lowercased()
        let matches = all.filter {
            $0.productName.lowercased().contains(lower) || lower.contains($0.productName.lowercased())
        }
        return matches.min(by: { $0.dealPrice < $1.dealPrice })
    }

    // MARK: - Batch deal check

    func checkForDeals(items: [String], stores: [StoreChain], postalCode: String? = nil) async throws -> [FlyerPrice] {
        let all = try await fetchCurrentFlyers(for: stores, postalCode: postalCode)
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

    private func cachedPrices(for stores: [StoreChain], postalCode: String?) throws -> [FlyerPrice]? {
        let ageCutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<FlyerCache>(predicate: #Predicate { $0.fetchedAt > ageCutoff })
        let cached = try context.fetch(descriptor)
        guard !cached.isEmpty else { return nil }
        let now = Date()
        let storeRawValues = stores.map { $0.rawValue }
        let valid = cached.filter {
            $0.validUntil >= now &&
            storeRawValues.contains($0.storeName) &&
            (postalCode == nil || $0.postalCode == nil || $0.postalCode == postalCode)
        }
        return valid.isEmpty ? nil : valid.map { $0.asFlyerPrice }
    }

    private func persistCache(_ prices: [FlyerPrice]) throws {
        let existing = try context.fetch(FetchDescriptor<FlyerCache>())
        existing.forEach { context.delete($0) }
        prices.forEach { context.insert(FlyerCache(from: $0)) }
        try context.save()
    }
}
