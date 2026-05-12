# PHASES.md — Wochi Build Order & Claude Code Prompts

This file tells you exactly what to build, in what order, and gives you
the exact prompt to use with Claude Code for each step.

**Rule:** Never start a step until the previous step is working and tested.
**Rule:** Always read CLAUDE.md before each Claude Code session.

---

## PHASE 1 — MVP (Months 1–3)
Goal: A working app for your own household. You and your household members use it daily.

---

### STEP 1.1 — Xcode Project Setup

**What to do manually (not Claude Code):**
1. Create new Xcode project
   - Template: App
   - Product Name: Wochi
   - Bundle ID: com.yourname.wochi
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData ✓
   - Include Tests ✓
2. Add iCloud capability → CloudKit → container: iCloud.com.yourname.wochi
3. Add Push Notifications capability
4. Add Background Modes capability → Remote notifications + Background fetch
5. Set minimum deployment: iOS 16.0
6. Drop CLAUDE.md, ARCHITECTURE.md, FEATURES.md, PHASES.md into project root (not in Xcode, just in folder)

---

### STEP 1.2 — Data Models

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md.

Create all SwiftData @Model classes for the Wochi app. 

Create the following files in the Data/SwiftData/Models/ folder:
- Household.swift
- HouseholdMember.swift  
- ShoppingList.swift
- ShoppingItem.swift
- PantryItem.swift
- Receipt.swift
- ReceiptItem.swift
- PreferredStore.swift
- SubstitutionAlert.swift

Also create:
- Data/SwiftData/WochiDataContainer.swift — sets up ModelContainer with CloudKit sync enabled
- Shared/Constants.swift — app-wide constants

Use exactly the models defined in ARCHITECTURE.md section 1.
Enable CloudKit sync via ModelConfiguration with cloudKitContainerIdentifier.
Add #Preview-compatible sample data as static factory methods on each model.
Do not create any UI yet.
```

**Done when:** Project compiles with zero errors. All models visible in schema.

---

### STEP 1.3 — Repositories

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md.

Implement the repository layer for Wochi.

Create these files in Data/Repositories/:
- ShoppingListRepository.swift
- PantryRepository.swift  
- ReceiptRepository.swift
- HouseholdRepository.swift
- BudgetRepository.swift

Each repository must:
- Conform to its protocol defined in ARCHITECTURE.md section 4
- Use SwiftData ModelContext for all operations
- Use async/await (no completion handlers)
- Handle errors with WochiError enum from ARCHITECTURE.md section 9
- Be injectable (accept ModelContext in init)

Also create Domain/UseCases/ with:
- AddItemToListUseCase.swift
- CheckOffItemUseCase.swift
- ScanReceiptUseCase.swift (stub — Vision integration comes in Step 1.7)
- ComputeBudgetUseCase.swift — implements the budget computation logic from ARCHITECTURE.md section 7

Do not create any UI yet.
```

**Done when:** All repositories compile. Write unit tests for ComputeBudgetUseCase.

---

### STEP 1.4 — App Structure & Navigation

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md.

Create the main app navigation structure for Wochi.

Create:
- WochiApp.swift — app entry point, injects ModelContainer
- ContentView.swift — TabView with 4 tabs:
  * Tab 1: Shopping List (cart icon)
  * Tab 2: Pantry (house icon)
  * Tab 3: Budget (chart.bar icon)
  * Tab 4: Settings (gear icon)

Create placeholder views for each tab (just a Text with tab name).

Create Features/Onboarding/:
- OnboardingView.swift — 3-slide carousel (F-01)
- SignInView.swift — Sign in with Apple button (F-02), use AuthenticationServices framework
- HouseholdSetupView.swift — Create or Join household choice screen (F-03)

Logic:
- On first launch: show OnboardingView
- After sign-in: show HouseholdSetupView  
- After household setup: show ContentView (TabView)
- Store onboarding completion in UserDefaults

