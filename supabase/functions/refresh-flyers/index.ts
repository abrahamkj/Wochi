import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
)

const GROCERY_STORES = ["lidl", "rewe", "kaufland", "edeka", "aldi", "penny", "netto", "dm", "rossmann", "norma", "aldi süd", "aldi nord"]

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

const BONIAL_ACCOUNT_ID = "b48bdfb7-1abf-4462-946c-e5cec3bbe64e"

const HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  "Accept": "application/json, text/plain, */*",
  "Accept-Language": "de-DE,de;q=0.9",
  "Referer": "https://www.kaufda.de/",
  "Origin": "https://www.kaufda.de",
}

// ─── Probe handler (GET) — content-viewer-be.kaufda.de discovery ─────────────
// User found: https://content-viewer-be.kaufda.de/v1/brochures/{uuid}/pages?partner=kaufda_web&lat=...&lng=...
async function probeKaufda(plz: string): Promise<object> {
  const accountId = "b48bdfb7-1abf-4462-946c-e5cec3bbe64e"
  // Coordinates for PLZ 10115 (Berlin Mitte)
  const lat = 52.5251
  const lng = 13.3697

  // 1. Try brochure LISTING on content-viewer-be.kaufda.de
  const listingCandidates = [
    `https://content-viewer-be.kaufda.de/v1/brochures?partner=kaufda_web&lat=${lat}&lng=${lng}&limit=50`,
    `https://content-viewer-be.kaufda.de/v1/brochures?partner=kaufda_web&lat=${lat}&lng=${lng}&radius=10&limit=50`,
    `https://content-viewer-be.kaufda.de/v1/brochures?partner=kaufda_web&zipCode=${plz}&limit=50`,
    `https://content-viewer-be.kaufda.de/v1/brochures?partner=kaufda_web&postalCode=${plz}&country=DE&limit=50`,
    `https://content-viewer-be.kaufda.de/v2/brochures?partner=kaufda_web&lat=${lat}&lng=${lng}&limit=50`,
    `https://content-viewer-be.kaufda.de/v1/catalogs?partner=kaufda_web&lat=${lat}&lng=${lng}&limit=50`,
    `https://content-viewer-be.kaufda.de/v1/publications?partner=kaufda_web&lat=${lat}&lng=${lng}&limit=50`,
  ]

  const listingProbes: object[] = []
  for (const url of listingCandidates) {
    try {
      const res = await fetch(url, { headers: HEADERS })
      const text = await res.text()
      let body: any = null
      try { body = JSON.parse(text) } catch { /* not json */ }
      const arr = body ? (body.brochures ?? body.contents ?? body.items ?? body.results ?? body.data ?? body.catalogs ?? []) : []
      listingProbes.push({
        url, status: res.status,
        keys: body ? Object.keys(body) : [],
        arrayLength: arr.length,
        firstItem: arr[0] ? JSON.stringify(arr[0]).slice(0, 300) : null,
        preview: !body ? text.slice(0, 300) : null,
      })
      if (res.ok && arr.length > 0) break
    } catch (e) {
      listingProbes.push({ url, error: String(e) })
    }
  }

  // 2. Fetch pages of the known brochure the user found to understand the data shape
  const knownBrochureId = "df23802c-92b6-4c05-87ed-0f5eb54328cf"
  let pagesData: object = {}
  try {
    const res = await fetch(
      `https://content-viewer-be.kaufda.de/v1/brochures/${knownBrochureId}/pages?partner=kaufda_web&brochureKey=&lat=${lat}&lng=${lng}`,
      { headers: HEADERS }
    )
    const text = await res.text()
    let body: any = null
    try { body = JSON.parse(text) } catch { /* not json */ }
    pagesData = {
      status: res.status,
      keys: body ? Object.keys(body) : [],
      preview: text.slice(0, 600),
    }
  } catch (e) {
    pagesData = { error: String(e) }
  }

  // 3. Try to get brochure metadata (publisher name) for the known brochure
  let brochureMeta: object = {}
  try {
    const res = await fetch(
      `https://content-viewer-be.kaufda.de/v1/brochures/${knownBrochureId}?partner=kaufda_web`,
      { headers: HEADERS }
    )
    const text = await res.text()
    brochureMeta = { status: res.status, preview: text.slice(0, 400) }
  } catch (e) {
    brochureMeta = { error: String(e) }
  }

  return { plz, lat, lng, listingProbes, knownBrochurePagesData: pagesData, knownBrochureMeta: brochureMeta }
}

