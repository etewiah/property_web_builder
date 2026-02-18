# 06 — Implementation Phases

## Phase 1: PWS API (PropertyWebScraper changes)

**Goal:** PWS exposes a clean v2 API endpoint that returns data in PWB's format.
**Duration estimate:** Not provided per CLAUDE.md guidelines.
**Depends on:** Nothing.

### Tasks

1. **Create `PropertyTypeNormalizer` service**
   - File: `app/services/property_web_scraper/property_type_normalizer.rb`
   - Regex-based mapping from raw property type text to standardized keys
   - Tests with examples from each supported portal

2. **Create `/api/v2/extract` endpoint**
   - Controller: `app/controllers/property_web_scraper/api/v2/extractions_controller.rb`
   - Route: `POST /api/v2/extract`
   - Accepts `{ url, html }`, returns `{ asset_data, listing_data, images }`
   - Uses `HtmlExtractor` directly (stateless, no Firestore)
   - Includes `PropertyTypeNormalizer` in the transformation

3. **Create `/api/v2/health` endpoint**
   - Controller: `app/controllers/property_web_scraper/api/v2/health_controller.rb`
   - Route: `GET /api/v2/health`
   - No auth required
   - Returns scraper count and version

4. **Create `/api/v2/portals` endpoint**
   - Controller: `app/controllers/property_web_scraper/api/v2/portals_controller.rb`
   - Route: `GET /api/v2/portals`
   - Returns list of supported hosts with country info

5. **Audit scraper mappings for `property_type` coverage**
   - Check each of the 18 JSON mapping files
   - Add `property_type` extraction where missing
   - Test against fixture HTML files

6. **Write tests**
   - Unit tests for `PropertyTypeNormalizer`
   - Request specs for all v2 endpoints
   - Integration test: HTML fixture → v2 extract → verify output structure

### Deliverable

PWS v2 API is deployed and accessible. Can be verified with:

```bash
# Health check
curl https://scraper.example.com/api/v2/health

# Extract a property (with HTML provided)
curl -X POST https://scraper.example.com/api/v2/extract \
  -H "X-Api-Key: test-key" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.rightmove.co.uk/properties/123", "html": "<html>..."}'
```

---

## Phase 2: PWB Client (PropertyWebBuilder changes)

**Goal:** PWB can call PWS for extraction, falling back to local Pasarelas.
**Depends on:** Phase 1.

### Tasks

1. **Create `ExternalScraperClient` service**
   - File: `app/services/pwb/external_scraper_client.rb`
   - HTTP client using Faraday
   - Calls `/api/v2/extract` with URL + HTML
   - Returns `Result` struct matching PWB's `extracted_data` format
   - Error handling: `UnsupportedPortalError`, `ExtractionFailedError`, `ConnectionError`

2. **Add `extraction_source` migration**
   - New column on `pwb_scraped_properties`
   - Values: `"external"`, `"local"`, `"manual"`

3. **Modify `PropertyScraperService`**
   - After fetching HTML, try `ExternalScraperClient` first
   - On `UnsupportedPortalError` or `ConnectionError`, fall back to local Pasarela
   - Set `extraction_source` on `ScrapedProperty`

4. **Add configuration**
   - `PWS_API_URL`, `PWS_API_KEY`, `PWS_TIMEOUT`, `PWS_ENABLED` env vars
   - Document in deployment guide

5. **Write tests**
   - Unit tests for `ExternalScraperClient` (using WebMock stubs)
   - Integration tests for the fallback path in `PropertyScraperService`
   - Test: PWS success → external extraction used
   - Test: PWS unsupported → local pasarela used
   - Test: PWS timeout → local pasarela used
   - Test: PWS disabled → local pasarela used directly

### Deliverable

PWB imports properties using PWS for extraction when available. Verified by:
1. Importing a property from a PWS-supported portal → `extraction_source: "external"`
2. Importing from an unsupported portal → `extraction_source: "local"`
3. Setting `PWS_ENABLED=false` → always uses local extraction

---

## Phase 3: UI Enhancements (Optional)

**Goal:** Better user experience around the integration.
**Depends on:** Phase 2.

### Tasks

1. **Show extraction source in preview page**
   - Display badge indicating "Extracted via PropertyWebScraper" or "Extracted locally"

2. **Show supported portals in URL import form**
   - Query `/api/v2/portals` and display as a collapsible list
   - Cache the result (portals don't change often)

3. **Admin dashboard integration health indicator**
   - Call `/api/v2/health` and show status in site admin dashboard
   - Green = healthy, Yellow = degraded, Red = unreachable

4. **Extraction quality indicator**
   - Show `extraction_rate` from PWS response
   - Flag low-quality extractions for user review

---

## Phase 4: Extend Portal Coverage (Ongoing)

**Goal:** Add support for more property portals via PWS JSON mappings.
**Depends on:** Phase 1.

### Process for Adding a New Portal

This is the key benefit of the microservice approach — adding a portal requires **zero Ruby code changes** in either project:

1. **Get a sample HTML page** from the new portal
2. **Create a JSON mapping file** in PWS: `config/scraper_mappings/<cc>_<portal>.json`
3. **Add an ImportHost seed record** for the new hostname
4. **Test** the mapping against the sample HTML using the `/api/v2/extract` endpoint
5. **Deploy PWS** — the new portal is immediately available to all PWB instances

Alternatively, use PWS's AI-assisted mapping generation (`POST /admin/api/ai-map`) to draft the mapping from sample HTML automatically.

### No PWB Changes Needed

When a new portal is added to PWS:
- PWB's `ExternalScraperClient` sends the URL + HTML
- PWS recognizes the new host and applies the new mapping
- Data comes back in the same format
- No PWB deployment needed

For portals PWS doesn't support, PWB's local Pasarela (or generic fallback) still works.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| PWS goes down | Automatic fallback to local Pasarelas; no user impact |
| PWS returns bad data | Preview step lets users review before importing |
| Network latency | 15-second timeout; async batch processing for large imports |
| API key compromise | Rotate via ENV var; no shared secrets in code |
| PWS breaking changes | Versioned API (v2); PWB can pin to specific version |
| Portal HTML changes | Fix in PWS JSON config only; no PWB redeploy |

---

## Migration Strategy

This is an **additive** integration — nothing is removed from PWB:

1. Deploy PWS with v2 API (Phase 1)
2. Deploy PWB changes with `PWS_ENABLED=false` initially (Phase 2)
3. Enable for a single test website: set `PWS_ENABLED=true` in staging
4. Verify extraction quality matches or exceeds local Pasarelas
5. Enable for all websites in production
6. Monitor `extraction_source` distribution in `ScrapedProperty` records
7. Over time, local Pasarelas become the fallback rather than the primary path

Local Pasarelas are **never removed** — they serve as the safety net.
