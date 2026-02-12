# SPP API Endpoints

**Status:** Implemented
**Related:** [SPP–PWB Integration](./README.md) | [SppListing Model](./spp-listing-model.md) | [Authentication](./authentication.md)

---

## Publish Property

**Purpose:** Activate an SPP listing for a property, making the SPP page live.

**Path:** `POST /api_manage/v1/:locale/properties/:id/spp_publish`

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

**Path:** `POST /api_manage/v1/:locale/properties/:id/spp_unpublish`

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

**Path:** `GET /api_manage/v1/:locale/properties/:id/spp_leads`

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

## Update SPP Listing Content

**Purpose:** Allow SPP's admin UI to update listing content — translated texts, price, curated photos, features, template, and settings.

**Path:** `PUT /api_manage/v1/:locale/spp_listings/:id`

**Request body:**
```json
{
  "title": "Your Dream Mediterranean Retreat",
  "description": "Imagine waking up to the sound of waves...",
  "seo_title": "Luxury Biarritz Apartment",
  "meta_description": "Stunning 3-bed apartment in Biarritz...",
  "price_cents": 45000000,
  "price_currency": "EUR",
  "photo_ids_ordered": [42, 17, 3, 28, 11],
  "highlighted_features": ["sea_views", "private_pool", "parking"],
  "template": "luxury",
  "spp_settings": { "color_scheme": "dark", "layout": "full-width" },
  "extra_data": {
    "agent_name": "Marie Dupont",
    "video_tour_url": "https://youtube.com/watch?v=abc123"
  }
}
```

All fields are optional — send only the fields you want to update.

| Parameter | Type | Description |
|-----------|------|-------------|
| `title` | string | Marketing headline (Mobility-translated per `:locale`) |
| `description` | string | Marketing description (Mobility-translated) |
| `seo_title` | string | SEO title tag (Mobility-translated) |
| `meta_description` | string | SEO meta description (Mobility-translated) |
| `price_cents` | integer | Price in cents (e.g., `45000000` = 450,000.00) |
| `price_currency` | string | ISO 4217 currency code |
| `photo_ids_ordered` | array of integers | PropPhoto IDs in display order. Must belong to the same property. Empty array resets to default order. |
| `highlighted_features` | array of strings | Feature keys to spotlight (e.g., `["sea_views", "pool"]`) |
| `template` | string | SPP template name (e.g., `"luxury"`, `"modern"`) |
| `spp_settings` | object | Template-specific settings (colors, layout options) |
| `extra_data` | object | Arbitrary JSON for future needs |

**Behavior:**
- Finds `SppListing` by UUID, scoped to current website (via `realty_asset.website_id`)
- Sets `I18n.locale` from the `:locale` route param, so Mobility writes translations to the correct locale
- Validates `photo_ids_ordered` — all IDs must belong to PropPhotos of the same RealtyAsset
- Casts photo IDs to integers for clean JSONB storage
- Returns the full updated listing as JSON

**Response (200 OK):**
```json
{
  "id": "abc-123-uuid",
  "listingType": "sale",
  "title": "Your Dream Mediterranean Retreat",
  "description": "Imagine waking up to the sound of waves...",
  "seoTitle": "Luxury Biarritz Apartment",
  "metaDescription": "Stunning 3-bed apartment in Biarritz...",
  "priceCents": 45000000,
  "priceCurrency": "EUR",
  "photoIdsOrdered": [42, 17, 3, 28, 11],
  "highlightedFeatures": ["sea_views", "private_pool", "parking"],
  "template": "luxury",
  "sppSettings": { "color_scheme": "dark", "layout": "full-width" },
  "extraData": { "agent_name": "Marie Dupont", "video_tour_url": "..." },
  "active": true,
  "visible": true,
  "liveUrl": "https://123-main-st-sale.spp.example.com/",
  "publishedAt": "2026-02-12T10:30:00Z",
  "updatedAt": "2026-02-12T11:00:00Z"
}
```

**Errors:** 404 (listing not found or belongs to other tenant), 422 (invalid photo IDs from different property), 401 (not authenticated)

---

## Supporting Change: Link Enquiries to Properties (Done)

The `pwb_messages` table now has a `realty_asset_id` column (UUID, nullable) that links enquiries to specific properties. The enquiry controller (`api_public/v1/enquiries_controller.rb`) stores the resolved property's ID when `property_id` is present.

Pre-existing messages have `realty_asset_id = NULL` — the leads endpoint returns only directly-linked messages.

---

## Response Conventions

- **Publish/unpublish:** JSON object with `status`, `listingType`, `liveUrl`, and optionally `publishedAt`
- **Leads:** JSON array (not wrapped in `{ data: [...] }`)
- **Errors:** `{ success: false, error: "..." }` — matches PWB's existing `BaseController` error handling

---

## Implementation Files

| File | Relevance |
|------|-----------|
| `app/controllers/api_manage/v1/spp_listings_controller.rb` | All SPP endpoints (publish, unpublish, leads, update) |
| `spec/requests/api_manage/v1/spp_listings_spec.rb` | 30 specs for publish, unpublish, leads |
| `spec/requests/api_manage/v1/spp_listings_update_spec.rb` | 15 specs for content management update |
| `db/migrate/20260212163000_add_realty_asset_id_to_pwb_messages.rb` | Enquiry-property linking migration |
