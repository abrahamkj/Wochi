# CLAUDE.md — Wochi Project Master Context

> This file is read automatically by Claude Code on every prompt.
> It is the single source of truth for the project. Never contradict it.

---

## 1. What is Wochi?

**Wochi** is a native iOS household intelligence app for Germany.
The name comes from **"Woche"** (German: week) + **"i"** (intelligence).
Tagline: *"Weekly Intelligence for your household."*

Wochi helps households manage their weekly grocery shopping smarter:
- Shared shopping lists across all household members
- Smart pantry tracking with expiry alerts
- Household budget dashboard from scanned receipts
- Smart substitution alerts based on weekly store flyers
- Voice input via Siri for frictionless item adding

It is built **iOS-native first**, targeting the German market, with plans to expand features and markets over time.

---

## 2. App Identity

| Property | Value |
|---|---|
| App Name | Wochi |
| Bundle ID | com.yourname.wochi |
| Platform | iOS 16+ (native Swift/SwiftUI) |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Minimum iOS | iOS 16.0 |
| Target Market | Germany (de-DE) |
| Monetization | Freemium — Free tier + Premium €2.99/month |
| App Store Category | Productivity / Lifestyle |

---

## 3. Core Principles

These principles guide every decision in this codebase:

1. **Offline-first** — The app must work fully without internet. Sync happens in the background.
2. **Privacy-first** — Receipt OCR runs on-device. No personal data sent to third-party servers without explicit user consent.
3. **Household-centric** — Everything is scoped to a Household, not an individual user. All shared data belongs to the Household.
4. **Native only** — Use Apple frameworks wherever possible. No third-party dependency if a native solution exists.
5. **Simplicity first** — Features ship simple. Complexity is added only when users ask for it.
6. **German market** — All default copy, store names, currency (€), and date formats target Germany.

---

## 4. Architecture Overview

```
Wochi iOS App
│
├── Presentation Layer (SwiftUI Views)
│   ├── Shopping List
│   ├── Pantry
│   ├── Budget Dashboard
│   ├── Substitution Alerts
│   └── Settings / Household Management
│
├── Domain Layer (Business Logic)
│   ├── Use Cases
│   └── Domain Models
│
├── Data Layer
│   ├── Local: SwiftData (CoreData successor)
│   ├── Sync: CloudKit (CKShare for household sharing)
│   └── Remote: Supabase (price/flyer data — read only)
│
└── System Integrations
    ├── App Intents (Siri voice add)
    ├── iOS Vision (receipt OCR)
    ├── Swift Charts (budget dashboard)
    ├── WidgetKit (home screen list widget)
    └── APNs + CloudKit push (notifications)
```

---

## 5. Data Storage Strategy

| Data Type | Storage | Sync |
|---|---|---|
| Shopping list items | SwiftData → CloudKit Shared DB | Real-time push |
| Pantry items | SwiftData → CloudKit Shared DB | Real-time push |
| Receipts | SwiftData → CloudKit Private DB | Per user |
| Budget records | Computed from receipts locally | N/A |
| Household metadata | CloudKit Shared DB | Real-time push |
| User preferences | SwiftData → CloudKit Private DB | Per device |
| Weekly flyer prices | Supabase (remote, read-only) | Weekly background fetch |
| Store catalog | Supabase + cached in SwiftData | On first launch + weekly |

---

## 6. Key Apple Frameworks Used

| Framework | Purpose |
|---|---|
| SwiftUI | All UI |
| SwiftData | Local persistence (replaces CoreData) |
| CloudKit (CKShare) | Household sharing and sync |
| Vision | On-device receipt OCR |
| App Intents | Siri integration ("Add milk to Wochi") |
| Swift Charts | Budget dashboard visualizations |
| WidgetKit | Home screen shopping list widget |
| APNs | Push notifications |
| MapKit | Store route optimization (Phase 3) |
| CoreLocation | Nearby store detection |

---

## 7. External Services

| Service | Purpose | When Used |
|---|---|---|
| Supabase | Weekly flyer price data + store catalog | Phase 2+ |
| Kaufda / Prospekt.de | Source of weekly store flyers (scraped into Supabase) | Phase 2+ |
| Apple CloudKit | Household sync | Phase 1 |

**No user PII is ever sent to Supabase.** Supabase only holds public price/store data.

---

## 8. Project File Structure

```
Wochi/
├── WochiApp.swift                  # App entry point
├── ContentView.swift               # Root view + tab navigation
│
├── Domain/
│   ├── Models/                     # Pure Swift structs (non-persistent)
│   └── UseCases/                   # Business logic
│
├── Data/
│   ├── SwiftData/
│   │   ├── Models/                 # SwiftData @Model classes
│   │   └── WochiDataContainer.swift
│   ├── CloudKit/
│   │   ├── CloudKitManager.swift
│   │   └── HouseholdShareManager.swift
│   ├── Supabase/
│   │   ├── SupabaseClient.swift
│   │   └── PriceRepository.swift
│   └── Repositories/
│       ├── ShoppingListRepository.swift
│       ├── PantryRepository.swift
│       ├── ReceiptRepository.swift
│       └── HouseholdRepository.swift
│
├── Features/
│   ├── Onboarding/
│   ├── ShoppingList/
│   ├── Pantry/
│   ├── Budget/
│   ├── Alerts/
│   └── Settings/
│
├── AppIntents/
│   └── AddItemIntent.swift         # Siri voice add
│
├── Widgets/
│   └── ShoppingListWidget.swift
│
├── Shared/
│   ├── Components/                 # Reusable SwiftUI views
│   ├── Extensions/
│   └── Constants.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings         # de + en
```

---

## 9. Coding Standards

- **Swift 5.9+** — use modern Swift features (macros, structured concurrency)
- **async/await** everywhere — no completion handlers
- **@MainActor** on all View Models
- **SwiftData @Model** for all persistent types
- **No force unwraps** — handle optionals safely
- **No third-party dependencies** in Phase 1 — only Apple frameworks
- **MVVM pattern** — Views observe ViewModels, ViewModels call Repositories
- **Preview-friendly** — all Views must have working #Preview macros
- Localization keys for all user-facing strings from day one
- German as default locale (de-DE), English as fallback

---

## 10. What Claude Code Should Never Do

- Never use UIKit directly — SwiftUI only
- Never add a third-party package without asking first
- Never store sensitive user data in Supabase
- Never hardcode strings visible to users — always use localization keys
- Never implement a feature not in FEATURES.md without confirming first
- Never skip error handling — all async calls must handle errors gracefully
- Never use deprecated APIs — iOS 16+ only

---

## 11. Current Phase

**Phase 1 — MVP (Months 1–3)**
Building for internal use (developer + household).
See PHASES.md for the exact build order.
See FEATURES.md for full feature specifications.
See ARCHITECTURE.md for data models and API contracts.
