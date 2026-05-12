# ARCHITECTURE.md — Wochi Data Models & API Contracts

---

## 1. SwiftData Models

All persistent models use SwiftData `@Model` macro.
CloudKit sync is enabled via `ModelConfiguration` with `cloudKitContainerIdentifier`.

---

### 1.1 Household

The central entity. Everything in the app belongs to a Household.

```swift
@Model
final class Household {
    @Attribute(.unique) var id: UUID
    var name: String                        // e.g. "Müller Family", "WG Stuttgart"
    var createdAt: Date
    var updatedAt: Date
    var currency: String                    // Default: "EUR"
    var countryCode: String                 // Default: "DE"
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var members: [HouseholdMember]
    
    @Relationship(deleteRule: .cascade)
    var shoppingLists: [ShoppingList]
    
    @Relationship(deleteRule: .cascade)
    var pantryItems: [PantryItem]
    
    @Relationship(deleteRule: .cascade)
    var receipts: [Receipt]
    
    @Relationship(deleteRule: .cascade)
    var preferredStores: [PreferredStore]
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currency = "EUR"
        self.countryCode = "DE"
        self.members = []
        self.shoppingLists = []
        self.pantryItems = []
        self.receipts = []
        self.preferredStores = []
    }
}
```

---

### 1.2 HouseholdMember

A user who belongs to a household.

```swift
@Model
final class HouseholdMember {
    @Attribute(.unique) var id: UUID
    var appleUserID: String                 // From CloudKit / Sign in with Apple
    var displayName: String
    var email: String?
    var avatarColor: String                 // Hex color for avatar placeholder
    var role: MemberRole
    var joinedAt: Date
    var isCurrentDevice: Bool              // True only on this user's device
    
    // Relationship
    var household: Household?
    
    init(appleUserID: String, displayName: String, role: MemberRole = .member) {
        self.id = UUID()
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.role = role
        self.joinedAt = Date()
        self.avatarColor = MemberRole.randomAvatarColor()
        self.isCurrentDevice = false
    }
}

enum MemberRole: String, Codable {
    case owner      // Can delete household, manage all members
    case admin      // Can invite/remove members
    case member     // Can add/edit lists and pantry
    case viewer     // Read-only access
    
    static func randomAvatarColor() -> String {
        let colors = ["#4ade80", "#60a5fa", "#f87171", "#fbbf24", "#a78bfa", "#34d399"]
        return colors.randomElement() ?? "#4ade80"
    }
}
```

---

### 1.3 ShoppingList

A household can have multiple lists (e.g. "Weekly Groceries", "Baumarkt", "IKEA").

```swift
@Model
final class ShoppingList {
    @Attribute(.unique) var id: UUID
    var name: String                        // e.g. "Wochenmarkt", "IKEA Trip"
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool                    // Archived after shopping trip
    var sortOrder: Int
    
    // Relationships
    var household: Household?
    
    @Relationship(deleteRule: .cascade)
    var items: [ShoppingItem]
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isArchived = false
        self.sortOrder = 0
        self.items = []
    }
    
    // Computed
    var pendingItems: [ShoppingItem] {
        items.filter { !$0.isChecked }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var checkedItems: [ShoppingItem] {
        items.filter { $0.isChecked }
    }
    
    var totalEstimatedCost: Double {
        items.compactMap { $0.estimatedPrice }.reduce(0, +)
    }
}
```

---

### 1.4 ShoppingItem

An item on a shopping list.

