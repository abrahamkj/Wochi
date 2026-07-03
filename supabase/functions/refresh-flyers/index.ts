import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

// Fixed device ID — Kaufda uses this for personalisation but doesn't validate it
const BONIAL_ACCOUNT_ID = "wochi-service-00000000-0000-0000-0000-000000000001"

// Grocery store publisher IDs on Kaufda (Bonial DE)
// Find yours: Network tab → look for calls to /api/publishers or /api/brochures
// These are the most common German grocery retailers
const GROCERY_PUBLISHERS: Record<string, string> = {
  "Lidl":      "lidl-de",       // adjust to actual publisherId values
  "REWE":      "rewe",
  "Kaufland":  "kaufland",
  "Edeka":     "edeka",
  "Aldi":      "aldi-sued",
  "Penny":     "penny",
  "Netto":     "netto",
}

// German city PLZ codes to cover major regions
const LOCATIONS = [
  { plz: "10115", city: "Berlin" },
  { plz: "20095", city: "Hamburg" },
  { plz: "80331", city: "München" },
  { plz: "50667", city: "Köln" },
  { plz: "70173", city: "Stuttgart" },
  { plz: "60311", city: "Frankfurt" },
  { plz: "30159", city: "Hannover" },
  { plz: "01067", city: "Dresden" },
]

const HEADERS = {
  "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
  "Accept": "application/json",
  "Accept-Language": "de-DE,de;q=0.9",
  "Referer": "https://www.kaufda.de/",
}

// ─── Step 1: Discover active brochures for a location ────────────────────────
async function fetchBrochures(plz: string): Promise<string[]> {
  // This endpoint lists current brochures near a postal code.
  // Verify/update by checking Network tab for calls containing "brochure" or "publication"
  const url = `https://www.kaufda.de/api/brochures?location=${plz}&country=DE&limit=50&userPlatformCategory=desktop.web.browser`
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) return []

  const data = await res.json()

  // Filter to grocery retailers only and extract brochure IDs
  const brochures: string[] = []
  const items = data.brochures ?? data.contents ?? data.items ?? data.results ?? []
  for (const b of items) {
    const publisher = (b.publisherName ?? b.retailer ?? b.name ?? "").toLowerCase()
    const isGrocery = Object.keys(GROCERY_PUBLISHERS).some(s => publisher.includes(s.toLowerCase()))
    if (isGrocery) {
      const id = b.id ?? b.brochureId ?? b.uuid
      if (id) brochures.push(id)
    }
  }
  return brochures
}

// ─── Step 2: Fetch all offers from a brochure ────────────────────────────────
async function fetchOffers(brochureId: string, plz: string): Promise<object[]> {
  const url = [
    `https://www.kaufda.de/api/personalisedOffers`,
    `?brochureId=${brochureId}`,
    `&size=100`,
    `&bonialAccountId=${BONIAL_ACCOUNT_ID}`,
    `&userPlatformCategory=desktop.web.browser`,
  ].join("")

  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) return []

  const data = await res.json()
  const contents: any[] = data.contents ?? []

  const now = new Date().toISOString()
  const mapped: object[] = []

  for (const item of contents) {
    if (item.type !== "OFFER") continue

    const store = mapStore(item.publisherName ?? "")
    if (!store) continue  // skip non-grocery publishers

    const mainPrice = item.prices?.mainPrice ?? 0
    const secondaryPrice = item.prices?.secondaryPrice ?? 0

    // secondaryPrice is the "was" price; mainPrice is the deal price
    const dealPrice    = mainPrice > 0 ? mainPrice : 0
    const regularPrice = secondaryPrice > 0 ? secondaryPrice : 0

    if (dealPrice <= 0) continue
    if (!item.validUntil) continue

    // Skip if already expired
    if (item.validUntil < now) continue

    // Only include items with a meaningful discount, or include all if no regular price
    const savings = regularPrice > 0
      ? ((regularPrice - dealPrice) / regularPrice) * 100
      : 0
    if (regularPrice > 0 && savings < 10) continue  // skip tiny discounts

    const category = item.categories?.[0] ?? mapCategory(item.categoryPaths?.[0])

    mapped.push({
      product_name:    item.title?.trim(),
      brand:           item.brand ?? null,
      store:           store,
      regular_price:   regularPrice > 0 ? regularPrice : dealPrice * 1.25, // estimate if missing
      deal_price:      dealPrice,
      valid_from:      item.validFrom ?? now,
      valid_until:     item.validUntil,
      category:        category ?? null,
      flyer_image_url: item.offerImages?.url?.normal ?? item.offerImages?.url?.thumbnail ?? null,
      postal_code:     plz,
    })
  }

  return mapped
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function mapStore(publisherName: string): string | null {
  const n = publisherName.toLowerCase()
  if (n.includes("kaufland"))  return "Kaufland"
  if (n.includes("lidl"))      return "Lidl"
  if (n.includes("rewe"))      return "REWE"
  if (n.includes("edeka"))     return "Edeka"
  if (n.includes("aldi"))      return "Aldi"
  if (n.includes("penny"))     return "Penny"
  if (n.includes("netto"))     return "Netto"
  if (n.includes(" dm ") || n === "dm") return "dm"
  if (n.includes("rossmann"))  return "Rossmann"
  return null  // not a grocery store we track
}