Use SwiftUI animations for slide transitions.
All strings must use LocalizedStringKey — create Localizable.strings with de and en entries.
```

**Done when:** App launches, shows onboarding, can navigate to tab view.

---

### STEP 1.5 — CloudKit Household Sharing

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md section 2.

Implement CloudKit household sharing in Wochi.

Create Data/CloudKit/:
- CloudKitManager.swift — manages CloudKit container and sync status
- HouseholdShareManager.swift — handles CKShare creation and acceptance

Implement in HouseholdRepository:
- createHousehold(name:) — creates Household + CKShare zone
- inviteMember(to:) — generates CKShare URL, returns it for sharing
- acceptInvite(from url:) — accepts CKShare, joins household zone
- leaveHousehold(_:) — removes from CKShare participants

In Features/Settings/ create:
- HouseholdManagementView.swift — member list, invite button, leave option (F-70, F-71, F-72, F-73)
- InviteMemberView.swift — generates link, shows share sheet

Handle the wochi:// URL scheme for deep link invite acceptance.
Add URL scheme to Info.plist.
Show sync status indicator (F-82) in Settings tab.
```

**Done when:** Two devices/simulators can join the same household and see shared data.

---

### STEP 1.6 — Shopping List Feature

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md MODULE 2 (F-10 through F-14).

Implement the complete Shopping List feature for Wochi.

Create in Features/ShoppingList/:
- ShoppingListsView.swift — list of all household lists (F-10)
- ShoppingListDetailView.swift — items in a list (F-11)  
- AddItemView.swift — bottom sheet to add item (F-12)
- EditItemView.swift — full edit screen (F-13)
- ShoppingListViewModel.swift — @MainActor ViewModel

Requirements:
- Real-time updates from CloudKit push
- Check-off animation (strikethrough + fade)
- Items grouped by ItemCategory with section headers (toggleable)
- Swipe actions: check off, delete, edit
- Show member avatar next to item (who added it)
- "Alle erledigten löschen" confirmation sheet
- Archive list (F-14)
- Auto-complete suggestions when typing item name
- Offline indicator badge when no CloudKit sync

Localize all strings in de/en.
All views must have working #Preview macros with sample data.
```

**Done when:** Can create lists, add/edit/delete items, check them off, archive list. Two members see same data in real-time.

---

### STEP 1.7 — Receipt Scanning (OCR)

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md section 5, and FEATURES.md MODULE 5 (F-40, F-41).

Implement receipt scanning with on-device OCR.

Create in Features/Budget/Scanning/:
- ReceiptCameraView.swift — fullscreen camera with guide overlay (F-40)
- ReceiptReviewView.swift — parsed result review and edit (F-41)
- ReceiptParser.swift — parses Vision OCR output into structured data

ReceiptParser requirements:
- Input: raw String from VNRecognizeTextRequest
- Output: parsed Receipt with items
- Must handle German receipt formats for: Kaufland, Lidl, REWE, Edeka
- Extract: store name, date (German format dd.MM.yyyy), items (name + price), total
- Use regex for price patterns: German format uses comma as decimal (e.g. "1,99 €")
- Store name detection from known German chain names
- Graceful failure: return partial result if some fields can't be parsed

Vision setup:
- VNRecognizeTextRequest with recognitionLevel: .accurate
- recognitionLanguages: ["de-DE", "en-US"]  
- Run on background thread, publish results on MainActor

After receipt saved:
- Offer pantry update (F-22) — show items with checkboxes
- Refresh budget data

All OCR runs on-device. Never send receipt images or text to any server.
```

**Done when:** Can photograph a German supermarket receipt and get reasonable item extraction. Manual correction works.

---

### STEP 1.8 — Pantry Tracker

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md MODULE 3 (F-20 through F-25).

Implement the Pantry Tracker feature.

Create in Features/Pantry/:
- PantryView.swift — main pantry list with categories (F-20)
- AddPantryItemView.swift — add item manually + barcode scan (F-21)
- EditPantryItemView.swift — edit item, quick "Aufgebraucht" action (F-23)
- PantryViewModel.swift — @MainActor ViewModel
- BarcodeScanner.swift — wraps AVFoundation for EAN barcode reading