```swift
@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String                        // e.g. "Milch"
    var quantity: Double                    // e.g. 2
    var unit: String?                       // e.g. "Liter", "kg", "Stück"
    var preferredBrand: String?             // e.g. "Barilla", "Alpro"
    var brandTier: BrandPreference          // .preferred / .acceptable / .never
    var category: ItemCategory              // Auto-classified
    var note: String?                       // e.g. "Bio wenn möglich"
    var estimatedPrice: Double?             // From flyer data
    var suggestedStore: String?             // e.g. "Kaufland"
    var isChecked: Bool
    var checkedAt: Date?
    var sortOrder: Int
    var addedAt: Date
    var addedByMemberID: UUID?
    var checkedByMemberID: UUID?
    var sourceType: ItemSourceType          // .manual / .voice / .pantryAlert / .recurring
    
    // Relationship
    var list: ShoppingList?
    
    init(name: String, quantity: Double = 1, unit: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.brandTier = .acceptable
        self.category = .other
        self.isChecked = false
        self.sortOrder = 0
        self.addedAt = Date()
        self.sourceType = .manual
    }
}

enum BrandPreference: String, Codable {
    case preferred      // Always buy this brand
    case acceptable     // OK if preferred not available
    case never          // Never suggest this brand
}

enum ItemSourceType: String, Codable {
    case manual         // User typed it
    case voice          // Added via Siri
    case pantryAlert    // Added because pantry ran low
    case recurring      // Part of a recurring template
    case receiptScan    // Detected from previous receipt
}

enum ItemCategory: String, Codable, CaseIterable {
    case fruit          = "Obst & Gemüse"
    case dairy          = "Milchprodukte"
    case meat           = "Fleisch & Fisch"
    case bakery         = "Brot & Backwaren"
    case frozen         = "Tiefkühl"
    case drinks         = "Getränke"
    case snacks         = "Snacks & Süßes"
    case pantryDry      = "Vorrat"
    case cleaning       = "Putzmittel"
    case hygiene        = "Hygiene"
    case household      = "Haushalt"
    case baby           = "Baby"
    case pet            = "Tier"
    case other          = "Sonstiges"
}
```

---

### 1.5 PantryItem

Tracks what the household currently has at home.

```swift
@Model
final class PantryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double
    var unit: String?
    var category: ItemCategory
    var brand: String?
    var barcode: String?                    // EAN barcode for scanning
    var expiryDate: Date?
    var openedDate: Date?                   // When was it opened?
    var lowStockThreshold: Double           // Alert when below this
    var addedAt: Date
    var lastUpdatedAt: Date
    var lastUpdatedByMemberID: UUID?
    var imageData: Data?                    // Optional product photo
    var notes: String?
    
    // Relationship
    var household: Household?
    
    init(name: String, quantity: Double = 1, unit: String? = nil) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = .other
        self.lowStockThreshold = 1
        self.addedAt = Date()
        self.lastUpdatedAt = Date()
    }
    
    // Computed
    var isLowStock: Bool {
        quantity <= lowStockThreshold
    }
    
    var isExpiringSoon: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry <= Date().addingTimeInterval(3 * 24 * 60 * 60) // 3 days
    }
    
    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }
    
    var daysUntilExpiry: Int? {
        guard let expiry = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
    }
}
```

---

### 1.6 Receipt

A scanned store receipt.

```swift
@Model
final class Receipt {
    @Attribute(.unique) var id: UUID
    var storeName: String                   // e.g. "Kaufland", "Lidl"
    var storeAddress: String?
    var purchaseDate: Date
    var totalAmount: Double
    var currency: String                    // Default: "EUR"
    var scannedAt: Date
    var scannedByMemberID: UUID?
    var rawOCRText: String?                 // Raw text from Vision framework
    var imageData: Data?                    // Receipt photo (optional, stored locally)
    var isVerified: Bool                    // User confirmed the scan was accurate
    
    // Relationships
    var household: Household?
    
    @Relationship(deleteRule: .cascade)
    var items: [ReceiptItem]
    
    init(storeName: String, purchaseDate: Date, totalAmount: Double) {
        self.id = UUID()
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.currency = "EUR"
        self.scannedAt = Date()
        self.isVerified = false
        self.items = []
    }
    
    // Computed
    var month: Int { Calendar.current.component(.month, from: purchaseDate) }
    var year: Int { Calendar.current.component(.year, from: purchaseDate) }
}
```

---

### 1.7 ReceiptItem

An individual line item from a scanned receipt.

```swift
@Model
final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String                        // As read from receipt
    var normalizedName: String?             // Cleaned up name for matching
    var brand: String?
    var quantity: Double
    var unit: String?
    var unitPrice: Double
    var totalPrice: Double
    var category: ItemCategory
    var isDiscounted: Bool
    var originalPrice: Double?              // Before discount
    
    // Relationship
    var receipt: Receipt?
    
    // Link to pantry item if matched
    var matchedPantryItemID: UUID?
    
    init(name: String, quantity: Double, unitPrice: Double, totalPrice: Double) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
        self.category = .other
        self.isDiscounted = false
    }
}
```

---

### 1.8 BudgetRecord

Monthly aggregated spending — computed from receipts, not stored directly.
This is a computed value object, not a SwiftData model.