function mapCategory(path?: Array<{ name: string }>): string | null {
  if (!path) return null
  const last = path[path.length - 1]?.name?.toLowerCase() ?? ""
  if (last.includes("milch") || last.includes("käse") || last.includes("molker")) return "dairy"
  if (last.includes("fleisch") || last.includes("fisch") || last.includes("wurst")) return "meat"
  if (last.includes("obst") || last.includes("gemüse")) return "fruit"
  if (last.includes("brot") || last.includes("back")) return "bakery"
  if (last.includes("getränk") || last.includes("wasser") || last.includes("saft")) return "drinks"
  if (last.includes("tiefkühl")) return "frozen"
  if (last.includes("hygiene") || last.includes("körper")) return "hygiene"
  if (last.includes("drogerie") || last.includes("reinig") || last.includes("wasch")) return "cleaning"
  return "other"
}

// ─── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Allow manual trigger with a specific PLZ: POST /refresh-flyers {"plz":"10115"}
  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {}
  const locations = body.plz
    ? [{ plz: body.plz, city: "custom" }]
    : LOCATIONS

  const allDeals: object[] = []
  const errors: string[] = []

  for (const { plz, city } of locations) {
    console.log(`Fetching brochures for ${city} (${plz})...`)

    let brochureIds = await fetchBrochures(plz)

    // Fallback: if brochure discovery fails, try direct brochure IDs from URL params
    if (brochureIds.length === 0 && body.brochureIds) {
      brochureIds = body.brochureIds
    }

    for (const brochureId of brochureIds) {
      try {
        const deals = await fetchOffers(brochureId, plz)
        allDeals.push(...deals)
        console.log(`  Brochure ${brochureId}: ${deals.length} deals`)
      } catch (e) {
        errors.push(`${plz}/${brochureId}: ${e}`)
      }
    }
  }

  if (allDeals.length === 0) {
    return new Response(JSON.stringify({
      error: "No deals fetched. Share brochure IDs directly: POST {brochureIds: ['uuid1','uuid2'], plz: '10115'}",
      errors,
    }), { status: 422, headers: { "Content-Type": "application/json" } })
  }

  // Delete expired deals, upsert fresh ones
  await supabase.from("flyer_prices").delete().lt("valid_until", new Date().toISOString())
  const { error: insertError } = await supabase.from("flyer_prices").insert(allDeals)

  return new Response(JSON.stringify({
    inserted: allDeals.length,
    locations: locations.map(l => l.plz),
    errors: errors.length ? errors : undefined,
    insertError: insertError ?? undefined,
  }), { status: insertError ? 500 : 200, headers: { "Content-Type": "application/json" } })
})
