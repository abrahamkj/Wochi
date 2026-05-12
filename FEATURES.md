# FEATURES.md — Wochi Feature Specifications

Every feature in this file has:
- A clear description
- Acceptance criteria (what "done" means)
- UI notes
- Edge cases to handle

---

## MODULE 1: Onboarding

### F-01: Welcome Screen
**Description:** First screen new users see. Explains Wochi in 3 slides.

**Acceptance Criteria:**
- [ ] 3-slide carousel with illustration, title, and subtitle per slide
- [ ] Slide 1: "Dein Haushalt, organisiert" — shared lists intro
- [ ] Slide 2: "Nie mehr vergessen" — pantry + reminders
- [ ] Slide 3: "Klüger einkaufen" — price comparison + budget
- [ ] "Weiter" button advances slides
- [ ] Skip button jumps to account creation
- [ ] Does not show again after first launch

**Edge Cases:**
- User force-quits mid-onboarding → resumes from beginning

---

### F-02: Sign In with Apple
**Description:** Authentication using Apple's native Sign In with Apple.

**Acceptance Criteria:**
- [ ] Standard Sign In with Apple button shown
- [ ] On success: creates or retrieves HouseholdMember record
- [ ] Apple User ID stored securely in Keychain
- [ ] Display name fetched from Apple account (editable)
- [ ] On subsequent launches: auto-signs in silently
- [ ] No email/password flow — Apple only in Phase 1

**Edge Cases:**
- User revokes Apple sign-in → shows re-authentication prompt
- Apple servers unavailable → allow offline access to existing data

---

### F-03: Create or Join Household
**Description:** After sign-in, user either creates a new household or joins one via invite link.

**Acceptance Criteria:**
- [ ] Two clear options: "Neuen Haushalt erstellen" / "Einladung annehmen"
- [ ] Create: prompts for household name (e.g. "Familie Müller")
- [ ] Create: automatically sets user as .owner
- [ ] Join: opens URL handler for wochi:// deep links
- [ ] Join: shows household name + owner name before accepting
- [ ] Confirmation screen shown after both paths
- [ ] User lands on main tab view after completion

**Edge Cases:**
- Invalid invite link → clear error message
- Invite already accepted → "Du bist bereits Mitglied"
- Household full (10 members) → appropriate message

---

## MODULE 2: Shopping List

### F-10: View Shopping Lists
**Description:** Main list screen showing all active household shopping lists.

**Acceptance Criteria:**
- [ ] Shows all non-archived lists for the household
- [ ] Each list card shows: name, item count, estimated total (if available)
- [ ] Lists sorted by last updated (most recent first)
- [ ] "+" button to create new list
- [ ] Swipe left to archive a list
- [ ] Empty state: friendly illustration + "Erste Liste erstellen" button
- [ ] Pull-to-refresh triggers CloudKit sync

**UI Notes:**
- Card-based layout
- Show member avatars who last updated each list

---

### F-11: View and Edit a Shopping List
**Description:** Detail view of a single list with all items.

**Acceptance Criteria:**
- [ ] Shows pending items at top, checked items collapsed below
- [ ] Each item shows: name, quantity + unit, brand (if set), category icon, estimated price (if available)
- [ ] Tap item to check it off (strike-through animation)
- [ ] Long-press item to edit details
- [ ] Swipe left on item to delete
- [ ] Items grouped by category (user can toggle)
- [ ] Items sorted by category aisle order (user can toggle)
- [ ] "Alle erledigten löschen" button when checked items exist
- [ ] Show who added each item (small avatar)
- [ ] Real-time updates when other members modify the list (CloudKit push)

**Edge Cases:**
- Offline: changes saved locally, sync badge shown
- Conflict (two members edit same item simultaneously): last-write-wins, CloudKit handles

---

### F-12: Add Item to List
**Description:** Quick-add item flow.

