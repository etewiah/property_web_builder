# SPP–PWB Integration Architecture Guide

This document describes how SinglePropertyPages (SPP) integrates with PropertyWebBuilder (PWB). It covers the deployment topology, request flows, configuration model, and the specific API endpoints SPP needs from PWB.

These endpoints are referenced in Phases 3–4 of the SPP backend integration plan (see `docs/backend-integration.md` in the SinglePropertyPages repository).

---

## Table of Contents

1. [What Is SPP?](#what-is-spp)
2. [Deployment Topology](#deployment-topology)
3. [URL Ownership — Who Serves the Property Page?](#url-ownership--who-serves-the-property-page)
4. [Configuration Model](#configuration-model)
5. [Publishing Lifecycle](#publishing-lifecycle)
6. [Enquiry Flow](#enquiry-flow)
7. [Endpoint 1: Publish Property](#endpoint-1-publish-property)
8. [Endpoint 2: Unpublish Property](#endpoint-2-unpublish-property)
9. [Endpoint 3: Property Leads](#endpoint-3-property-leads)
10. [Supporting Change: Link Enquiries to Properties](#supporting-change-link-enquiries-to-properties)
11. [Response Conventions](#response-conventions)
12. [SPP's Current Dev Stubs](#spps-current-dev-stubs)
13. [Open Questions](#open-questions)

---

## What Is SPP?

SinglePropertyPages (SPP) is an Astro.js application that generates standalone, richly-designed pages for individual property listings. Unlike PWB's built-in property pages (rendered by `PropsController` for B themes or proxied through `ClientProxyController` for A themes), SPP pages are purpose-built for marketing a single property — closer to a microsite than a listing detail page.

SPP communicates with PWB via the `api_manage` and `api_public` namespaces.

---

## Deployment Topology

There are two viable deployment models. The choice affects URL ownership, CORS requirements, and how SPP resolves tenant context. **This is the most important architectural decision to make before implementation.**

### Option A: Proxied Through PWB (Like A Themes)

```
┌──────────┐     ┌──────────────────────┐     ┌──────────────┐
│ Browser  │ ──▶ │   PWB (Rails)        │ ──▶ │   SPP (Astro)│
│          │     │   ClientProxyCtrl    │     │              │
└──────────┘     └──────────────────────┘     └──────────────┘
```

- Browser hits PWB's domain. PWB proxies the request to SPP's Astro server.
- **PWB controls the URL.** SPP is invisible to the visitor.
- Tenant context is passed via `X-Website-Slug` header from the proxy (see `app/controllers/pwb/client_proxy_controller.rb:118-131`).
- No CORS needed — everything is same-origin from the browser's perspective.
- This is the same pattern used for A themes. The per-tenant Astro URL is stored in `client_theme_config['astro_client_url']` (see `docs/architecture/per_tenant_astro_url_routing.md`).
- SPP would need a dedicated proxy route rather than sharing the catch-all A theme proxy, since an A-theme tenant's main pages and its SPP pages are distinct Astro apps.

### Option B: SPP Serves Directly (Independent Deployment)

```
┌──────────┐                               ┌──────────────┐
│ Browser  │ ─────────────────────────────▶ │   SPP (Astro)│
│          │                               │              │
└──────────┘                               └──────┬───────┘
                                                  │ API calls
                                                  ▼
                                           ┌──────────────┐
                                           │   PWB (Rails) │
                                           └──────────────┘
```

- Browser hits SPP directly on its own domain (e.g., `123-main-st.example.com`).
- **SPP controls the URL.** PWB is a data API only.
- SPP must include the `X-Website-Slug` header on all API calls to PWB (see `app/controllers/concerns/subdomain_tenant.rb:32-38` for how PWB resolves tenants from this header).
- **CORS is required.** PWB currently has no CORS configuration — `api_public/v1/base_controller.rb` inherits from `ActionController::Base` and does not set `Access-Control-Allow-Origin`. This would need to be added for SPP origins.
- The enquiry form on SPP pages would POST directly to PWB's `api_public/v1/enquiries`, or SPP could proxy the request through its own Astro API routes.

### Which to Choose?

| Concern | Option A (Proxied) | Option B (Independent) |
|---------|-------------------|----------------------|
| URL ownership | PWB domain | SPP domain |
| CORS | Not needed | Required on PWB |
| Tenant resolution | Automatic via proxy headers | SPP must send `X-Website-Slug` |
| SSL/DNS | No extra setup | SPP needs its own cert/domain |
| Latency | Extra hop through Rails | Direct to SPP |
| SEO | One canonical URL per property | Needs canonical coordination (see [Open Questions](#open-questions)) |

**Recommendation:** Start with Option A (proxied) to minimize cross-cutting concerns. This reuses the existing proxy architecture and avoids CORS, DNS, and dual-URL issues. Migrate to Option B later if latency or scaling requires it.

---

## URL Ownership — Who Serves the Property Page?

PWB currently generates property page URLs via `RealtyAsset#contextual_show_path` (`app/models/pwb/realty_asset.rb:226-237`), which produces paths like:

```
/en/properties/for-sale/<uuid>/<slug>
```

These are served by `PropsController` (B themes) or proxied through `ClientProxyController` (A themes). The publish endpoint's `liveUrl` response field needs to return the correct URL, but **the correct URL depends on the deployment topology:**

| Topology | `liveUrl` should be |
|----------|-------------------|
| Option A (Proxied) | PWB's path: `/en/properties/for-sale/<uuid>/<slug>`, or a dedicated SPP proxy path like `/en/spp/<uuid>/<slug>` |
| Option B (Independent) | SPP's full URL: `https://123-main-st.example.com/` — but PWB doesn't know this without configuration |

### Solving `liveUrl` for Option B

If SPP runs independently, PWB needs to know SPP's URL pattern to generate correct `liveUrl` values. Two approaches:

1. **SPP tells PWB.** SPP sends the live URL back to PWB after publishing (e.g., a callback or a PATCH to the property with the SPP URL). PWB stores it.
2. **PWB generates it from a template.** Store a URL template in `client_theme_config` like `"spp_url_template": "https://{slug}.spp.example.com/"` and have PWB interpolate property data.

For Option A, `liveUrl` can use the existing `contextual_show_path` output, possibly on a dedicated SPP proxy route prefix.

---

## Configuration Model

SPP configuration should follow the existing per-tenant pattern used for Astro clients: the `client_theme_config` JSONB column on `pwb_websites`.

### Proposed Keys

```json
{
  "astro_client_url": "https://main-astro.example.com",
  "spp_url": "https://spp.example.com",
  "spp_url_template": "https://{slug}.spp.example.com/"
}
```

| Key | Purpose |
|-----|---------|
| `spp_url` | Base URL of the SPP Astro server for this tenant (used for proxying in Option A, or for CORS allowlisting in Option B) |
| `spp_url_template` | URL template for generating `liveUrl` in Option B. Supports `{slug}`, `{uuid}`, `{locale}` placeholders. Not needed for Option A. |

This mirrors the existing `astro_client_url` pattern (see `docs/architecture/per_tenant_astro_url_routing.md`) and requires no migration — `client_theme_config` is already a JSONB column.

### Resolution Priority (Option A)

If SPP is proxied, the proxy controller resolves the SPP server URL in this order:

1. `client_theme_config['spp_url']` (per-tenant)
2. `ENV['SPP_URL']` (environment default)
3. `http://localhost:4322` (development fallback)

---

## Publishing Lifecycle

"Publishing" means different things to PWB and SPP. This section clarifies the coordination.

### What "Publish" Means on PWB

On PWB, publishing a property means:
- The property's sale listing becomes `active: true` and `visible: true`
- The property appears in search results and listing pages on PWB
- The property page is accessible at its PWB URL

### What "Publish" Means on SPP

On SPP, publishing may involve:
- Deploying or enabling a standalone property page
- Generating static assets (images, metadata) for the page
- Making the SPP-hosted page accessible to visitors

### Coordination Flow

```
SPP                              PWB
 │                                │
 │  POST /publish                 │
 │ ──────────────────────────────▶│  1. Activate listing (visible: true)
 │                                │  2. Generate liveUrl
 │  { status, liveUrl }           │
 │ ◀──────────────────────────────│
 │                                │
 │  3. SPP enables its own page   │
 │     using liveUrl for links    │
```

**The publish endpoint on PWB only controls PWB's visibility state.** SPP is responsible for its own page deployment. The `liveUrl` in the response tells SPP where the property page lives (which, in Option A, is a PWB-proxied URL; in Option B, PWB computes it from the configured template).

Unpublishing is the reverse: PWB hides the listing, and SPP disables its page.

---

## Enquiry Flow

When a visitor on an SPP-hosted property page submits an enquiry, the submission must reach PWB's `api_public/v1/enquiries` endpoint (`app/controllers/api_public/v1/enquiries_controller.rb`).

### Option A (Proxied): Enquiry via SPP's Proxy

```
Browser (on PWB domain)
  │  POST /api/enquiries
  ▼
SPP Astro API route
  │  Adds X-Website-Slug header
  │  POST /api_public/v1/enquiries
  ▼
PWB Rails
  │  SubdomainTenant resolves website from X-Website-Slug
  │  Creates contact + message
  │  Sends email notification
  ▼
Returns { success: true, data: { contact_id, message_id } }
```

This is same-origin. No CORS needed.

### Option B (Independent): Enquiry Directly to PWB

```
Browser (on SPP domain)
  │  POST https://pwb.example.com/api_public/v1/enquiries
  │  Headers: X-Website-Slug: tenant-slug
  ▼
PWB Rails (needs CORS for SPP origin)
  │  SubdomainTenant resolves website from X-Website-Slug
  │  Creates contact + message
  │  Sends email notification
  ▼
Returns { success: true, data: { contact_id, message_id } }
```

**CORS requirements for Option B:**
- `Access-Control-Allow-Origin` must include SPP's origin
- `Access-Control-Allow-Headers` must include `X-Website-Slug`, `Content-Type`
- `Access-Control-Allow-Methods` must include `POST, OPTIONS`
- PWB currently has **no CORS configuration** — this would need to be added to `ApiPublic::V1::BaseController`

### How SPP Knows the Tenant Slug

SPP needs the tenant's `X-Website-Slug` value to include on API calls. This can be:
- Injected at build/deploy time as an environment variable
- Returned in the initial data fetch when SPP loads property data from PWB
- Configured in SPP's per-tenant configuration

### Required `enquiry_params`

The enquiry endpoint expects (see `app/controllers/api_public/v1/enquiries_controller.rb:82-84`):

```json
{
  "enquiry": {
    "name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "+34 612 345 678",
    "message": "I am interested in this property.",
    "property_id": "<uuid-or-slug>"
  }
}
```

The `property_id` links the enquiry to the property (see [Supporting Change](#supporting-change-link-enquiries-to-properties) below).

---

## Endpoint 1: Publish Property

**Purpose:** Make a property visible on the public website.

**Suggested path:** `POST /api_manage/v1/:locale/properties/:id/publish`

**Behavior:**
- Find the `RealtyAsset` by its UUID, scoped to the current website
- Find or activate a sale listing for that property
- Ensure the listing is active, visible, and not archived
- The exact mechanism is up to PWB (e.g., calling `activate!` then setting `visible: true`, or a single state transition)

**Expected response (200 OK):**
```json
{
  "status": "published",
  "liveUrl": "/en/properties/for-sale/<uuid>/<slug>",
  "publishedAt": "2026-02-12T10:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Should be `"published"` on success |
| `liveUrl` | string | The path or URL where the property is publicly viewable. For Option A, this is a PWB path. For Option B, this is computed from `spp_url_template` in `client_theme_config`. |
| `publishedAt` | string (ISO 8601) | When the property became published (listing's `updated_at` is fine) |

**`liveUrl` generation logic:**

```
if website.client_theme_config['spp_url_template'].present?
  # Option B: interpolate the template
  template = website.client_theme_config['spp_url_template']
  template.gsub('{slug}', property.slug).gsub('{uuid}', property.id)
else
  # Option A / default: use PWB's own path
  property.contextual_show_path('for_sale')
end
```

**Error cases:**
- **404** — Property not found (standard `RecordNotFound` handling)
- **422** — Property has no sale listing to publish

---

## Endpoint 2: Unpublish Property

**Purpose:** Hide a property from the public website without archiving or deleting it.

**Suggested path:** `POST /api_manage/v1/:locale/properties/:id/unpublish`

**Behavior:**
- Find the `RealtyAsset` by its UUID, scoped to the current website
- Find the active sale listing
- Make it not visible (but keep it active so it can be re-published easily)

**Expected response (200 OK):**
```json
{
  "status": "draft",
  "liveUrl": null
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Should be `"draft"` on success |
| `liveUrl` | null | Property is no longer publicly viewable |

**Error cases:**
- **404** — Property not found
- **422** — No active sale listing to unpublish

---

## Endpoint 3: Property Leads

**Purpose:** Retrieve enquiry messages associated with a specific property, for display in SPP's leads tab.

**Suggested path:** `GET /api_manage/v1/:locale/properties/:id/leads`

**Behavior:**
- Find the `RealtyAsset` by its UUID, scoped to the current website
- Return messages (enquiries) linked to that property, ordered by most recent first
- Each lead should include the associated contact's name, email, and phone
- Include an `isNew` flag indicating whether the lead needs attention

**Expected response (200 OK):**
```json
[
  {
    "id": 42,
    "name": "Jane Doe",
    "email": "jane@example.com",
    "phone": "+34 612 345 678",
    "message": "I am interested in this property. Is it still available?",
    "createdAt": "2026-02-11T14:22:00Z",
    "isNew": true
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | integer | Message ID |
| `name` | string | Contact's display name (or fallback to "Unknown") |
| `email` | string | Contact's primary email (or the `origin_email` from the form) |
| `phone` | string or null | Contact's phone number |
| `message` | string | Enquiry message content |
| `createdAt` | string (ISO 8601) | When the enquiry was submitted |
| `isNew` | boolean | Whether this lead needs attention — suggested heuristic: `read == false` OR created within the last 48 hours |

**Notes:**
- Returns an empty array `[]` when no leads exist for the property (not a 404)
- Returns **404** only when the property itself doesn't exist
- If PWB doesn't currently have a way to link messages to specific properties, see the next section

---

## Supporting Change: Link Enquiries to Properties

**Context:** PWB's `Message` model does not currently have a foreign key to `RealtyAsset`. The enquiry controller receives a `property_id` parameter but only uses it for the email notification — it isn't stored on the message.

**What SPP needs:** When a visitor submits an enquiry from a property page (via `POST /api_public/v1/enquiries` with `property_id`), the resulting message should be queryable by property. This is what makes the leads endpoint above possible.

**Suggested approach (PWB decides the implementation):**
- Add a `realty_asset_id` column (UUID, nullable) to the `pwb_messages` table
- When the enquiry controller processes a submission with a `property_id`, store the resolved property's ID on the message
- Add a `belongs_to :realty_asset` association on the `Message` model

**Backwards compatibility:** Messages created before this change will have `realty_asset_id = NULL`. PWB can decide how to handle these in the leads endpoint — options include:
- Return only directly-linked messages (simplest)
- Fall back to returning all website messages when a property has none linked (more useful during transition)
- Backfill based on email notification logs (most complete but most complex)

---

## Response Conventions

SPP's proxy layer is designed to handle multiple response shapes, so PWB has flexibility. That said, SPP specifically expects:

- **Publish/unpublish:** A JSON object with `status`, `liveUrl`, and optionally `publishedAt`
- **Leads:** A JSON array (not wrapped in `{ data: [...] }`)
- **Errors:** SPP checks for `response.ok` and reads error details from the body. PWB's existing `BaseController` error handling (returning `{ success: false, error: "..." }`) works well

---

## SPP's Current Dev Stubs

For reference, here is what SPP returns from its dev stubs today. These are the shapes that SPP's frontend code is built to consume:

### Publish stub response
```json
{
  "status": "published",
  "liveUrl": "https://demo.example.com/properties/for-sale/<id>/<slug>",
  "publishedAt": "<current ISO timestamp>"
}
```

### Unpublish stub response
```json
{
  "status": "draft",
  "liveUrl": null
}
```

### Leads stub response
```json
[
  {
    "id": 1,
    "name": "Sarah Johnson",
    "email": "sarah.johnson@email.com",
    "phone": "+1 (555) 123-4567",
    "message": "I'm very interested in this property...",
    "createdAt": "2025-01-15T10:30:00Z",
    "isNew": true
  }
]
```

These stubs live in:
- `apps/main/src/pages/api/[...path].ts` (publish/unpublish/leads handlers within `getDevResponse()`)

Once PWB implements the real endpoints, SPP will update its proxy to route to PWB instead of returning stubs.

---

## Open Questions

These are architectural concerns that need decisions before or during implementation. They don't block the endpoint work but affect the overall integration.

### 1. Data Freshness

SPP fetches property data from PWB's API, but there is currently no mechanism for PWB to notify SPP when property data changes (price, photos, description). Options:

- **Polling:** SPP periodically re-fetches property data. Simple but adds load and has latency.
- **Webhooks:** PWB sends a POST to SPP when a property is updated. Requires a webhook endpoint on SPP and a callback URL stored in `client_theme_config`.
- **Cache headers:** PWB already sets `expires_in 5.hours, public: true` on `api_public` responses (`app/controllers/api_public/v1/base_controller.rb:22`). SPP can respect these cache headers. This works if 5-hour staleness is acceptable.
- **On-demand rebuild:** For static SPP pages, trigger a rebuild when property data changes. Requires a build hook URL.

### 2. SEO — Duplicate Content

If both PWB and SPP serve pages for the same property (even in Option A with different URL paths), search engines may see duplicate content. Coordination needed:

- **Canonical URL:** One of the two pages should have a `<link rel="canonical">` pointing to the other. Which is the canonical?
- **Sitemap:** Only include one URL per property in the sitemap. PWB currently generates sitemaps — should SPP URLs be included instead?
- **JSON-LD:** PWB already generates JSON-LD for property pages (`PropsController` sets `@seo_property`). SPP pages should use the same structured data.
- **`noindex` on PWB:** If SPP is the primary marketing page, consider `noindex`ing PWB's listing detail page for that property.

### 3. Authentication for `api_manage` Endpoints

The publish/unpublish/leads endpoints are under `api_manage`, which requires authentication. How does SPP authenticate?

- SPP's Astro API routes proxy to PWB, adding auth headers. This is the same pattern used for A theme admin routes (see `ClientProxyController#auth_headers` at `app/controllers/pwb/client_proxy_controller.rb:134-141`).
- SPP needs a valid user session or API token for the tenant. The mechanism should be documented.

### 4. Multi-Listing Properties

The current endpoint spec assumes one sale listing per property. Properties can also have rental listings. Should SPP support publish/unpublish for rentals? If so, the endpoints may need a `listing_type` parameter.

### 5. CORS Implementation (Option B Only)

If Option B is chosen, PWB needs CORS support on `api_public` endpoints. This could be:
- A `rack-cors` gem configuration
- A `before_action` in `ApiPublic::V1::BaseController` that sets CORS headers
- Scoped to known SPP origins from `client_theme_config['spp_url']`

---

## Key Reference Files

| File | Relevance |
|------|-----------|
| `app/controllers/pwb/client_proxy_controller.rb` | Existing proxy pattern for A themes — model for Option A |
| `app/controllers/pwb/props_controller.rb` | Current property page rendering (B themes) |
| `app/controllers/api_public/v1/enquiries_controller.rb` | Enquiry submission endpoint |
| `app/controllers/api_public/v1/base_controller.rb` | API base controller (no CORS currently) |
| `app/models/pwb/realty_asset.rb:226-237` | `contextual_show_path` — URL generation |
| `app/controllers/concerns/subdomain_tenant.rb` | Tenant resolution via `X-Website-Slug` |
| `docs/architecture/per_tenant_astro_url_routing.md` | Per-tenant URL config pattern |
| `docs/architecture/client_proxy_controller.md` | Proxy architecture docs |
