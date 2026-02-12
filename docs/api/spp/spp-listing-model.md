# SPP Listing Model

**Status:** Proposed
**Related:** [SPP–PWB Integration](./README.md) | [Endpoints](./endpoints.md)

---

## Summary

An SPP page is a listing — the same kind of thing as a `SaleListing` or `RentalListing`, but for a different channel. A `RealtyAsset` can have PWB listings and SPP listings simultaneously, each with its own texts, publication state, and timing. The `SppListing` model follows the exact same pattern as the existing listing models.

A property that is both for sale and for rent can have two SPP listings — one sale-focused, one rental-focused — with different marketing copy, URLs, and publication states. The `listing_type` field on `SppListing` distinguishes them.

## The Model

### Relationship to Existing Listings

```
                        RealtyAsset
                       (the property)
                  /         |          \
          SaleListing  RentalListing  SppListing(s)
          (PWB sale)   (PWB rental)   (SPP pages)
                                      /          \
                              SppListing       SppListing
                              listing_type:    listing_type:
                              "sale"           "rental"
```

All listing types:
- Belong to the same `RealtyAsset`
- Have independent publication states (`active`, `visible`, `archived`)
- Have their own translated marketing texts (`title`, `description`)
- Have their own SEO fields (`seo_title`, `meta_description`)
- Include `ListingStateable`, `NtfyListingNotifications`, `RefreshesPropertiesView`

SppListing goes further than SaleListing/RentalListing in independence — it controls its own price, curated photo selection and order, and highlighted features, rather than delegating everything from `RealtyAsset`.

For `SppListing`, the uniqueness constraint is scoped by `(realty_asset_id, listing_type)` — only one active SPP listing per property per listing type.

### Why Sale and Rental SPP Variants?

A property for sale and a property for rent serve different audiences with different marketing:

| Aspect | SPP Sale Page | SPP Rental Page |
|--------|--------------|-----------------|
| Headline | "Your Dream Mediterranean Retreat" | "Luxury Biarritz Summer Rental" |
| Price featured | Sale price | Monthly rent |
| Target audience | Buyers, investors | Holidaymakers, relocators |
| URL | `123-main-st-for-sale.spp.example.com` | `123-main-st-rental.spp.example.com` |
| SEO | Targets "buy apartment Biarritz" | Targets "rent apartment Biarritz" |

These are genuinely different pages, not just the same page with a different price.

### What SppListing Controls Independently

SaleListing and RentalListing delegate most data (photos, features, location) to `RealtyAsset`. An SppListing is designed to be as self-contained as possible — a purpose-built marketing page that curates its own presentation:

- **Own price.** `price_cents` / `price_currency`, set independently. Can be pre-populated from a PWB listing when first created, but the SppListing owns it.
- **Curated photos.** `photo_ids_ordered` — a JSONB array of `PropPhoto` IDs in the display order the SPP page wants. The property might have 20 photos; the SPP sale page might show 8 in a specific order with a different hero image than the rental page. Photos not in the array aren't shown. An empty/null array falls back to the property's default photo order.
- **Highlighted features.** `highlighted_features` — a JSONB array of feature keys to spotlight on the SPP page. The property's full feature list lives on `RealtyAsset`, but the SPP page picks which to emphasize (e.g., `["sea_views", "private_pool", "parking"]`).
- **Listing type.** `listing_type` — `"sale"` or `"rental"`, determining the marketing angle.
- **Template/theme.** `template` — which SPP template to render (e.g., `"luxury"`, `"modern"`).
- **URL tracking.** `spp_slug` (URL slug on the SPP domain) and `live_url` (full computed URL when published).
- **Expansion field.** `extra_data` — a general-purpose JSONB column for future needs without requiring migrations. Examples: custom color schemes, agent override info, video tour URLs, testimonial quotes, or any feature not yet anticipated.

### Table Schema: `pwb_spp_listings`