**Acceptance Criteria:**
- [ ] Tap "+" opens bottom sheet with text field
- [ ] Auto-complete suggestions from: previous items, pantry items, common German grocery items
- [ ] Quantity field (default: 1)
- [ ] Unit selector (Stück, kg, g, Liter, ml, Packung, Flasche, Dose)
- [ ] Optional: preferred brand field
- [ ] Optional: note field
- [ ] Category auto-assigned based on item name (ML classifier or keyword matching)
- [ ] "Hinzufügen" saves and closes, or "Hinzufügen & weiteres" stays open
- [ ] Item immediately visible to all household members

**Edge Cases:**
- Duplicate item name: prompt "Bereits auf der Liste — Menge erhöhen?"
- Empty name: button disabled

---

### F-13: Edit Item Details
**Description:** Full edit screen for a shopping item.

**Acceptance Criteria:**
- [ ] Edit: name, quantity, unit, brand, brand preference (preferred/acceptable/never), category, note, estimated price
- [ ] Category picker with icons
- [ ] Brand preference picker: ⭐ Bevorzugt / ✓ Akzeptabel / ✗ Nie
- [ ] Save changes syncs to all members
- [ ] Delete item option (with confirmation)

---

### F-14: Archive Shopping List
**Description:** Mark a list as done after shopping trip.

**Acceptance Criteria:**
- [ ] Swipe left on list card → "Archivieren" option
- [ ] Or: button inside list detail view
- [ ] Archived lists not shown in main view
- [ ] Archived lists accessible via "Archiv" section in settings
- [ ] Checked items from archived list can optionally update pantry quantities

---

## MODULE 3: Pantry Tracker

### F-20: View Pantry
**Description:** Shows everything the household currently has at home.

**Acceptance Criteria:**
- [ ] Items grouped by category with section headers
- [ ] Each item shows: name, quantity + unit, expiry date (if set), low stock indicator
- [ ] Expiring items (≤ 3 days) shown with orange warning
- [ ] Expired items shown with red indicator
- [ ] Low stock items shown with yellow indicator
- [ ] "Ablaufend" and "Wenig vorrätig" filter chips at top
- [ ] Search bar to find specific items
- [ ] Empty state with illustration

**UI Notes:**
- Colored indicators: 🟢 OK, 🟡 Low, 🟠 Expiring Soon, 🔴 Expired

---

### F-21: Add Pantry Item Manually
**Description:** Add a product to the pantry by hand.

**Acceptance Criteria:**
- [ ] Form: name, quantity, unit, category, brand, expiry date (date picker), low stock threshold
- [ ] Barcode scanner button (opens camera, reads EAN barcode)
- [ ] If barcode recognized: auto-fills name and category from Supabase product catalog
- [ ] Expiry date picker: calendar style, German date format (dd.MM.yyyy)
- [ ] Low stock threshold: stepper, defaults to 1
- [ ] Save → item visible to all household members

---

### F-22: Auto-Populate Pantry from Receipt
**Description:** After scanning a receipt, offer to add bought items to pantry.

**Acceptance Criteria:**
- [ ] After receipt confirmation, show: "Vorräte aktualisieren?"
- [ ] List all recognized receipt items with checkboxes (all checked by default)
- [ ] User can uncheck items they don't want to add
- [ ] For existing pantry items: shows current quantity + adds scanned quantity
- [ ] For new items: creates new pantry entry
- [ ] "Bestätigen" updates all selected items
- [ ] Expiry date not set automatically (user prompted to add later)

---

### F-23: Update Pantry Item
**Description:** Edit an existing pantry item (used some, expired, finished).

**Acceptance Criteria:**
- [ ] Tap item → edit sheet
- [ ] Adjust quantity (up/down stepper or direct input)
- [ ] Quick action: "Aufgebraucht" sets quantity to 0 and offers to add to shopping list
- [ ] Update expiry date
- [ ] Shows last updated by + timestamp
- [ ] "Löschen" removes item (with confirmation)

---

### F-24: Expiry Notifications
**Description:** Push notifications when pantry items are expiring.