Notification scheduling (F-24, F-25):
- Create NotificationManager.swift
- Schedule local notifications for expiry (3 days before + on day)
- Schedule local notification for low stock (on quantity update)
- Request notification permission on first use
- "Zur Liste hinzufügen" notification action button

Filters:
- "Ablaufend" chip — shows only expiring/expired items
- "Wenig vorrätig" chip — shows only low stock items
- Search bar with live filtering

Visual indicators:
- 🟢 OK (quantity > threshold, not expiring)
- 🟡 Low stock (quantity ≤ threshold)
- 🟠 Expiring soon (≤ 3 days)
- 🔴 Expired

All views must have working #Preview macros.
```

**Done when:** Can add/edit/delete pantry items. Notifications fire correctly for expiry and low stock.

---

### STEP 1.9 — Budget Dashboard

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md MODULE 4 (F-30 through F-34).

Implement the Budget Dashboard feature.

Create in Features/Budget/:
- BudgetView.swift — main dashboard with month selector (F-30)
- StoreBreakdownView.swift — horizontal bars per store (F-31)
- CategoryBreakdownView.swift — donut chart (F-32)
- MemberBreakdownView.swift — per-member spending (F-33)
- ReceiptHistoryView.swift — list of receipts (F-34)
- ReceiptDetailView.swift — full receipt line items
- BudgetViewModel.swift — @MainActor ViewModel

Use Swift Charts for all visualizations:
- Store breakdown: BarChart horizontal
- Category breakdown: SectorChart (donut)
- Month-over-month: LineChart (shown on main view)

Month selector: ← [Monat Jahr] → navigation
Compare to last month: show +/-% with color (green = less, red = more)

BudgetRepository.fetchBudgetRecord() uses computation logic from ARCHITECTURE.md section 7.
Results cached in ViewModel — recompute when new receipt saved.

Receipt row: store name/logo color, date formatted as "dd. MMMM yyyy", total "€ X,XX"
Swipe to delete receipt with confirmation — updates budget immediately.

All amounts formatted with German locale (€ 1.234,56 format).
```

**Done when:** Dashboard shows accurate spending breakdown. Charts render correctly. Month navigation works.

---

### STEP 1.10 — Siri Voice Input

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md section 6, and FEATURES.md MODULE 7 (F-60, F-61, F-62).

Implement Siri integration via App Intents framework.

Create in AppIntents/:
- AddItemIntent.swift — AppIntent to add item to shopping list (F-60, F-61)
- WochiShortcuts.swift — AppShortcutsProvider for suggested shortcuts (F-62)

AddItemIntent requirements:
- Title: "Artikel zu Wochi hinzufügen"
- Parameters: itemName (String), quantity (Double, default 1), unit (String?, optional)
- Natural language variations: 
  * "Add [item] to Wochi"
  * "Füge [item] zu Wochi hinzu"
  * "Wochi [item] hinzufügen"
- Performs() function:
  1. Fetches current household's primary active list
  2. Creates ShoppingItem with sourceType: .voice
  3. Saves via ShoppingListRepository
  4. Returns IntentResult with dialog confirmation in German
- Works when app is not open (background execution)

WochiShortcuts:
- Register 3 suggested shortcuts shown in Settings and Shortcuts app
- "Zur Liste hinzufügen"
- "Wochi Liste anzeigen"  
- "Vorräte prüfen"

Add in Features/Settings/:
- SiriShortcutsView.swift — shows available shortcuts with setup instructions

Test: invoke via Siri on device. Item should appear on list for all household members.
```

**Done when:** "Hey Siri, add Milch to Wochi" adds milk to the active list and other members see it.

---

### STEP 1.11 — Polish & Internal Launch

**Claude Code Prompt:**
```
Read CLAUDE.md.

Polish the Wochi app for internal use (Phase 1 completion).

