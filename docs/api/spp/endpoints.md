# SPP API Endpoints

**Related:** [SPP–PWB Integration](./README.md) | [SppListing Model](./spp-listing-model.md) | [Authentication](./authentication.md)

---

## Publish Property

**Purpose:** Activate an SPP listing for a property, making the SPP page live.

**Path:** `POST /api_manage/v1/:locale/properties/:id/publish`

**Request body:**
```json
{
  "listing_type": "sale"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `listing_type` | string | No | `"sale"` | `"sale"` or `"rental"` |

**Behavior:**
- Find `RealtyAsset` by UUID, scoped to current website
- Find or create `SppListing` for the given `listing_type`
- Set `active: true`, `visible: true`, `archived: false`, `published_at: now`
- Compute and store `live_url` from `spp_url_template` in `client_theme_config`
- PWB's `SaleListing`/`RentalListing` is **not affected**

**`liveUrl` generation:**
```ruby
template = website.client_theme_config['spp_url_template']
listing.live_url = template
  .gsub('{slug}', property.slug)
  .gsub('{uuid}', property.id)
  .gsub('{listing_type}', listing.listing_type)
  .gsub('{locale}', I18n.locale.to_s)
```

**Response (200 OK):**
```json
{
  "status": "published",
  "listingType": "sale",
  "liveUrl": "https://123-main-st-sale.spp.example.com/",
  "publishedAt": "2026-02-12T10:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `"published"` |
| `listingType` | string | `"sale"` or `"rental"` |
| `liveUrl` | string | SPP page URL from `SppListing#live_url` |
| `publishedAt` | ISO 8601 | When the listing was published |

**Errors:** 404 (property not found), 422 (`spp_url_template` not configured, or invalid `listing_type`)

---

## Unpublish Property

**Purpose:** Hide an SPP listing without archiving or deleting it.

**Path:** `POST /api_manage/v1/:locale/properties/:id/unpublish`

**Request body:**
```json
{
  "listing_type": "sale"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `listing_type` | string | No | `"sale"` | `"sale"` or `"rental"` |

**Behavior:**
- Find `RealtyAsset` by UUID, scoped to current website
- Find active `SppListing` for the given `listing_type`
- Set `visible: false` (keep `active: true` for easy re-publish)
- PWB's `SaleListing`/`RentalListing` is **not affected**

**Response (200 OK):**
```json
{
  "status": "draft",
  "listingType": "sale",
  "liveUrl": null
}
```

**Errors:** 404 (property not found), 422 (no active SPP listing of that type)

---

## Property Leads

**Purpose:** Retrieve enquiries for a property, for SPP's leads tab.

**Path:** `GET /api_manage/v1/:locale/properties/:id/leads`

**Behavior:**
- Find `RealtyAsset` by UUID, scoped to current website
- Return messages linked to that property (`realty_asset_id`), newest first
- Leads are property-scoped, not listing-type-scoped

**Response (200 OK):**
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
| `name` | string | Contact name (or "Unknown") |
| `email` | string | Contact email |
| `phone` | string or null | Contact phone |
| `message` | string | Enquiry content |
| `createdAt` | ISO 8601 | Submission time |
| `isNew` | boolean | `read == false` or created within 48 hours |

Returns `[]` when no leads exist (not 404). Returns 404 only when the property doesn't exist.

---

## Supporting Change: Link Enquiries to Properties

PWB's `Message` model has no foreign key to `RealtyAsset`. The enquiry controller receives `property_id` but only uses it for the email notification.

**What's needed:** Store the property reference on the message so the leads endpoint can query by property.

**Suggested approach:**
- Add `realty_asset_id` (UUID, nullable) to `pwb_messages`
- When the enquiry controller processes a `property_id`, store the resolved property's ID
- Add `belongs_to :realty_asset` on `Message`

**Backwards compatibility:** Pre-existing messages will have `realty_asset_id = NULL`. Options:
- Return only directly-linked messages (simplest)
- Fall back to all website messages when none linked (transition period)

---

## Response Conventions

- **Publish/unpublish:** JSON object with `status`, `listingType`, `liveUrl`, and optionally `publishedAt`
- **Leads:** JSON array (not wrapped in `{ data: [...] }`)
- **Errors:** `{ success: false, error: "..." }` — matches PWB's existing `BaseController` error handling

---

## SPP's Current Dev Stubs

SPP uses local stubs while PWB endpoints are being built. These are the shapes SPP's frontend consumes:

**Publish:** `{ "status": "published", "liveUrl": "https://...", "publishedAt": "..." }`

**Unpublish:** `{ "status": "draft", "liveUrl": null }`

**Leads:** `[{ "id": 1, "name": "...", "email": "...", "phone": "...", "message": "...", "createdAt": "...", "isNew": true }]`

Stubs live in `apps/main/src/pages/api/[...path].ts` (`getDevResponse()`). Once PWB implements the real endpoints, SPP routes to PWB instead.
