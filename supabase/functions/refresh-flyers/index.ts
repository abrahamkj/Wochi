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

// ─── Probe handler (GET) — extract real API URLs from page source ─────────────
async function probeHandelsangebote(plz: string): Promise<object> {
  // 1. Fetch homepage HTML and extract any API URLs or config
  const homeRes = await fetch(`https://www.handelsangebote.de/`, { headers: HEADERS })
  const homeHtml = await homeRes.text()

  // Look for API base URLs, config objects, or fetch() calls in the HTML/inline JS
  const apiUrlMatches = [
    ...homeHtml.matchAll(/["'`](https?:\/\/[^"'`]*api[^"'`]{0,80})["'`]/gi),
    ...homeHtml.matchAll(/["'`](\/api\/[^"'`]{1,80})["'`]/gi),
    ...homeHtml.matchAll(/apiUrl\s*[:=]\s*["'`]([^"'`]+)["'`]/gi),
    ...homeHtml.matchAll(/baseUrl\s*[:=]\s*["'`]([^"'`]+)["'`]/gi),
    ...homeHtml.matchAll(/endpoint\s*[:=]\s*["'`]([^"'`]+)["'`]/gi),
  ].map(m => m[1]).filter((v, i, a) => a.indexOf(v) === i).slice(0, 30)

  // 2. Look for <script src> tags pointing to JS bundles we should also probe
  const scriptSrcs = [...homeHtml.matchAll(/<script[^>]+src=["']([^"']+)["']/gi)]
    .map(m => m[1])
    .filter(s => s.includes("chunk") || s.includes("main") || s.includes("app") || s.includes("bundle"))
    .slice(0, 3)

  // 3. Fetch the API root (Symfony API Platform exposes docs at /api)
  let apiRootBody: any = null
  const apiRootRes = await fetch(`https://www.handelsangebote.de/api`, {
    headers: { ...HEADERS, Accept: "application/ld+json" }
  })
  if (apiRootRes.ok) {
    const t = await apiRootRes.text()
    try { apiRootBody = JSON.parse(t) } catch { apiRootBody = t.slice(0, 1000) }
  }

  // 4. Fetch the JS bundle and extract every URL / API hint
  let bundleInfo: object = { skipped: true }
  if (scriptSrcs[0]) {
    const src = scriptSrcs[0].startsWith("http") ? scriptSrcs[0] : `https://www.handelsangebote.de${scriptSrcs[0]}`
    const bundleRes = await fetch(src, { headers: HEADERS })
    const bundleStatus = bundleRes.status

    if (bundleRes.ok) {
      const bundleText = await bundleRes.text()
      const size = bundleText.length

      const extract = (re: RegExp) =>
        [...bundleText.matchAll(re)].map(m => m[1]).filter((v, i, a) => a.indexOf(v) === i)

      // Full https:// URLs in the bundle (any domain)
      const fullUrls = extract(/["'`](https?:\/\/[^"'`\s]{10,120})["'`]/gi)
        .filter(u => !u.includes("fonts.") && !u.includes("cdn.") && !u.includes("analytics"))
        .slice(0, 40)

      // Relative paths that look like API calls
      const relativePaths = extract(/["'`](\/[a-z0-9_\-\/]{3,60})["'`]/gi)
        .filter(p => p.includes("offer") || p.includes("product") || p.includes("flyer")
                  || p.includes("brochure") || p.includes("store") || p.includes("search")
                  || p.includes("zip") || p.includes("plz") || p.includes("postal"))
        .slice(0, 30)

      // fetch() / axios calls pattern
      const fetchCalls = extract(/fetch\(["'`]([^"'`]{10,120})["'`]/gi).slice(0, 20)
      const axiosCalls = extract(/axios\.[a-z]+\(["'`]([^"'`]{5,120})["'`]/gi).slice(0, 20)

      // Config-like patterns: baseUrl, endpoint, apiUrl, host
      const configVars = extract(/(?:baseUrl|endpoint|apiUrl|apiBase|host|serviceUrl)\s*[:=]\s*["'`]([^"'`]{5,120})["'`]/gi).slice(0, 20)

      // ZIP/postal code query param patterns
      const zipParams = extract(/["'`]([^"'`]{0,60}(?:zip|plz|postalCode|zipCode|postal)[^"'`]{0,60})["'`]/gi)
        .filter(v => v.includes("/") || v.includes("?"))
        .slice(0, 20)

      bundleInfo = { src, bundleStatus, size, fullUrls, relativePaths, fetchCalls, axiosCalls, configVars, zipParams }
    } else {
      bundleInfo = { src, bundleStatus }
    }
  }

  return {
    plz,
    homepageStatus: homeRes.status,
    apiRootStatus: apiRootRes.status,
    apiRootBody,
    apiUrlsFoundInHomepage: apiUrlMatches,
    scriptBundles: scriptSrcs,
    bundleInfo,
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