```swift
struct BudgetRecord {
    let month: Int
    let year: Int
    let householdID: UUID
    let totalSpent: Double
    let currency: String
    
    let byStore: [StoreSpend]
    let byCategory: [CategorySpend]
    let byMember: [MemberSpend]
    let receiptCount: Int
    
    struct StoreSpend: Identifiable {
        let id = UUID()
        let storeName: String
        let amount: Double
        let percentage: Double
        let receiptCount: Int
    }
    
    struct CategorySpend: Identifiable {
        let id = UUID()
        let category: ItemCategory
        let amount: Double
        let percentage: Double
    }
    
    struct MemberSpend: Identifiable {
        let id = UUID()
        let memberID: UUID
        let memberName: String
        let amount: Double
        let receiptCount: Int
    }
}
```

---

### 1.9 PreferredStore

Stores the household prefers to shop at.

```swift
@Model
final class PreferredStore {
    @Attribute(.unique) var id: UUID
    var storeChain: StoreChain             // e.g. .kaufland, .lidl
    var customName: String?                // Optional custom label
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
        case .kaufland: return "#E30613"
        case .lidl:     return "#0050AA"
        case .rewe:     return "#CC0000"
        case .edeka:    return "#FFD700"
        case .aldi:     return "#003C88"
        case .penny:    return "#CC0000"
        case .netto:    return "#FFD700"
        case .dm:       return "#D40511"
        case .rossmann: return "#E30613"
        case .other:    return "#888888"
        }
    }
}
```

---

### 1.10 SubstitutionAlert

A deal alert for a product the household regularly buys.

```swift
@Model
final class SubstitutionAlert {
    @Attribute(.unique) var id: UUID
    var productName: String
    var preferredBrand: String?
    var currentStore: StoreChain
    var dealStore: StoreChain
    var regularPrice: Double
    var dealPrice: Double
    var savingsPercent: Double
    var validFrom: Date
    var validUntil: Date
    var flyerImageURL: String?
    var isRead: Bool
    var isDismissed: Bool
    var createdAt: Date
    
    var household: Household?
    
    init(productName: String, dealStore: StoreChain, regularPrice: Double, dealPrice: Double, validUntil: Date) {
        self.id = UUID()
        self.productName = productName
        self.currentStore = .kaufland
        self.dealStore = dealStore
        self.regularPrice = regularPrice
        self.dealPrice = dealPrice
        self.savingsPercent = ((regularPrice - dealPrice) / regularPrice) * 100
        self.validFrom = Date()
        self.validUntil = validUntil
        self.isRead = false
        self.isDismissed = false
        self.createdAt = Date()
    }
    
    var isActive: Bool {
        Date() >= validFrom && Date() <= validUntil
    }
    
    var savingsAmount: Double {
        regularPrice - dealPrice
    }
}
```

---

## 2. CloudKit Schema

### Container Setup

```
Container ID: iCloud.com.yourname.wochi

Zones:
├── _defaultZone (private)          ← Per-user data (receipts, device prefs)
└── WochiHousehold-{householdID}    ← Shared zone per household (lists, pantry, alerts)
```

### Sharing Flow

```swift
// 1. Owner creates a CKShare for their household zone
// 2. CKShare generates a shareable URL
// 3. URL sent via iOS share sheet (iMessage, WhatsApp, etc.)
// 4. Recipient taps → app opens → accepts share
// 5. CloudKit adds them to the shared zone
// 6. SwiftData automatically syncs their local store
```

### Member Limits
- CloudKit CKShare supports up to **10 participants** per share
- Sufficient for any household use case

---

## 3. Supabase Schema (Remote — Price Data Only)

**Important:** Supabase holds ONLY public market data. Zero user PII.

```sql
-- Stores directory
CREATE TABLE stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chain VARCHAR(50) NOT NULL,          -- 'kaufland', 'lidl', etc.
    name VARCHAR(100) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    postal_code VARCHAR(10),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    country_code CHAR(2) DEFAULT 'DE',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Product catalog (normalized product names)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    brand VARCHAR(100),
    category VARCHAR(50),
    barcode VARCHAR(20),
    unit VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Weekly flyer prices
CREATE TABLE flyer_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_chain VARCHAR(50) NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    brand VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    unit VARCHAR(20),
    unit_price DECIMAL(10, 4),           -- Price per 100g/100ml etc.
    is_discounted BOOLEAN DEFAULT FALSE,
    original_price DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2),
    valid_from DATE NOT NULL,
    valid_until DATE NOT NULL,
    flyer_page_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_flyer_prices_chain ON flyer_prices(store_chain);
CREATE INDEX idx_flyer_prices_valid ON flyer_prices(valid_from, valid_until);
CREATE INDEX idx_flyer_prices_product ON flyer_prices(product_name);
```

