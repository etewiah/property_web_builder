# SPP–PWB Integration

**Status:** Implemented (Phases 1–6 complete)

SinglePropertyPages (SPP) is an Astro.js application that generates standalone marketing microsites for individual property listings. It integrates with PropertyWebBuilder (PWB) as a data backend.

**Deployment model:** Option B — SPP serves pages independently on its own domain. PWB is a data API. See [Architecture](#architecture) below.

**Data model:** SPP pages are modeled as `SppListing` records — the same pattern as `SaleListing` and `RentalListing`, with independent texts, publication state, and a `listing_type` field for sale vs rental variants.

---

## Documents

**Start here if you're building an SPP client:** [Client Integration Guide](./client-integration-guide.md) — complete guide with every endpoint, request/response shapes, TypeScript types, and setup instructions.

### Architecture & Implementation Docs

| Document | What It Covers | Status |
|----------|---------------|--------|
| [Client Integration Guide](./client-integration-guide.md) | Complete guide for SPP client developers | Current |
| [SppListing Model](./spp-listing-model.md) | Data model, migration, model definition, relationship to existing listings | Implemented |
| [Endpoints](./endpoints.md) | Publish, unpublish, leads, content management API specs + enquiry linking | Implemented |
| [Authentication](./authentication.md) | API key auth via `X-API-Key` header and `WebsiteIntegration` | Implemented |
| [CORS](./cors.md) | `rack-cors` configuration for SPP origins | Implemented |
| [SEO](./seo.md) | Canonical URLs, sitemaps, JSON-LD coordination between PWB and SPP | Implemented |
| [Data Freshness](./data-freshness.md) | Cache headers (phase 1) and webhooks (phase 2, future) | Phase 1 done |

---

## Architecture

### Request Flow

```
┌──────────┐                               ┌──────────────┐
│ Browser  │ ─────────────────────────────▶ │   SPP (Astro)│
│          │                               │              │
└──────────┘                               └──────┬───────┘
                                                  │
                              ┌────────────────────┼────────────────────┐
                              │ Server-side        │ Browser-side       │
                              │ (X-API-Key)        │ (X-Website-Slug)   │
                              ▼                    ▼                    │
                       ┌─────────────┐      ┌─────────────┐            │
                       │ api_manage  │      │ api_public   │◀───────────┘
                       │ (auth'd)   │      │ (public)    │  enquiry POST
                       └─────────────┘      └─────────────┘
                              └──────────┬──────────┘
                                         │
                                    PWB (Rails)
```

- **SPP Astro server** calls `api_manage` (publish, unpublish, leads) with `X-API-Key` + `X-Website-Slug` headers. Server-to-server, no CORS needed.
- **Browser** calls `api_public` (enquiry submissions) directly to PWB with `X-Website-Slug`. Cross-origin, CORS needed.
- **Tenant resolution:** `X-Website-Slug` header, handled by `SubdomainTenant` concern (`app/controllers/concerns/subdomain_tenant.rb`).

### Data Model

```
                        RealtyAsset
                       (the property)
                  /         |          \
          SaleListing  RentalListing  SppListing(s)
          (PWB sale)   (PWB rental)   (SPP pages)
                                      /          \
                              listing_type:    listing_type:
                              "sale"           "rental"
```

- All listing types share the property's physical data (location, bedrooms, photos) from `RealtyAsset`
- Each has independent marketing texts, SEO fields, and publication state
- SPP listings reference the corresponding PWB listing for price data
- Full spec: [SppListing Model](./spp-listing-model.md)

### URL Ownership

SPP controls the property page URL. PWB generates the URL from `client_theme_config['spp_url_template']` and stores it on `SppListing#live_url` at publish time.

Template example:
```json
{ "spp_url_template": "https://{slug}-{listing_type}.spp.example.com/" }
```

Produces: `https://123-main-st-sale.spp.example.com/`

### Configuration

Per-tenant SPP configuration is stored in the `client_theme_config` JSONB column on `pwb_websites`, following the existing `astro_client_url` pattern:

```json
{
  "spp_url": "https://spp.example.com",
  "spp_url_template": "https://{slug}-{listing_type}.spp.example.com/"
}
```

### Publishing Lifecycle

Publishing on SPP and PWB are independent:

```
SPP                              PWB
 │  POST /publish                 │
 │  { listing_type: "sale" }      │
 │ ──────────────────────────────▶│  Create/activate SppListing
 │                                │  (SaleListing untouched)
 │  { status, liveUrl }           │
 │ ◀──────────────────────────────│
 │  SPP enables its page          │
```

A property can be published on PWB but not SPP, or vice versa, or both. Each listing type (sale/rental) is also independent.

### Enquiry Flow

Visitor submits enquiry on SPP page → browser POSTs to PWB's `api_public/v1/enquiries` with `X-Website-Slug` → PWB creates contact + message → sends email notification.

CORS is required for this cross-origin POST. See [CORS](./cors.md).

---

## Provisioning

Use the rake task to create an SPP integration for a tenant:

```bash
rails spp:provision[my-subdomain]
```

This creates a `WebsiteIntegration` (category: `spp`) with an encrypted API key and outputs the environment variables SPP needs.

## Key Implementation Files

| File | Relevance |
|------|-----------|
| `app/models/pwb/spp_listing.rb` | SppListing model with Mobility translations, monetize, curated photos |
| `app/controllers/api_manage/v1/spp_listings_controller.rb` | Publish, unpublish, leads, and content management endpoints |
| `app/controllers/api_manage/v1/base_controller.rb` | API key authentication (iterates encrypted credentials) |
| `app/controllers/api_public/v1/enquiries_controller.rb` | Enquiry endpoint (links messages to properties) |
| `app/controllers/api_public/v1/base_controller.rb` | Cache headers (`expires_in 1.hour`) |
| `app/controllers/concerns/subdomain_tenant.rb` | Tenant resolution via `X-Website-Slug` |
| `app/helpers/seo_helper.rb` | `spp_live_url_for` helper, SEO meta tags, JSON-LD, canonical URLs |
| `app/controllers/sitemaps_controller.rb` | Sitemap generation (uses SPP URLs when available) |
| `app/views/sitemaps/index.xml.erb` | Sitemap template with SPP URL support |
| `config/initializers/cors.rb` | CORS configuration with SPP origin patterns |
| `lib/tasks/spp.rake` | SPP provisioning rake task |
| `docs/architecture/per_tenant_astro_url_routing.md` | Per-tenant URL config pattern |
