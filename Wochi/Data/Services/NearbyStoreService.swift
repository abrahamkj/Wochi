import CoreLocation
import MapKit

// MARK: - NearbyStoreService
//
// Uses MKLocalSearch to find which supermarket chains actually have
// locations within `radiusKm` of the user. Returns matching StoreChains
// so the app only fetches deals for stores the user can realistically visit.

actor NearbyStoreService {
    static let shared = NearbyStoreService()

    // Search terms that map to each StoreChain
    private let chainQueries: [(StoreChain, String)] = [
        (.kaufland, "Kaufland"),
        (.lidl,     "Lidl"),
        (.rewe,     "REWE"),
        (.edeka,    "Edeka"),
        (.aldi,     "Aldi"),
        (.penny,    "Penny"),
        (.netto,    "Netto"),
        (.dm,       "dm Drogerie"),
        (.rossmann, "Rossmann"),
    ]

    func nearbyChains(near location: CLLocation, radiusKm: Double = 10) async -> [StoreChain] {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radiusKm * 1000,
            longitudinalMeters: radiusKm * 1000
        )
        var found: [StoreChain] = []
        await withTaskGroup(of: StoreChain?.self) { group in
            for (chain, query) in chainQueries {
                group.addTask {
                    await self.search(query: query, region: region, chain: chain)
                }
            }
            for await result in group {
                if let chain = result { found.append(chain) }
            }
        }
        return found
    }

    private func search(query: String, region: MKCoordinateRegion, chain: StoreChain) async -> StoreChain? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest

        let results = try? await MKLocalSearch(request: request).start()
        return results?.mapItems.isEmpty == false ? chain : nil
    }
}
