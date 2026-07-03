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

const HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  "Accept": "application/json, text/plain, */*",
  "Accept-Language": "de-DE,de;q=0.9",
  "Referer": "https://www.handelsangebote.de/",
  "Origin": "https://www.handelsangebote.de",
}

// ─── Probe handler (GET) — Offerista API discovery ────────────────────────────
// handelsangebote.de is an Offerista white-label product. We have integer brochure IDs
// from the page's tracking JSON. Now we find the Offerista API base URL.
async function probeHandelsangebote(plz: string): Promise<object> {
  // 1. Fetch the lazy home JS chunk which contains the real API calls
  const homeChunkRes = await fetch("https://www.handelsangebote.de/build/js-handelsangebote-de-home.6289e086.js", { headers: HEADERS })
  let chunkApiUrls: string[] = []
  let chunkFullText = ""
  if (homeChunkRes.ok) {
    chunkFullText = await homeChunkRes.text()
    const extract = (re: RegExp) =>
      [...chunkFullText.matchAll(re)].map(m => m[1]).filter((v, i, a) => a.indexOf(v) === i)

    chunkApiUrls = [
      ...extract(/["'`](https?:\/\/[^"'`\s]{10,150})["'`]/gi),
      ...extract(/["'`](\/[a-z][a-z0-9_\-\/]{2,60})["'`]/gi)
        .filter(p => p.includes("api") || p.includes("offer") || p.includes("brochure") || p.includes("product")),
    ].filter((v, i, a) => a.indexOf(v) === i).slice(0, 50)
  }

  // 2. Try Offerista API directly with known brochure IDs from page tracking JSON
  const knownBrochureIds = [6104336, 6100160, 6094172, 6105539, 6095426]
  const offeristaCandidates = [
    `https://api.offerista.com/brochures/${knownBrochureIds[0]}`,
    `https://api.offerista.com/v1/brochures/${knownBrochureIds[0]}`,
    `https://api.offerista.com/v1/brochures/${knownBrochureIds[0]}/offers`,
    `https://api.offerista.com/v2/brochures/${knownBrochureIds[0]}`,
    `https://app.offerista.com/api/brochures/${knownBrochureIds[0]}`,
    `https://www.handelsangebote.de/api/brochures/${knownBrochureIds[0]}`,
    `https://www.handelsangebote.de/api/brochure/${knownBrochureIds[0]}`,
    `https://www.handelsangebote.de/api/products?brochureId=${knownBrochureIds[0]}`,
    `https://www.handelsangebote.de/api/offers?brochureId=${knownBrochureIds[0]}`,
  ]

  const offeristProbes: object[] = []
  for (const url of offeristaCandidates) {
    try {
      const res = await fetch(url, { headers: HEADERS })
      const text = await res.text()
      let body: any = null
      try { body = JSON.parse(text) } catch { /* not json */ }
      offeristProbes.push({
        url,
        status: res.status,
        isJson: body !== null,
        keys: body ? Object.keys(body).slice(0, 10) : null,
        preview: text.slice(0, 300),
      })
      if (res.ok) break
    } catch (e) {
      offeristProbes.push({ url, error: String(e) })
    }
  }

  // 3. Try fetching a known product ID from the tracking JSON
  const knownProductId = 43766572
  const productProbes: object[] = []
  for (const url of [
    `https://api.offerista.com/products/${knownProductId}`,
    `https://www.handelsangebote.de/api/products/${knownProductId}`,
  ]) {
    try {
      const res = await fetch(url, { headers: HEADERS })
      const text = await res.text()
      let body: any = null
      try { body = JSON.parse(text) } catch { /* not json */ }
      productProbes.push({ url, status: res.status, isJson: body !== null, preview: text.slice(0, 300) })
      if (res.ok) break
    } catch (e) {
      productProbes.push({ url, error: String(e) })
    }
  }

  return {
    plz,
    homeChunkStatus: homeChunkRes.status,
    homeChunkSize: chunkFullText.length,
    chunkApiUrls,
    knownBrochureIds,
    offeristApiProbes: offeristProbes,
    productProbes,
  }
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
    const result = await probeHandelsangebote(plz)
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