**Acceptance Criteria:**
- [ ] Notification sent 3 days before expiry date
- [ ] Notification sent on expiry day
- [ ] Notification content: item name + days remaining
- [ ] Tapping notification → opens Pantry filtered to that item
- [ ] Notification settings: user can enable/disable per type
- [ ] Notifications sent to ALL household members (not just who added the item)

---

### F-25: Low Stock Notifications
**Description:** Alert when a pantry item falls below its threshold.

**Acceptance Criteria:**
- [ ] Triggered when quantity is updated to ≤ threshold
- [ ] Notification: "📦 [Item] ist fast aufgebraucht"
- [ ] Action button: "Zur Liste hinzufügen" — adds to active shopping list with one tap
- [ ] Deduplicates: no repeat notification if already on shopping list

---

## MODULE 4: Budget Dashboard

### F-30: Monthly Overview
**Description:** Shows total household spending for the current month.

**Acceptance Criteria:**
- [ ] Large number: total spent this month in €
- [ ] Comparison to last month: "+12% gegenüber letztem Monat" in red/green
- [ ] Month selector (← →) to browse history
- [ ] Receipt count shown: "Basierend auf 8 Kassenbons"
- [ ] If no receipts: prompt to scan first receipt
- [ ] Data updates in real-time when new receipt scanned

---

### F-31: Spending by Store
**Description:** Breakdown of spending per store chain.

**Acceptance Criteria:**
- [ ] Horizontal bar chart (Swift Charts)
- [ ] Each store: logo/name, € amount, percentage bar, receipt count
- [ ] Sorted by amount descending
- [ ] Tapping store → shows only that store's receipts
- [ ] Current month shown by default, month selector above

---

### F-32: Spending by Category
**Description:** Donut/pie chart of spending by food category.

**Acceptance Criteria:**
- [ ] Donut chart (Swift Charts) with category colors
- [ ] Legend below chart: category name, € amount, %
- [ ] Tapping segment highlights it and shows detail
- [ ] Categories from ItemCategory enum
- [ ] "Sonstiges" grouped for small categories (< 2%)

---

### F-33: Spending by Member
**Description:** Shows which household member spent how much.

**Acceptance Criteria:**
- [ ] Only shown for households with 2+ members
- [ ] Each member: avatar, name, € amount, receipt count
- [ ] Based on who scanned the receipt (not split equally — Phase 1)
- [ ] Note shown: "Basierend auf gescannten Kassenbons"

---

### F-34: Receipt History
**Description:** List of all scanned receipts.

**Acceptance Criteria:**
- [ ] Chronological list of receipts (newest first)
- [ ] Each row: store name + logo, date, total amount, scanned-by avatar
- [ ] Tap → shows full receipt detail (items list)
- [ ] Swipe to delete (with confirmation, updates budget)
- [ ] Filter by store, by member, by month
- [ ] Empty state: "Noch keine Kassenbons. Scanne deinen ersten Kassenbon."

---

## MODULE 5: Receipt Scanning

### F-40: Open Camera and Scan
**Description:** Main entry point for receipt scanning.

**Acceptance Criteria:**
- [ ] Accessible from: tab bar, "+" in Budget, post-shopping prompt
- [ ] Full-screen camera with receipt frame guide overlay
- [ ] Flash toggle
- [ ] "Aus Fotos wählen" option (pick from photo library)
- [ ] Capture button triggers OCR processing
- [ ] Processing indicator shown during OCR
- [ ] Must request camera permission gracefully

---

### F-41: Receipt Review Screen
**Description:** After OCR, user reviews and corrects parsed data.

**Acceptance Criteria:**
- [ ] Shows parsed results: store name, date, items list, total
- [ ] Store name: editable dropdown (pre-populated with known German chains)
- [ ] Date: editable date picker
- [ ] Items: editable list — name, quantity, price per row
- [ ] Add item manually if OCR missed something
- [ ] Delete incorrectly parsed item
- [ ] Total: shown and compared to sum of items (mismatch highlighted)
- [ ] "Bestätigen" saves receipt
- [ ] "Erneut scannen" discards and reopens camera

