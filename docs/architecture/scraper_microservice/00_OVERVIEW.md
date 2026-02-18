# PropertyWebScraper Microservice Integration

## Overview

This document set describes the plan for integrating **PropertyWebScraper** (PWS) as an external extraction microservice into **PropertyWebBuilder** (PWB).

### Problem

PWB has a built-in scraping system using Ruby "Pasarela" classes — one per portal (Rightmove, Zoopla, Idealista, etc.). This approach has drawbacks:

1. **Adding a new portal requires Ruby code** — a new Pasarela class, tests, and deployment
2. **Portal HTML changes break extraction** — fixing requires a PWB code change and redeploy
3. **Limited portal coverage** — PWB supports ~10 portals vs PWS's 18+
4. **Duplicate effort** — PWS already solves extraction with a mature, JSON-config-driven approach

### Solution

Use PWS as a dedicated extraction microservice. PWB sends a property URL (+ optional pre-rendered HTML) to PWS, receives structured property data back, and imports it through the existing `PropertyImportFromScrapeService`.

```
                        PWB (Rails)                              PWS (Astro/Rails)
                        ──────────                               ──────────────────
User enters URL ──→ ExternalScraperClient ──HTTP POST──→ /api/v1/extract
                           │                                      │
                           │                              HtmlExtractor + Mappings
                           │                                      │
                    receives JSON ←──────────────────── { property data }
                           │
                    PropertyImportFromScrapeService
                           │
                    RealtyAsset + Listing + Photos
```

### Documents in This Set

| # | Document | Purpose |
|---|----------|---------|
| 00 | OVERVIEW (this file) | High-level summary |
| 01 | ARCHITECTURE | System architecture and data flow |
| 02 | DATA_MAPPING | Field-by-field mapping between PWS and PWB |
| 03 | API_CONTRACT | Exact API request/response specification |
| 04 | PWS_CHANGES | Recommended changes to PropertyWebScraper |
| 05 | PWB_CHANGES | Changes needed in PropertyWebBuilder |
| 06 | IMPLEMENTATION_PHASES | Phased rollout plan |

### Decision Record

- **Integration style:** HTTP microservice (not gem dependency, not code port)
- **PWS deployment target:** Astro app (modern, actively maintained) with Rails engine as fallback
- **Auth:** API key via `X-Api-Key` header
- **Fallback:** PWB retains its Pasarela system as a fallback when PWS is unavailable
- **HTML source:** PWB fetches HTML via its existing connectors (HTTP/Playwright), sends to PWS for extraction only
