import Foundation
import SwiftData

@Model
final class PreferredStore {
    @Attribute(.unique) var id: UUID
    var storeChain: StoreChain
    var customName: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var isActive: Bool
    var sortOrder: Int

    var household: Household?

    init(storeChain: StoreChain) {
        self.id = UUID()
        self.storeChain = storeChain
        self.isActive = true
        self.sortOrder = 0
    }
}

enum StoreChain: String, Codable, CaseIterable {
    case kaufland   = "Kaufland"
    case lidl       = "Lidl"
    case rewe       = "REWE"
    case edeka      = "Edeka"
    case aldi       = "Aldi"
    case penny      = "Penny"
    case netto      = "Netto"
    case dm         = "dm"
    case rossmann   = "Rossmann"
    case other      = "Sonstiges"

    var logoAsset: String { "logo_\(rawValue.lowercased())" }

    var primaryColor: String {
        switch self {
        case .kaufland:  return "#E30613"
        case .lidl:      return "#0050AA"
        case .rewe:      return "#CC0000"
        case .edeka:     return "#FFD700"
        case .aldi:      return "#003C88"
        case .penny:     return "#CC0000"
        case .netto:     return "#FFD700"
        case .dm:        return "#D40511"
        case .rossmann:  return "#E30613"
        case .other:     return "#888888"
        }
    }

    static func detect(from text: String) -> StoreChain? {
        let lower = text.lowercased()
        return allCases.first { lower.contains($0.rawValue.lowercased()) }
    }
}