**Edge Cases:**
- Total mismatch > 10%: warning shown but user can still confirm
- Empty parse result: "Kassenbon nicht lesbar" with retry option
- Very long receipts (30+ items): scrollable list with performance

---

## MODULE 6: Substitution Alerts

### F-50: Alerts List
**Description:** Shows current active deals for products the household regularly buys.

**Acceptance Criteria:**
- [ ] List of active alerts, sorted by savings % (highest first)
- [ ] Each alert: product name, regular store vs. deal store, regular price vs. deal price, savings €/%, valid until date
- [ ] "Neu" badge on unread alerts
- [ ] Swipe to dismiss alert
- [ ] Empty state: "Keine aktuellen Angebote für deine Produkte"
- [ ] Badge on tab icon showing unread alert count

---

### F-51: Alert Generation Logic
**Description:** Background process that finds deals based on household's purchase history.

**Acceptance Criteria:**
- [ ] Runs weekly when new flyer data available in Supabase
- [ ] Compares: products bought in last 4 weeks vs. current flyer prices
- [ ] Alert generated when: deal price is ≥ 15% cheaper than average paid price
- [ ] One alert per product per week maximum
- [ ] Alert only generated for stores in household's preferred stores list
- [ ] Push notification sent when new alerts generated

---

### F-52: Brand Preference Filtering
**Description:** Alerts respect brand preferences set by the household.

**Acceptance Criteria:**
- [ ] Never suggest a product where household has set brand = .never
- [ ] Substitution suggestions only show brands rated .preferred or .acceptable
- [ ] Alert shows if preferred brand is on sale (no substitution needed)
- [ ] Alert shows alternative brand only with: original brand unavailable notice + rating

---

### F-53: Thumbs Up/Down on Substitutions
**Description:** After trying a suggested substitution, user rates it.

**Acceptance Criteria:**
- [ ] After alert is viewed: "Hast du es gekauft?" prompt
- [ ] 👍 / 👎 buttons
- [ ] Thumbs up: brand moved to .acceptable or .preferred (user chooses)
- [ ] Thumbs down: brand marked as .never for this product
- [ ] Rating stored per product per brand in household data

---

## MODULE 7: Siri Voice Input

### F-60: Add Item via Siri
**Description:** "Hey Siri, add Milch to Wochi"

**Acceptance Criteria:**
- [ ] App Intent registered: "Add item to Wochi"
- [ ] Siri asks for item name if not provided
- [ ] Adds to household's primary active list
- [ ] Confirms: "Milch wurde zu deiner Einkaufsliste hinzugefügt"
- [ ] Works from: locked screen, AirPods, Apple Watch
- [ ] Works in German and English
- [ ] Item appears on list for all household members within seconds

---

### F-61: Add Item with Quantity via Siri
**Description:** "Hey Siri, add 2 Liter Milch to Wochi"

**Acceptance Criteria:**
- [ ] Parses quantity from natural language ("zwei Liter", "2 kg", "eine Packung")
- [ ] Quantity and unit extracted and saved with item
- [ ] Fallback to quantity 1 if not parseable
- [ ] Confirmation includes quantity: "2 Liter Milch wurde hinzugefügt"

---

### F-62: Siri Shortcut Setup
**Description:** User can create custom Siri shortcuts for Wochi actions.

**Acceptance Criteria:**
- [ ] Suggested shortcuts shown in Wochi settings
- [ ] "Zur Einkaufsliste hinzufügen" shortcut
- [ ] "Wochi Liste anzeigen" shortcut (opens app to list)
- [ ] "Vorräte prüfen" shortcut (opens pantry)
- [ ] Shortcuts app compatible

---

## MODULE 8: Household Management

### F-70: View Household Members
**Description:** Shows all members of the household.

**Acceptance Criteria:**
- [ ] List of members with: avatar color, name, role badge, joined date
- [ ] Current user highlighted
- [ ] Owner sees role management options
- [ ] Tap member → see their contribution (receipts scanned, items added)