1. App Icon:
   - Create AppIcon assets — simple "W" lettermark on green (#4ade80) background
   - All required sizes for iOS

2. Launch Screen:
   - Wochi wordmark centered on dark background
   - Subtle fade-in animation

3. Empty States:
   - Every list/grid view needs an empty state
   - Illustration (SF Symbols based) + title + subtitle + action button
   - Shopping: "Noch keine Artikel" + "Ersten Artikel hinzufügen"
   - Pantry: "Dein Vorrat ist leer" + "Ersten Artikel hinzufügen"
   - Budget: "Noch kein Kassenbon" + "Ersten Kassenbon scannen"
   - Alerts: "Keine aktuellen Angebote"

4. Error Handling:
   - Implement WochiError display (toast/banner style, not modal)
   - CloudKit offline banner at top of screen when disconnected
   - Retry mechanisms for failed sync

5. Haptic Feedback:
   - Check off item: UIImpactFeedbackGenerator .medium
   - Delete item: UINotificationFeedbackGenerator .warning
   - Receipt saved: UINotificationFeedbackGenerator .success

6. Accessibility:
   - VoiceOver labels on all interactive elements
   - Dynamic Type support on all text
   - Sufficient color contrast (WCAG AA)

7. German localization review:
   - All strings in Localizable.strings
   - Correct German plural forms
   - Date/currency formatted with de-DE locale everywhere
```

**Done when:** App used by developer's household for 2 weeks with no crashes.

---

## PHASE 2 — Beta (Months 4–6)
Goal: 10–20 test households. Real user feedback.

### STEP 2.1 — Supabase Setup & Flyer Price Integration

**Claude Code Prompt:**
```
Read CLAUDE.md and ARCHITECTURE.md sections 3 and 7.

Implement remote price data fetching from Supabase.

Create Data/Supabase/:
- SupabaseClient.swift — URLSession-based client (no third-party SDK)
- PriceRepository.swift — implements PriceRepositoryProtocol
- FlyerPrice.swift — Codable struct matching Supabase flyer_prices table

PriceRepository methods:
- fetchCurrentFlyers(for stores:) — GET /flyer_prices?valid_until=gte.{today}
- findBestPrice(for productName:, in stores:) — fuzzy match by name
- checkForDeals(items:, stores:) — batch check, returns [SubstitutionAlert]

Caching:
- Cache flyer data in SwiftData (FlyerCache model — create it)
- Refresh only if cache is older than 24 hours
- Fetch in background (BackgroundTasks framework)
- Register BGAppRefreshTask with identifier: com.yourname.wochi.flyer-refresh

Background refresh:
- Schedules weekly (every 7 days, Monday morning)
- On completion: generate SubstitutionAlerts for household
- Send push notification if new deals found
```

---

### STEP 2.2 — Substitution Alerts Feature

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md MODULE 6 (F-50 through F-53).

Implement the Substitution Alerts feature.

Create in Features/Alerts/:
- AlertsView.swift — list of active alerts (F-50)
- AlertDetailView.swift — full deal detail with store info
- AlertsViewModel.swift — @MainActor ViewModel

Alert card shows:
- Product name
- Regular store logo + price
- →
- Deal store logo + deal price
- Savings badge: "-35%" in green
- Valid until: "noch 3 Tage"

Alert generation (F-51):
- Triggered after flyer refresh completes
- Implement in AlertGenerationService.swift
- 15% minimum savings threshold
- Max 1 alert per product per week
- Only for products bought in last 4 weeks (from receipts)

Brand filtering (F-52):
- Filter alerts by household brand preferences
- Never show .never branded products

Rating (F-53):
- Post-view prompt: "Hast du es gekauft?"
- 👍 / 👎 updates brand preference

Tab badge on Alerts tab showing unread count.
```

---

### STEP 2.3 — TestFlight Distribution

**Manual steps (not Claude Code):**
1. Create App Store Connect account
2. Configure app in App Store Connect
3. Archive build in Xcode
4. Upload to TestFlight
5. Add 10–20 beta testers
6. Write German TestFlight description explaining what to test

---

## PHASE 3 — Launch (Months 7–12)
Goal: App Store release Germany. Freemium monetization.

### STEP 3.1 — Route Optimization

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md.

Implement store route optimization.

Create Features/ShoppingList/RouteOptimization/:
- RouteOptimizerService.swift — determines which item to buy at which store
- StoreRouteView.swift — shows optimized route with MapKit
- InStoreModeView.swift — GPS-triggered in-store view sorted by aisle

RouteOptimizerService:
- Input: [ShoppingItem] with suggestedStore, household preferred stores
- Output: [StoreRoute] — items grouped by store, in optimal visit order
- Algorithm: nearest neighbor for store visit order (small set, simple TSP)
- Uses item.suggestedStore from flyer data

InStoreModeView:
- Triggered automatically when CoreLocation detects user at a known store
- Shows only items for that store
- Items sorted by aisle category order
- Large check-off buttons (thumb-friendly while pushing cart)
- "Fertig mit diesem Markt" completes the store stop
```

---

### STEP 3.2 — StoreKit 2 Freemium

**Claude Code Prompt:**
```
Read CLAUDE.md and FEATURES.md MODULE 10 (F-90).

Implement freemium monetization with StoreKit 2.

Create Features/Premium/:
- StoreKitManager.swift — handles product fetching, purchasing, entitlements
- PaywallView.swift — premium upgrade screen (F-90)
- PremiumStatusView.swift — shown in Settings for premium users

Products (configure in App Store Connect first):
- com.yourname.wochi.premium.monthly — €2.99/month
- com.yourname.wochi.premium.yearly — €24.99/year

Free tier enforcement:
- Create EntitlementManager.swift — checks current subscription status
- Gate features per FEATURES.md MODULE 10 free tier limits
- Show paywall when limit hit with friendly explanation
- "Weiter mit der kostenlosen Version" option always available

Use StoreKit 2 (iOS 15+) Transaction.currentEntitlement API.
Support Family Sharing via .familyShareable product configuration.
Restore purchases button in Settings.
14-day free trial for yearly plan.
```

---

### STEP 3.3 — App Store Submission

**Manual steps:**
1. App Store screenshots (6.7", 6.1", iPad)
2. App Preview video (optional but recommended)
3. German App Store description
4. Keywords research (German grocery/household terms)
5. Privacy policy URL
6. Age rating questionnaire
7. Submit for App Review

---

## Prompt Template for Any Claude Code Session

Use this template at the start of any new Claude Code session:

```
I'm building Wochi, a native iOS household intelligence app.
Please read CLAUDE.md in the project root first — it contains 
all context about the app, architecture, and coding standards.

Today's task: [DESCRIBE YOUR SPECIFIC TASK]

Before writing any code:
1. Confirm you've read CLAUDE.md
2. State which FEATURES.md items you'll implement
3. List files you'll create or modify
4. Flag any decisions that need my input

Follow all standards in CLAUDE.md. SwiftUI only, async/await only,
no third-party packages without asking.
```

---

## Debugging Checklist

When something doesn't work, check in this order:

1. **CloudKit not syncing?**
   - iCloud logged in on both devices?
   - CloudKit container enabled in capabilities?
   - Running on physical device (not simulator for CloudKit)?

2. **OCR not working?**
   - Camera permission granted?
   - Good lighting in receipt photo?
   - Vision framework request set to .accurate?

3. **Siri intent not firing?**
   - App Intent registered in WochiApp.swift?
   - Siri permission granted in Settings?
   - Testing on physical device?

4. **SwiftData not persisting?**
   - ModelContainer injected in WochiApp.swift?
   - @Environment(\.modelContext) in view?
   - Model class marked @Model?

5. **Notifications not appearing?**
   - Permission granted?
   - Testing on physical device?
   - Background modes enabled in capabilities?
