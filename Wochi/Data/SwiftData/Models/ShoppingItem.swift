import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: Double = 1
    var unit: String?
    var preferredBrand: String?
    var brandTier: BrandPreference = .acceptable
    var category: ItemCategory = .other
    var note: String?
    var estimatedPrice: Double?
    var suggestedStore: String?
    var isChecked: Bool = false
    var checkedAt: Date?
    var sortOrder: Int = 0
    var addedAt: Date = Date()
    var addedByMemberID: UUID?
    var checkedByMemberID: UUID?
    var sourceType: ItemSourceType = .manual

    var list: ShoppingList?

    init(name: String, quantity: Double = 1, unit: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.brandTier = .acceptable
        self.category = ItemCategory.classify(name: name)
        self.isChecked = false
        self.sortOrder = 0
        self.addedAt = Date()
        self.sourceType = .manual
    }
}

enum BrandPreference: String, Codable {
    case preferred
    case acceptable
    case never
}

enum ItemSourceType: String, Codable {
    case manual
    case voice
    case pantryAlert
    case recurring
    case receiptScan
}

enum ItemCategory: String, Codable, CaseIterable {
    case fruit      = "Obst & Gemüse"
    case dairy      = "Milchprodukte"
    case meat       = "Fleisch & Fisch"
    case bakery     = "Brot & Backwaren"
    case frozen     = "Tiefkühl"
    case drinks     = "Getränke"
    case snacks     = "Snacks & Süßes"
    case pantryDry  = "Vorrat"
    case cleaning   = "Putzmittel"
    case hygiene    = "Hygiene"
    case household  = "Haushalt"
    case baby       = "Baby"
    case pet        = "Tier"
    case other      = "Sonstiges"

    var displayName: String {
        switch self {
        case .fruit:     return String(localized: "category.produce")
        case .dairy:     return String(localized: "category.dairy")
        case .meat:      return String(localized: "category.meat")
        case .bakery:    return String(localized: "category.bakery")
        case .frozen:    return String(localized: "category.frozen")
        case .drinks:    return String(localized: "category.beverages")
        case .snacks:    return String(localized: "category.snacks")
        case .pantryDry: return String(localized: "category.pantry")
        case .cleaning:  return String(localized: "category.cleaning")
        case .hygiene:   return String(localized: "category.hygiene")
        case .household: return String(localized: "category.household")
        case .baby:      return String(localized: "category.baby")
        case .pet:       return String(localized: "category.pet")
        case .other:     return String(localized: "category.other")
        }
    }

    var sfSymbol: String {
        switch self {
        case .fruit:     return "leaf"
        case .dairy:     return "drop"
        case .meat:      return "fork.knife"
        case .bakery:    return "birthday.cake"
        case .frozen:    return "snowflake"
        case .drinks:    return "wineglass"
        case .snacks:    return "popcorn"
        case .pantryDry: return "cabinet"
        case .cleaning:  return "bubbles.and.sparkles"
        case .hygiene:   return "shower"
        case .household: return "house"
        case .baby:      return "figure.and.child.holdinghands"
        case .pet:       return "pawprint"
        case .other:     return "tag"
        }
    }

    // Keyword-based category classifier for German grocery items
    static func classify(name: String) -> ItemCategory {
        let lower = name.lowercased()
        let rules: [(ItemCategory, [String])] = [
            (.dairy,     ["milch", "joghurt", "käse", "butter", "sahne", "quark", "kefir", "skyr"]),
            (.fruit,     ["apfel", "banane", "tomate", "salat", "gurke", "zwiebel", "karotte", "paprika", "spinat", "zucchini", "brokkoli", "orange", "zitrone", "erdbeere", "traube", "kirsche", "mango", "avocado"]),
            (.meat,      ["fleisch", "huhn", "hühnchen", "rind", "schwein", "hackfleisch", "lachs", "fisch", "thunfisch", "wurst", "schinken", "hähnchen"]),
            (.bakery,    ["brot", "brötchen", "toast", "croissant", "kuchen", "mehl", "hefe"]),
            (.frozen,    ["tiefkühl", "frozen", "eis"]),
            (.drinks,    ["wasser", "saft", "cola", "bier", "wein", "kaffee", "tee", "limonade", "sprudel"]),
            (.snacks,    ["chips", "schokolade", "keks", "bonbon", "nuss", "müsli", "riegel"]),
            (.pantryDry, ["nudeln", "pasta", "reis", "linsen", "bohnen", "öl", "essig", "salz", "zucker", "gewürz", "sauce", "ketchup", "senf", "mayonnaise", "mehl", "backpulver"]),
            (.cleaning,  ["spülmittel", "waschmittel", "putzmittel", "schwamm", "reiniger", "weichspüler"]),
            (.hygiene,   ["seife", "shampoo", "zahncreme", "zahnbürste", "deo", "rasierer", "lotion", "taschentuch"]),
            (.household, ["küchenpapier", "alufolie", "frischhalte", "müllbeutel", "glühbirne", "batterie"]),
            (.baby,      ["windel", "babynahrung", "babymilch"]),
            (.pet,       ["hundefutter", "katzenfutter", "tiernahrung"]),
        ]
        for (category, keywords) in rules {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }
}
