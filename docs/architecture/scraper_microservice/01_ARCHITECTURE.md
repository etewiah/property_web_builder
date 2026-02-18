# 01 — Architecture

## Separation of Concerns

The integration splits responsibilities cleanly:

| Responsibility | Owner | Rationale |
|----------------|-------|-----------|
| HTML fetching (HTTP, Playwright) | PWB | Already has robust connectors with blocking detection, Playwright fallback, manual HTML entry |
| HTML extraction (parsing, field mapping) | PWS | Purpose-built extraction engine with JSON-configurable mappings for 18+ portals |
| Portal registry (which host → which parser) | PWS | Maintains the mapping between hostnames and scraper configurations |
| Data import (creating RealtyAsset, Listings, Photos) | PWB | Owns the data model, multi-tenancy, and business logic |
| Scrape history & deduplication | PWB | Owns `ScrapedProperty` records scoped to each tenant website |

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PropertyWebBuilder (PWB)                     │
│                                                                  │
│  ┌──────────────┐    ┌─────────────────────┐                    │
│  │ URL Import   │───→│ PropertyScraperSvc   │                    │
│  │ Controller   │    │ (orchestrator)       │                    │
│  └──────────────┘    └─────────┬───────────┘                    │
│                                │                                 │
│                    ┌───────────┴───────────┐                    │
│                    │                       │                     │
│            ┌───────▼────────┐    ┌─────────▼──────────┐         │
│            │ ScraperConnector│    │ ExternalScraperClient│ [NEW]  │
│            │ (HTTP/Playwright)│    │ (calls PWS API)     │         │
│            └───────┬────────┘    └─────────┬──────────┘         │
│                    │                       │                     │
│                    │ raw HTML              │ raw HTML            │
│                    │                       │                     │
│            ┌───────▼────────┐              │                     │
│            │ Pasarela        │              │                     │
│            │ (local parser)  │    ┌─────────▼──────────┐         │
│            │ [FALLBACK]      │    │ PWS Microservice    │         │
│            └───────┬────────┘    │ (HTTP POST)         │         │
│                    │             └─────────┬──────────┘         │
│                    │                       │                     │
│                    └───────────┬───────────┘                    │
│                                │                                 │
│                    ┌───────────▼───────────┐                    │
│                    │ extracted_data JSON    │                    │
│                    └───────────┬───────────┘                    │
│                                │                                 │
│                    ┌───────────▼───────────┐                    │
│                    │ ScrapedProperty        │                    │
│                    │ (stored to DB)         │                    │
│                    └───────────┬───────────┘                    │
│                                │                                 │
│                    ┌───────────▼───────────┐                    │
│                    │ ImportFromScrapeService │                    │
│                    │ → RealtyAsset          │                    │
│                    │ → SaleListing/Rental   │                    │
│                    │ → PropPhotos           │                    │
│                    └────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  PropertyWebScraper (PWS)                        │
│                                                                  │
│  ┌────────────────┐                                              │
│  │ /api/v1/extract │ ←── POST { url, html }                     │
│  │ (new endpoint)  │                                              │
│  └───────┬────────┘                                              │
│          │                                                       │
│  ┌───────▼─────────┐    ┌──────────────────┐                    │
│  │ PortalRegistry   │───→│ ScraperMapping    │                    │
│  │ (host → mapping) │    │ (JSON config)     │                    │
│  └─────────────────┘    └────────┬─────────┘                    │
│                                  │                               │
│  ┌───────────────────────────────▼─────────────────────┐        │
│  │ HtmlExtractor                                        │        │
│  │ - defaultValues → set country, currency, etc.        │        │
│  │ - textFields → title, description, address, etc.     │        │
│  │ - intFields → bedrooms, bathrooms, etc.              │        │
│  │ - floatFields → price, lat, lng, area, etc.          │        │
│  │ - booleanFields → for_sale, for_rent, etc.           │        │
│  │ - images → image_urls array                          │        │
│  │ - features → features array                          │        │
│  │ - ScrapedContentSanitizer → clean & validate         │        │
│  └──────────────────────────────┬──────────────────────┘        │
│                                 │                                │
│                    { extracted property JSON }                    │
└─────────────────────────────────────────────────────────────────┘
```

## Request Flow (Happy Path)

1. User enters a property URL in PWB's admin UI
2. `PropertyScraperService` creates/finds a `ScrapedProperty` record
3. PWB's HTTP or Playwright connector fetches the raw HTML
4. `ExternalScraperClient` sends `{ url, html }` to PWS's `/api/v1/extract` endpoint
5. PWS identifies the portal from the URL host, loads the JSON mapping, runs `HtmlExtractor`
6. PWS returns `{ success: true, data: { asset_data, listing_data, images } }`
7. PWB saves `extracted_data` and `extracted_images` to the `ScrapedProperty` record
8. User previews and confirms the import
9. `PropertyImportFromScrapeService` creates `RealtyAsset` + `SaleListing`/`RentalListing` + `PropPhoto` records

## Fallback Strategy

```
ExternalScraperClient.call(url, html)
    │
    ├── Success → use PWS extracted data
    │
    └── Failure (timeout, 5xx, connection refused, unsupported portal)
            │
            └── Fall back to local Pasarela
                    │
                    ├── Success → use local extracted data
                    │
                    └── Failure → show "manual HTML entry" form to user
```

PWS failure triggers fallback silently. The `ScrapedProperty` record tracks which extraction method was used via a new `extraction_source` field: `"external"`, `"local"`, or `"manual"`.

## Configuration

PWB needs these settings (stored in ENV or `Rails.application.credentials`):

```ruby
# Required
PWS_API_URL=https://scraper.example.com    # Base URL of PWS deployment
PWS_API_KEY=your-api-key-here              # Matches PWS's PROPERTY_SCRAPER_API_KEY

# Optional
PWS_TIMEOUT=15                              # HTTP timeout in seconds (default: 15)
PWS_ENABLED=true                            # Feature flag to enable/disable (default: true)
```

## Deployment Considerations

- PWS can be deployed as a standalone Astro SSR app (recommended) or Rails engine
- No shared database — communication is purely via HTTP/JSON
- PWS is stateless for extraction — it doesn't need to persist anything for PWB's use case
- PWS can serve multiple PWB instances (multi-tenant safe since it just parses HTML)
- Rate limiting on PWS side is optional since PWB controls fetch timing