```ruby
create_table "pwb_spp_listings", id: :uuid, default: -> { "gen_random_uuid()" } do |t|
  # Core state (same as SaleListing)
  t.boolean  "active",    default: false, null: false
  t.boolean  "visible",   default: false
  t.boolean  "archived",  default: false
  t.boolean  "noindex",   default: false, null: false

  # Relationship
  t.uuid     "realty_asset_id", null: false

  # Listing type — "sale" or "rental"
  t.string   "listing_type", null: false, default: "sale"

  # Price
  t.bigint   "price_cents",    default: 0, null: false
  t.string   "price_currency", default: "EUR", null: false

  # Curated content
  t.jsonb    "photo_ids_ordered",     default: []     # Ordered array of PropPhoto IDs for this page
  t.jsonb    "highlighted_features",  default: []     # Feature keys to spotlight (e.g., ["sea_views", "pool"])

  # Translations (title, description, seo_title, meta_description)
  t.jsonb    "translations", default: {}, null: false

  # SPP-specific fields
  t.string   "spp_slug"        # URL slug on the SPP domain (e.g., "123-main-street")
  t.string   "live_url"        # Computed full URL when published
  t.string   "template"        # SPP template/theme name (e.g., "luxury", "modern")
  t.jsonb    "spp_settings",   default: {}  # SPP-specific config (colors, layout options, template settings)
  t.jsonb    "extra_data",     default: {}  # General-purpose expansion field for future needs
  t.datetime "published_at"    # When the listing was last published

  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false

  # Only one active SPP listing per property per listing type
  t.index ["realty_asset_id", "listing_type", "active"],
          name: "index_pwb_spp_listings_unique_active",
          unique: true, where: "(active = true)"
  t.index ["realty_asset_id"], name: "index_pwb_spp_listings_on_realty_asset_id"
  t.index ["spp_slug"], name: "index_pwb_spp_listings_on_spp_slug"
  t.index ["noindex"], name: "index_pwb_spp_listings_on_noindex"
  t.index ["translations"], name: "index_pwb_spp_listings_on_translations", using: :gin
end
```

### Model Definition

```ruby
# app/models/pwb/spp_listing.rb
module Pwb
  class SppListing < ApplicationRecord
    include NtfyListingNotifications
    include ListingStateable
    include SeoValidatable
    include RefreshesPropertiesView
    extend Mobility

    self.table_name = 'pwb_spp_listings'

    LISTING_TYPES = %w[sale rental].freeze

    belongs_to :realty_asset, class_name: 'Pwb::RealtyAsset'

    # Same translated fields as SaleListing
    translates :title, :description, :seo_title, :meta_description

    # Delegate physical property attributes from realty_asset
    delegate :reference, :website, :website_id,
             :count_bedrooms, :count_bathrooms, :street_address, :city,
             :latitude, :longitude, :slug,
             to: :realty_asset, allow_nil: true

    monetize :price_cents, with_model_currency: :price_currency

    validates :realty_asset_id, presence: true
    validates :listing_type, presence: true, inclusion: { in: LISTING_TYPES }

    scope :sale, -> { where(listing_type: 'sale') }
    scope :rental, -> { where(listing_type: 'rental') }

    # Curated photo list — returns PropPhotos in the order specified by this listing.
    # Falls back to the property's default photo order if no curation is set.
    def ordered_photos
      if photo_ids_ordered.present?
        photos_by_id = realty_asset.prop_photos.index_by(&:id)
        photo_ids_ordered.filter_map { |id| photos_by_id[id] }
      else
        realty_asset.prop_photos
      end
    end

    # Curated feature list — returns only the highlighted features for this listing.
    # Falls back to all property features if no highlights are set.
    def display_features
      if highlighted_features.present?
        all_features = realty_asset.features
        highlighted_features.filter_map { |key| all_features.find { |f| f['key'] == key } }
      else
        realty_asset.features
      end
    end

    private

    # Required by ListingStateable — scoped to same listing_type
    def listings_of_same_type
      realty_asset&.spp_listings&.where(listing_type: listing_type) || self.class.none
    end
  end
end
```

### RealtyAsset Association

Add to `app/models/pwb/realty_asset.rb`:

```ruby
has_many :spp_listings, class_name: 'Pwb::SppListing', dependent: :destroy
```

## How This Changes the Endpoints

### Publish

The publish endpoint creates or activates an `SppListing` for the specified listing type:

```ruby
# POST /api_manage/v1/:locale/properties/:id/publish
property = current_website.realty_assets.find(params[:id])
listing_type = params[:listing_type] || 'sale'

listing = property.spp_listings
  .where(listing_type: listing_type)
  .first_or_initialize(listing_type: listing_type)

listing.assign_attributes(
  active: true,
  visible: true,
  archived: false,
  published_at: Time.current,
  live_url: compute_spp_live_url(property, listing)
)
listing.save!

render json: {
  status: "published",
  listingType: listing.listing_type,
  liveUrl: listing.live_url,
  publishedAt: listing.published_at.iso8601
}
```