---

## 4. Repository Interfaces

All data access goes through repositories. Views never touch SwiftData or CloudKit directly.

```swift
// Shopping List
protocol ShoppingListRepositoryProtocol {
    func fetchAllLists(for household: Household) async throws -> [ShoppingList]
    func createList(name: String, in household: Household) async throws -> ShoppingList
    func addItem(_ item: ShoppingItem, to list: ShoppingList) async throws
    func updateItem(_ item: ShoppingItem) async throws
    func checkOffItem(_ item: ShoppingItem, by member: HouseholdMember) async throws
    func deleteItem(_ item: ShoppingItem) async throws
    func archiveList(_ list: ShoppingList) async throws
}

// Pantry
protocol PantryRepositoryProtocol {
    func fetchAllItems(for household: Household) async throws -> [PantryItem]
    func addItem(_ item: PantryItem, to household: Household) async throws
    func updateItem(_ item: PantryItem) async throws
    func deleteItem(_ item: PantryItem) async throws
    func fetchExpiringItems(within days: Int, for household: Household) async throws -> [PantryItem]
    func fetchLowStockItems(for household: Household) async throws -> [PantryItem]
}

// Receipt
protocol ReceiptRepositoryProtocol {
    func saveReceipt(_ receipt: Receipt, for household: Household) async throws
    func fetchReceipts(for household: Household, month: Int, year: Int) async throws -> [Receipt]
    func fetchAllReceipts(for household: Household) async throws -> [Receipt]
    func deleteReceipt(_ receipt: Receipt) async throws
}

// Household
protocol HouseholdRepositoryProtocol {
    func fetchCurrentHousehold() async throws -> Household?
    func createHousehold(name: String) async throws -> Household
    func inviteMember(to household: Household) async throws -> URL  // Returns share URL
    func removeMember(_ member: HouseholdMember, from household: Household) async throws
    func updateMemberRole(_ member: HouseholdMember, role: MemberRole) async throws
    func leaveHousehold(_ household: Household) async throws
}

// Budget (computed — no direct storage)
protocol BudgetRepositoryProtocol {
    func fetchBudgetRecord(for household: Household, month: Int, year: Int) async throws -> BudgetRecord
    func fetchBudgetHistory(for household: Household, months: Int) async throws -> [BudgetRecord]
}

// Price Data (from Supabase)
protocol PriceRepositoryProtocol {
    func fetchCurrentFlyers(for stores: [StoreChain]) async throws -> [FlyerPrice]
    func findBestPrice(for productName: String, in stores: [StoreChain]) async throws -> [FlyerPrice]
    func checkForDeals(items: [ShoppingItem], stores: [StoreChain]) async throws -> [SubstitutionAlert]
}
```

---

## 5. OCR Receipt Parsing Flow

```
User taps "Scan Receipt"
        ↓
Camera opens (SwiftUI fullscreen)
        ↓
User photographs receipt
        ↓
VNRecognizeTextRequest (iOS Vision)
  - runs on-device
  - recognitionLevel: .accurate
  - recognitionLanguages: ["de-DE", "en-US"]
        ↓
Raw text → ReceiptParser.parse(text:)
  - Regex patterns for German receipt formats
  - Extracts: store name, date, items, prices, total
  - Handles: Kaufland, Lidl, REWE, Edeka formats
        ↓
ReceiptReviewView (user confirms/edits)
        ↓
Confirmed receipt → ReceiptRepository.saveReceipt()
        ↓
Pantry auto-update (optional prompt)
Budget record invalidated → recomputed
```

---

## 6. Siri / App Intents Flow