// ─── Fetch flyers from handelsangebote.de ────────────────────────────────────
// (populated once we know the real endpoint from probing)
async function fetchHandelsangeboteOffers(plz: string): Promise<object[]> {
  // TODO: update URL after probing confirms the correct endpoint
  const url = `https://www.handelsangebote.de/api/offers?zip=${plz}&limit=100`
  const res = await fetch(url, { headers: HEADERS })
  if (!res.ok) return []

  const data = await res.json()
  const items: any[] = data.offers ?? data.items ?? data.results ?? data.data ?? data.contents ?? []

  const now = new Date().toISOString()
  const mapped: object[] = []

  for (const item of items) {
    const storeName = item.store?.name ?? item.retailer ?? item.publisherName ?? item.merchant ?? ""
    const store = mapStore(storeName)
    if (!store) continue

    const dealPrice    = item.price ?? item.dealPrice ?? item.offer_price ?? item.currentPrice ?? 0
    const regularPrice = item.regularPrice ?? item.original_price ?? item.normalPrice ?? item.uvp ?? 0

    if (dealPrice <= 0) continue

    const validUntil = item.validUntil ?? item.valid_until ?? item.end_date ?? item.validTo
    if (!validUntil || validUntil < now) continue

    const savings = regularPrice > 0 ? ((regularPrice - dealPrice) / regularPrice) * 100 : 0
    if (regularPrice > 0 && savings < 10) continue

    mapped.push({
      product_name:    (item.title ?? item.name ?? item.product_name ?? "").trim(),
      brand:           item.brand ?? null,
      store:           store,
      regular_price:   regularPrice > 0 ? regularPrice : dealPrice * 1.25,
      deal_price:      dealPrice,
      valid_from:      item.validFrom ?? item.valid_from ?? item.start_date ?? now,
      valid_until:     validUntil,
      category:        item.category ?? null,
      flyer_image_url: item.image ?? item.imageUrl ?? item.thumbnail ?? null,
      postal_code:     plz,
    })
  }

  return mapped
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function mapStore(name: string): string | null {
  const n = name.toLowerCase()
  if (n.includes("kaufland"))  return "Kaufland"
  if (n.includes("lidl"))      return "Lidl"
  if (n.includes("rewe"))      return "REWE"
  if (n.includes("edeka"))     return "Edeka"
  if (n.includes("aldi"))      return "Aldi"
  if (n.includes("penny"))     return "Penny"
  if (n.includes("netto"))     return "Netto"
  if (n.includes("norma"))     return "Norma"
  if (n === "dm" || n.startsWith("dm ") || n.includes(" dm")) return "dm"
  if (n.includes("rossmann"))  return "Rossmann"
  return null
}

// ─── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const body = req.method === "POST" ? await req.json().catch(() => ({})) : {}

  // GET request or {"probe": true} → probe mode: find the real API endpoint
  if (req.method === "GET" || body.probe) {
    const plz = body.plz ?? "10115"
    const result = await probeKaufda(plz)
    return new Response(JSON.stringify(result, null, 2), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    })
  }

  const locations = body.plz
    ? [{ plz: body.plz, city: "custom" }]
    : LOCATIONS

  const allDeals: object[] = []
  const errors: string[] = []

  for (const { plz, city } of locations) {
    console.log(`Fetching offers for ${city} (${plz})...`)
    try {
      const deals = await fetchHandelsangeboteOffers(plz)
      allDeals.push(...deals)
      console.log(`  ${city}: ${deals.length} deals`)
    } catch (e) {
      errors.push(`${plz}: ${e}`)
    }
  }

  if (allDeals.length === 0) {
    return new Response(JSON.stringify({
      error: "No deals found. Run GET /refresh-flyers to probe the API and find the correct endpoint.",
      errors,
    }), { status: 422, headers: { "Content-Type": "application/json" } })
  }

  await supabase.from("flyer_prices").delete().lt("valid_until", new Date().toISOString())
  const { error: insertError } = await supabase.from("flyer_prices").insert(allDeals)

  return new Response(JSON.stringify({
    inserted: allDeals.length,
    locations: locations.map(l => l.plz),
    errors: errors.length ? errors : undefined,
    insertError: insertError ?? undefined,
  }), { status: insertError ? 500 : 200, headers: { "Content-Type": "application/json" } })
})