**Key points:**
- `listing_type` defaults to `"sale"` if omitted (backwards compatible)
- Publishing the sale SPP listing does not affect the rental SPP listing (or any PWB listing)
- A property can have both a sale and rental SPP page published simultaneously

### Unpublish

```ruby
# POST /api_manage/v1/:locale/properties/:id/unpublish
property = current_website.realty_assets.find(params[:id])
listing_type = params[:listing_type] || 'sale'

listing = property.spp_listings
  .where(listing_type: listing_type)
  .active_listing.first

if listing.nil?
  render json: { error: "No active SPP #{listing_type} listing" }, status: :unprocessable_entity
  return
end

listing.update!(visible: false)

render json: {
  status: "draft",
  listingType: listing.listing_type,
  liveUrl: nil
}
```

### Leads

Leads are linked to the `RealtyAsset`, not to a specific listing type. All enquiries for a property appear in the same list regardless of whether they came from the sale SPP page, rental SPP page, or PWB:

```ruby
# GET /api_manage/v1/:locale/properties/:id/leads
property = current_website.realty_assets.find(params[:id])
messages = Pwb::Message.where(realty_asset_id: property.id).order(created_at: :desc)
```

If distinguishing lead source matters later, the enquiry form can include `source: "spp"` and `listing_type: "sale"` fields.

## How This Changes Other Documents

### Publishing Lifecycle

The [endpoints doc](./endpoints.md) describes the publish flow. With listing type support:

```
SPP                              PWB
 │                                │
 │  POST /publish                 │
 │  { listing_type: "sale" }      │
 │ ──────────────────────────────▶│  1. Create/activate SppListing (sale)
 │                                │  2. Set visible: true, published_at: now
 │                                │  3. Compute live_url from spp_url_template
 │  { status, listingType,        │
 │    liveUrl, publishedAt }      │
 │ ◀──────────────────────────────│
 │                                │
 │  POST /publish                 │
 │  { listing_type: "rental" }    │
 │ ──────────────────────────────▶│  4. Create/activate SppListing (rental)
 │                                │     (sale SPP listing untouched)
 │  { status, listingType,        │
 │    liveUrl, publishedAt }      │
 │ ◀──────────────────────────────│
```

Each listing type is independent. The SaleListings and RentalListings on PWB are untouched by either.

### SEO Coordination

The [SEO doc](./seo.md) describes `spp_live_url_for`. With listing types, this becomes:

```ruby
def spp_live_url_for(property, listing_type = nil)
  scope = property.spp_listings.active_listing
  scope = scope.where(listing_type: listing_type) if listing_type
  scope.first&.live_url
end
```

PWB's sale property page should canonical to the sale SPP listing. PWB's rental property page should canonical to the rental SPP listing.

### Data Freshness

The [data freshness doc](./data-freshness.md) analysis still applies. Each SppListing has its own texts, price, curated photos, and highlighted features. Physical property attributes (location, bedrooms) come from `RealtyAsset`. Note that if new photos are added to the property on PWB, they won't automatically appear on an SPP page unless added to its `photo_ids_ordered` array.

### URL Generation

The `spp_url_template` can include a `{listing_type}` placeholder:

```json
{
  "spp_url_template": "https://{slug}-{listing_type}.spp.example.com/"
}
```

This produces:
- `https://123-main-st-sale.spp.example.com/` for the sale SPP page
- `https://123-main-st-rental.spp.example.com/` for the rental SPP page

Or without the placeholder, both types share a domain and use path segments — SPP decides its URL structure.

## What Each Listing Controls

Each SppListing is independent — its own texts, price, photos, and features, all separate from the PWB listings and from each other:

**Example for a property with 20 photos and 12 features, both for sale and for rent:**

| Field | SaleListing (PWB) | RentalListing (PWB) | SppListing sale | SppListing rental |
|-------|-------------------|---------------------|-----------------|-------------------|
| title | "3-bed apartment in Biarritz" | "3-bed apartment - monthly rental" | "Your Dream Mediterranean Retreat" | "Luxury Biarritz Summer Rental" |
| description | "Spacious apartment..." | "Available for rental..." | "Imagine waking up to waves..." | "The perfect summer getaway..." |
| price | 450,000 EUR | 2,500 EUR/month | 450,000 EUR | 2,800 EUR/month |
| photos | All 20 (property order) | All 20 (property order) | 8 photos, pool hero shot first | 6 photos, terrace hero shot first |
| features | All 12 (property order) | All 12 (property order) | 4 highlighted: sea views, pool, parking, garden | 3 highlighted: terrace, beach access, AC |