```swift
// User says: "Hey Siri, add Milch to Wochi"
// or: "Hey Siri, add milk to my shopping list in Wochi"

struct AddItemToWochiIntent: AppIntent {
    static var title: LocalizedStringResource = "Add item to Wochi"
    static var description: IntentDescription = "Adds an item to your Wochi shopping list"
    
    @Parameter(title: "Item")
    var itemName: String
    
    @Parameter(title: "Quantity", default: 1)
    var quantity: Double
    
    @Parameter(title: "List", optionsProvider: ShoppingListOptionsProvider())
    var listName: String?
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Fetch household's active shopping list
        // 2. Create ShoppingItem with sourceType: .voice
        // 3. Add to list via repository
        // 4. Sync via CloudKit
        return .result(dialog: "'\(itemName)' wurde zu deiner Einkaufsliste hinzugefügt.")
    }
}
```

---

## 7. Budget Computation Logic

Budget records are never stored — always computed fresh from receipts.

```swift
func computeBudgetRecord(
    for household: Household,
    month: Int,
    year: Int,
    receipts: [Receipt]
) -> BudgetRecord {
    
    let filtered = receipts.filter {
        $0.month == month && $0.year == year
    }
    
    let total = filtered.reduce(0) { $0 + $1.totalAmount }
    
    // By store
    let byStore = Dictionary(grouping: filtered, by: \.storeName)
        .map { storeName, receipts in
            BudgetRecord.StoreSpend(
                storeName: storeName,
                amount: receipts.reduce(0) { $0 + $1.totalAmount },
                percentage: receipts.reduce(0) { $0 + $1.totalAmount } / total * 100,
                receiptCount: receipts.count
            )
        }
        .sorted { $0.amount > $1.amount }
    
    // By category (from receipt items)
    let allItems = filtered.flatMap { $0.items }
    let byCategory = Dictionary(grouping: allItems, by: \.category)
        .map { category, items in
            BudgetRecord.CategorySpend(
                category: category,
                amount: items.reduce(0) { $0 + $1.totalPrice },
                percentage: items.reduce(0) { $0 + $1.totalPrice } / total * 100
            )
        }
        .sorted { $0.amount > $1.amount }
    
    // By member
    let byMember = Dictionary(grouping: filtered, by: \.scannedByMemberID)
        .compactMap { memberID, receipts -> BudgetRecord.MemberSpend? in
            guard let memberID else { return nil }
            let member = household.members.first { $0.id == memberID }
            return BudgetRecord.MemberSpend(
                memberID: memberID,
                memberName: member?.displayName ?? "Unknown",
                amount: receipts.reduce(0) { $0 + $1.totalAmount },
                receiptCount: receipts.count
            )
        }
        .sorted { $0.amount > $1.amount }
    
    return BudgetRecord(
        month: month,
        year: year,
        householdID: household.id,
        totalSpent: total,
        currency: household.currency,
        byStore: byStore,
        byCategory: byCategory,
        byMember: byMember,
        receiptCount: filtered.count
    )
}
```

---

## 8. Notification Types

| Notification ID | Trigger | Content |
|---|---|---|
| `pantry.expiry` | 3 days before expiry date | "⚠️ [Item] läuft in 3 Tagen ab" |
| `pantry.lowStock` | Quantity ≤ threshold | "📦 [Item] ist fast aufgebraucht" |
| `list.itemAdded` | Another member adds item | "[Name] hat [Item] zur Liste hinzugefügt" |
| `list.itemChecked` | Another member checks off item | "[Name] hat [Item] gekauft ✓" |
| `alert.deal` | New deal for tracked product | "🏷️ [Item] ist diese Woche günstiger bei [Store]" |
| `budget.monthly` | 1st of each month | "📊 Deine Ausgaben im [Monat]: €[amount]" |

---

## 9. Error Handling Strategy

```swift
enum WochiError: LocalizedError {
    case networkUnavailable
    case cloudKitSyncFailed(underlying: Error)
    case receiptParsingFailed
    case householdNotFound
    case unauthorized
    case supabaseFetchFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Keine Internetverbindung. Deine Daten werden synchronisiert, sobald du wieder online bist."
        case .cloudKitSyncFailed:
            return "Synchronisierung fehlgeschlagen. Bitte prüfe deine iCloud-Einstellungen."
        case .receiptParsingFailed:
            return "Der Kassenbon konnte nicht gelesen werden. Bitte versuche es erneut."
        case .householdNotFound:
            return "Haushalt nicht gefunden. Bitte erstelle einen neuen Haushalt."
        case .unauthorized:
            return "Du hast keine Berechtigung für diese Aktion."
        case .supabaseFetchFailed:
            return "Preisdaten konnten nicht geladen werden. Bitte versuche es später erneut."
        }
    }
}
```
