<img src="Wochi/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" width="96" height="96" style="border-radius:22px" alt="Wochi App Icon" />

# Wochi

**Weekly Intelligence for your household.**

Wochi is a native iOS app for Germany that helps households manage their weekly grocery shopping smarter — shared lists, smart pantry tracking, budget dashboards from scanned receipts, and substitution alerts from weekly store flyers.

---

## Features

| Feature | Description |
|---|---|
| **Shared Shopping Lists** | Real-time shared lists across all household members via CloudKit |
| **Smart Pantry** | Track stock levels, expiry dates, and get low-stock alerts |
| **Budget Dashboard** | Scan receipts with on-device OCR — no data leaves your device |
| **Substitution Alerts** | Weekly flyer deals for products you actually buy |
| **Siri Shortcuts** | "Add milk to Wochi" — voice-first item adding |
| **Household Management** | Invite members, assign roles, manage access |

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Persistence | SwiftData |
| Sync | CloudKit (CKShare) |
| Receipt OCR | Apple Vision (on-device) |
| Price Data | Supabase (read-only, public data) |
| Voice | App Intents + Siri |
| Charts | Swift Charts |
| Widget | WidgetKit |

**No third-party dependencies.** Apple-native from top to bottom.

---

## Brand

### Colors

| Swatch | Name | Hex |
|---|---|---|
| 🟩 | Wochi Green | `#4CD88A` |
| 🟢 | Green Deep | `#2EB86A` |
| ⬛ | Wochi Dark | `#1A1A18` |
| 🟫 | Warm White | `#F2F0EB` |
| 🔘 | Muted | `#9A9589` |

### Logo

The Wochi mark is a **W that doubles as a house roofline** — the W's peaks become gable roofs, the valleys become doorways. Home + intelligence in a single geometric stroke. Available in the brand HTML at `Wochi/Resources/Assets.xcassets/AppIcon.appiconset/`.

---

## Architecture

```
Wochi/
├── WochiApp.swift              # App entry + SwiftData container
├── ContentView.swift           # Root tab navigation
│
├── Domain/
│   ├── Models/                 # WochiError, pure domain types
│   └── UseCases/               # ScanReceiptUseCase, ComputeBudgetUseCase
│
├── Data/
│   ├── SwiftData/Models/       # @Model classes (Household, ShoppingItem, PantryItem, Receipt…)
│   ├── CloudKit/               # CloudKitManager, HouseholdShareManager
│   ├── Supabase/               # PriceRepository (read-only flyer data)
│   └── Repositories/           # HouseholdRepository, ShoppingListRepository, PantryRepository…
│
├── Features/
│   ├── Onboarding/             # Sign-in, household create/join
│   ├── ShoppingList/           # Lists + items
│   ├── Pantry/                 # Inventory tracking
│   ├── Budget/                 # Dashboard + receipt scanning
│   ├── Alerts/                 # Substitution deal alerts
│   └── Settings/               # Household management, iCloud sync, Siri
│
├── AppIntents/                 # Siri "Add item" shortcut
├── Widgets/                    # Home screen shopping list widget
└── Resources/
    ├── Assets.xcassets         # App icon, brand colors
    ├── en.lproj/               # English localization
    └── de.lproj/               # German localization (primary)
```

---

## Core Principles

1. **Offline-first** — App works fully without internet; sync happens in background
2. **Privacy-first** — Receipt OCR runs on-device; no personal data sent to third parties
3. **Household-centric** — All shared data belongs to the Household, not the individual
4. **Native only** — Apple frameworks wherever possible; no third-party UI or networking
5. **German market** — Currency (€), date formats, and copy all target Germany by default

---

## Getting Started

### Requirements

- Xcode 15+
- iOS 16.0+ device or simulator
- Apple Developer account (for CloudKit + Siri entitlements)

### Setup

```bash
git clone https://github.com/abrahamkj/Wochi.git
cd Wochi
open Wochi.xcodeproj
```

1. Select your development team in **Signing & Capabilities**
2. Update the bundle ID from `com.yourname.wochi` to your own
3. Build and run on a device or simulator

> **Note:** CloudKit household sharing requires a physical device with an iCloud account signed in. The app runs fully offline on simulator — data persists locally via SwiftData.

---

## Localization

The app ships with full **German (de)** and **English (en)** localization. German is the primary locale (target market). All user-facing strings use `Localizable.strings` keys — never hardcoded text.

To add a new language, duplicate either `.lproj` folder and translate the `.strings` file.

---

## Roadmap

| Phase | Status | Scope |
|---|---|---|
| Phase 1 — MVP | 🚧 In Progress | Shopping lists, pantry, receipt scanning, household management |
| Phase 2 — Smart | 📋 Planned | Supabase flyer data, substitution alerts, price comparison |
| Phase 3 — Expand | 📋 Planned | Store route optimization, widgets, Apple Watch |

---

## License

Private — all rights reserved. Not open for redistribution.

---

*Built with Swift, SwiftUI, and ♥ for households that want to shop smarter.*