---

### F-71: Invite Member
**Description:** Generate and share an invite link.

**Acceptance Criteria:**
- [ ] "Mitglied einladen" button (visible to owner and admins)
- [ ] Generates CloudKit CKShare URL
- [ ] iOS share sheet opens automatically
- [ ] Invite link valid for 72 hours
- [ ] Pending invite shown in members list
- [ ] Max 10 members enforced — button disabled if limit reached

---

### F-72: Remove Member
**Description:** Owner/admin removes a member from the household.

**Acceptance Criteria:**
- [ ] Swipe left on member → "Entfernen" (owner/admin only)
- [ ] Confirmation dialog: "Möchtest du [Name] wirklich entfernen?"
- [ ] Removed member loses access to shared data immediately
- [ ] Their receipts remain in household data (unlinked from member)
- [ ] They are notified via push: "Du wurdest aus [Household] entfernt"

---

### F-73: Leave Household
**Description:** Member voluntarily leaves a household.

**Acceptance Criteria:**
- [ ] "Haushalt verlassen" in Settings
- [ ] If last member: offer to delete household entirely
- [ ] If owner and others remain: must transfer ownership first
- [ ] Confirmation: "Möchtest du [Household] wirklich verlassen?"
- [ ] After leaving: onboarding shown to create/join new household

---

### F-74: Preferred Stores Management
**Description:** Household configures which stores they shop at.

**Acceptance Criteria:**
- [ ] Multi-select list of StoreChain options with logos
- [ ] Reorder by drag handle (preferred stores sorted first)
- [ ] Selected stores used for: flyer fetching, substitution alerts, route planning
- [ ] At least one store must be selected
- [ ] Changes apply immediately to all household members

---

## MODULE 9: Settings

### F-80: Notification Preferences
**Description:** Per-notification-type enable/disable controls.

**Acceptance Criteria:**
- [ ] Toggles for: expiry alerts, low stock, list updates, deal alerts, monthly budget summary
- [ ] Per-notification quiet hours (e.g. no alerts between 22:00–08:00)
- [ ] Settings per member (each member sets their own)
- [ ] Link to iOS system notification settings

---

### F-81: App Language
**Description:** Language selection.

**Acceptance Criteria:**
- [ ] Follows iOS system language by default
- [ ] Supports: German (de-DE), English (en-US)
- [ ] Manual override in settings

---

### F-82: iCloud Sync Status
**Description:** Shows CloudKit sync status.

**Acceptance Criteria:**
- [ ] "Synchronisiert" / "Synchronisiert gerade..." / "Offline — Änderungen werden synchronisiert"
- [ ] Last sync timestamp
- [ ] "Jetzt synchronisieren" force-sync button
- [ ] Link to iOS Settings → iCloud if issues detected

---

### F-83: About & Legal
**Description:** App info, version, legal documents.

**Acceptance Criteria:**
- [ ] App version + build number
- [ ] Privacy Policy (German)
- [ ] Terms of Use (German)
- [ ] Contact/Support email
- [ ] Rate on App Store link
- [ ] Open source licenses

---

## MODULE 10: Freemium Gating (Phase 3)

### Free Tier Limits
- 1 household
- 1 shopping list
- 10 pantry items
- 3 months budget history
- Basic notifications (expiry only)

### Premium (€2.99/month or €24.99/year)
- Unlimited lists
- Unlimited pantry items
- Full budget history
- All notification types
- Substitution alerts
- Receipt scanning (unlimited)
- Voice/Siri integration
- Widget
- Priority support

### F-90: Paywall
**Acceptance Criteria:**
- [ ] Shown when free tier limit hit
- [ ] Clear value proposition in German
- [ ] Monthly and annual option (annual highlighted as best value)
- [ ] Free trial: 14 days (Phase 3)
- [ ] StoreKit 2 implementation
- [ ] Family Sharing support
- [ ] Restore purchases option