The property's physical data (3 bedrooms, 120m², Biarritz) comes from the shared `RealtyAsset`. Each SppListing stores its own price, curated photo order, and highlighted features.

### How SPP Manages These Texts

SPP's content management UI writes to the SppListing's translated fields via `api_manage`. A new endpoint or an extension of the existing property update endpoint:

```
PUT /api_manage/v1/:locale/spp_listings/:id
{
  "title": "Your Dream Mediterranean Retreat",
  "description": "Imagine waking up to the sound of waves...",
  "seo_title": "Luxury Biarritz Apartment",
  "meta_description": "Stunning 3-bed apartment in Biarritz...",
  "price_cents": 450000_00,
  "price_currency": "EUR",
  "photo_ids_ordered": [42, 17, 3, 28, 11],
  "highlighted_features": ["sea_views", "private_pool", "parking"],
  "template": "luxury",
  "extra_data": {
    "agent_name": "Marie Dupont",
    "agent_phone": "+33 6 12 34 56 78",
    "video_tour_url": "https://youtube.com/watch?v=..."
  }
}
```

This endpoint is not part of the initial publish/unpublish/leads spec but should be planned for.

## Migration

```ruby
class CreatePwbSppListings < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_spp_listings, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.boolean  :active,    default: false, null: false
      t.boolean  :visible,   default: false
      t.boolean  :archived,  default: false
      t.boolean  :noindex,   default: false, null: false

      t.uuid     :realty_asset_id, null: false
      t.string   :listing_type, null: false, default: "sale"

      t.bigint   :price_cents,    default: 0, null: false
      t.string   :price_currency, default: "EUR", null: false

      t.jsonb    :photo_ids_ordered,     default: []
      t.jsonb    :highlighted_features,  default: []

      t.jsonb    :translations, default: {}, null: false

      t.string   :spp_slug
      t.string   :live_url
      t.string   :template
      t.jsonb    :spp_settings, default: {}
      t.jsonb    :extra_data, default: {}
      t.datetime :published_at

      t.timestamps
    end

    add_index :pwb_spp_listings, :realty_asset_id
    add_index :pwb_spp_listings, [:realty_asset_id, :listing_type, :active],
              name: "index_pwb_spp_listings_unique_active",
              unique: true, where: "(active = true)"
    add_index :pwb_spp_listings, :spp_slug
    add_index :pwb_spp_listings, :noindex
    add_index :pwb_spp_listings, :translations, using: :gin

    add_foreign_key :pwb_spp_listings, :pwb_realty_assets,
                    column: :realty_asset_id, type: :uuid
  end
end
```

## Implementation Checklist

1. Create migration for `pwb_spp_listings` table (with `listing_type` column)
2. Create `Pwb::SppListing` model with concerns and `listing_type` validation
3. Add `has_many :spp_listings` to `RealtyAsset`
4. Update publish endpoint to accept `listing_type` param, create/activate SppListing
5. Update unpublish endpoint to accept `listing_type` param, target correct SppListing
6. Update leads endpoint to query by `realty_asset_id`
7. Add SppListing to the materialized view refresh (via `RefreshesPropertiesView` — automatic)
8. Add SppListing content management endpoint (for SPP's text editing)
9. Update `spp_live_url_for` helper to accept `listing_type` parameter
10. Test: publish/unpublish sale SppListing independently of rental SppListing
11. Test: both sale and rental SPP pages active simultaneously
12. Test: `ListingStateable` uniqueness constraint scoped by `listing_type`

## Reference Files

| File | Relevance |
|------|-----------|
| `app/models/pwb/sale_listing.rb` | Model to mirror for SppListing |
| `app/models/pwb/rental_listing.rb` | Another listing model following the same pattern |
| `app/models/concerns/listing_stateable.rb` | State management (activate!, deactivate!, archive!) |
| `app/models/concerns/ntfy_listing_notifications.rb` | Push notifications on state changes |
| `app/models/concerns/refreshes_properties_view.rb` | Materialized view refresh |
| `app/models/pwb/realty_asset.rb` | Property model — add `has_many :spp_listings` |
| `db/schema.rb:853-879` | `pwb_sale_listings` table definition (structural reference) |
