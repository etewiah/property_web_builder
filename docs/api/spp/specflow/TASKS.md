# SPP-PWB Integration — Tasks

**Spec:** [SPEC.md](./SPEC.md)
**Architecture:** [../README.md](../README.md)

---

## Phase 1: Data Model Foundation

**Goal:** Create the SppListing model and database table so SPP listings can be stored and managed.
**Deliverables:** Migration, model, association on RealtyAsset, factory.
**Dependencies:** None.

---

### Task 1.1: Create SppListing Migration [AI-Assisted]

**Input:**
- Migration spec in [spp-listing-model.md](../spp-listing-model.md#migration)
- Existing `pwb_sale_listings` table as structural reference (`db/schema.rb:853-879`)

**Action:**
Generate a Rails migration creating the `pwb_spp_listings` table with:
- UUID primary key
- State booleans: `active`, `visible`, `archived`, `noindex`
- `realty_asset_id` (UUID, not null, foreign key to `pwb_realty_assets`)
- `listing_type` (string, not null, default `"sale"`)
- `price_cents` (bigint, default 0), `price_currency` (string, default `"EUR"`)
- `photo_ids_ordered` (JSONB, default `[]`)
- `highlighted_features` (JSONB, default `[]`)
- `translations` (JSONB, default `{}`, not null)
- `spp_slug` (string), `live_url` (string), `template` (string)
- `spp_settings` (JSONB, default `{}`), `extra_data` (JSONB, default `{}`)
- `published_at` (datetime)
- Timestamps
- Partial unique index on `(realty_asset_id, listing_type, active)` where `active = true`
- Indexes on `realty_asset_id`, `spp_slug`, `noindex`, `translations` (GIN)
- Foreign key constraint to `pwb_realty_assets`

**Output:** Migration file in `db/migrate/`.

**Verification:**
- `rails db:migrate` succeeds
- `rails db:rollback` succeeds
- Table exists with correct columns: `rails runner "puts Pwb::SppListing.column_names.sort"`
- Unique index enforced: creating two active SppListings with same `realty_asset_id` and `listing_type` raises `ActiveRecord::RecordNotUnique`

---

### Task 1.2: Create SppListing Model [AI-Assisted]

**Input:**
- Model definition in [spp-listing-model.md](../spp-listing-model.md#model-definition)
- `app/models/pwb/sale_listing.rb` (pattern to follow)
- `app/models/concerns/listing_stateable.rb` (interface contract: `listings_of_same_type`)
- `app/models/concerns/ntfy_listing_notifications.rb`
- `app/models/concerns/refreshes_properties_view.rb`

**Action:**
Create `app/models/pwb/spp_listing.rb` including:
- Concerns: `ListingStateable`, `NtfyListingNotifications`, `SeoValidatable`, `RefreshesPropertiesView`
- `Mobility` translations for `title`, `description`, `seo_title`, `meta_description`
- Delegates physical attributes (`reference`, `website`, `website_id`, `count_bedrooms`, `count_bathrooms`, `street_address`, `city`, `latitude`, `longitude`, `slug`) from `realty_asset`
- `monetize :price_cents`
- Validates `realty_asset_id` presence and `listing_type` inclusion in `%w[sale rental]`
- Scopes: `.sale`, `.rental`
- `ordered_photos` method — returns curated PropPhotos from `photo_ids_ordered`, falls back to property default
- `display_features` method — returns highlighted features, falls back to all property features
- Private `listings_of_same_type` scoped to same `listing_type` (required by `ListingStateable`)

**Output:** Model file at `app/models/pwb/spp_listing.rb`.

**Verification:**
- `Pwb::SppListing.new` instantiates without error
- `Pwb::SppListing.create!(realty_asset: property, listing_type: 'sale')` works
- `listing.activate!` and `listing.deactivate!` work (from `ListingStateable`)
- `listing.title = "Test"` stores via Mobility translations
- `listing.ordered_photos` returns photos in curated order when `photo_ids_ordered` is set
- `listing.display_features` returns subset when `highlighted_features` is set

---

### Task 1.3: Add Association on RealtyAsset [AI-Assisted]

**Input:**
- `app/models/pwb/realty_asset.rb` — existing model with `has_many :sale_listings` and `has_many :rental_listings`

**Action:**
Add `has_many :spp_listings, class_name: 'Pwb::SppListing', dependent: :destroy` to `RealtyAsset`.

**Output:** Modified `app/models/pwb/realty_asset.rb`.

**Verification:**
- `property.spp_listings` returns an ActiveRecord relation
- `property.spp_listings.sale` and `property.spp_listings.rental` return scoped results
- Destroying a property cascades to destroy its SPP listings

---

### Task 1.4: Create Factory and Model Specs [AI-Assisted]

**Input:**
- Existing factories: `spec/factories/pwb/sale_listings.rb`, `spec/factories/pwb/realty_assets.rb`
- Model spec pattern: `spec/models/pwb/sale_listing_spec.rb`

**Action:**
1. Create `spec/factories/pwb/spp_listings.rb` with traits for `:sale`, `:rental`, `:published` (active + visible + published_at), `:with_curated_photos`, `:with_highlighted_features`
2. Create `spec/models/pwb/spp_listing_spec.rb` testing:
   - Validations (realty_asset_id required, listing_type inclusion)
   - Scopes (`.sale`, `.rental`)
   - `ListingStateable` integration (activate!, deactivate!, archive!)
   - Uniqueness constraint (only one active per property per listing_type)
   - `ordered_photos` with and without curation
   - `display_features` with and without highlights
   - `monetize` on price_cents
   - Mobility translations
   - Delegation of physical attributes from realty_asset
   - `listings_of_same_type` scoping (sale SppListing doesn't affect rental SppListing)

**Output:** Factory file and spec file.

**Verification:**
- `rspec spec/models/pwb/spp_listing_spec.rb` passes all tests
- Factory builds valid records: `FactoryBot.create(:spp_listing)` works

---

## Phase 2: API Endpoints

**Goal:** Implement the three SPP endpoints (publish, unpublish, leads) so SPP can manage listings and retrieve enquiries.
**Deliverables:** Controller, routes, request specs.
**Dependencies:** Phase 1 (SppListing model must exist).

---

### Task 2.1: Add Enquiry-Property Linking [AI-Assisted]

**Input:**
- `app/models/pwb/message.rb` — currently has no `realty_asset_id`
- `app/controllers/api_public/v1/enquiries_controller.rb` — receives `property_id` param
- [Endpoints doc: Supporting Change](../endpoints.md#supporting-change-link-enquiries-to-properties)

**Action:**
1. Create migration adding `realty_asset_id` (UUID, nullable) to `pwb_messages` with index
2. Add `belongs_to :realty_asset, optional: true` on `Message`
3. Update `EnquiriesController` to store `realty_asset_id` when `property_id` is present in the request

**Output:** Migration, model change, controller change.

**Verification:**
- Submitting an enquiry with `property_id` stores the resolved `realty_asset_id` on the message
- Submitting an enquiry without `property_id` still works (nullable column)
- `Pwb::Message.where(realty_asset_id: property.id)` returns linked messages
- Existing messages are unaffected (NULL `realty_asset_id`)

---

### Task 2.2: Implement Publish Endpoint [AI-Assisted]

**Input:**
- [Endpoints doc: Publish](../endpoints.md#publish-property)
- [SppListing model](../spp-listing-model.md#publish)
- `app/controllers/api_manage/v1/base_controller.rb` — authentication and tenant resolution
- `client_theme_config['spp_url_template']` pattern

**Action:**
Create `POST /api_manage/v1/:locale/properties/:id/spp_publish` endpoint that:
1. Finds `RealtyAsset` by UUID, scoped to `current_website`
2. Accepts `listing_type` param (default `"sale"`)
3. Validates `spp_url_template` exists in `client_theme_config`
4. Finds or initializes `SppListing` for the given listing_type
5. Sets `active: true`, `visible: true`, `archived: false`, `published_at: now`
6. Computes and stores `live_url` from `spp_url_template`
7. Returns `{ status, listingType, liveUrl, publishedAt }`

**Output:** Controller action with route.

**Verification:**
- `POST /api_manage/v1/en/properties/:id/spp_publish` with valid API key returns 200 with correct JSON
- Creates an `SppListing` record with `active: true`, `visible: true`
- `live_url` is correctly interpolated from the template
- Re-publishing updates `published_at` without creating a duplicate
- Returns 404 for non-existent property
- Returns 422 when `spp_url_template` is not configured
- Returns 401 without valid API key
- Publishing sale SPP listing does not affect existing SaleListing or rental SppListing

---

### Task 2.3: Implement Unpublish Endpoint [AI-Assisted]

**Input:**
- [Endpoints doc: Unpublish](../endpoints.md#unpublish-property)
- [SppListing model](../spp-listing-model.md#unpublish)

**Action:**
Create `POST /api_manage/v1/:locale/properties/:id/spp_unpublish` endpoint that:
1. Finds `RealtyAsset` by UUID, scoped to `current_website`
2. Accepts `listing_type` param (default `"sale"`)
3. Finds active `SppListing` for the given listing_type
4. Sets `visible: false` (keeps `active: true` for easy re-publish)
5. Returns `{ status: "draft", listingType, liveUrl: null }`

**Output:** Controller action with route.

**Verification:**
- Unpublishing sets `visible: false` but keeps `active: true`
- Returns 422 when no active SPP listing exists for that type
- Unpublishing sale SPP does not affect rental SPP listing
- Returns 401 without valid API key
- Re-publishing after unpublish restores `visible: true`

---

### Task 2.4: Implement Leads Endpoint [AI-Assisted]

**Input:**
- [Endpoints doc: Leads](../endpoints.md#property-leads)
- Task 2.1 (enquiry-property linking must be done)

**Action:**
Create `GET /api_manage/v1/:locale/properties/:id/spp_leads` endpoint that:
1. Finds `RealtyAsset` by UUID, scoped to `current_website`
2. Queries `Pwb::Message.where(realty_asset_id: property.id).order(created_at: :desc)`
3. Returns JSON array with `id`, `name`, `email`, `phone`, `message`, `createdAt`, `isNew`
4. Returns `[]` for no leads (not 404)

**Output:** Controller action with route.

**Verification:**
- Returns messages linked to the property, newest first
- `isNew` is true when message is unread or created within 48 hours
- Returns empty array for properties with no leads
- Returns 404 for non-existent property
- Returns 401 without valid API key
- Leads from both SPP and PWB enquiries appear (property-scoped, not source-scoped)

---

### Task 2.5: Write Request Specs for All Endpoints [AI-Assisted]

**Input:**
- Tasks 2.1-2.4 implementations
- Existing request spec patterns in `spec/requests/api_manage/`

**Action:**
Create `spec/requests/api_manage/v1/spp_endpoints_spec.rb` covering:
- Authentication (401 without key, 200 with valid key)
- Tenant isolation (cannot access another tenant's properties)
- Publish: creates SppListing, returns correct JSON, idempotent re-publish
- Unpublish: sets visible false, returns correct JSON, 422 when no active listing
- Leads: returns linked messages, empty array for no leads, newest first ordering
- Listing type independence: publishing sale doesn't affect rental and vice versa

**Output:** Request spec file.

**Verification:**
- `rspec spec/requests/api_manage/v1/spp_endpoints_spec.rb` passes all tests

---

## Phase 3: CORS and Authentication Setup

**Goal:** Configure CORS so SPP's browser can POST enquiries, and document the API key provisioning flow.
**Deliverables:** CORS config change, integration setup rake task.
**Dependencies:** None (can run in parallel with Phase 2).

---

### Task 3.1: Add SPP Origins to CORS Config [AI-Assisted]

**Input:**
- `config/initializers/cors.rb` — existing configuration with dev/prod/widget blocks
- [CORS doc](../cors.md)

**Action:**
1. Add SPP domain regex pattern to the production origins block (e.g., `/.*\.spp\.example\.com/`)
2. Add `max_age: 3600` to the production resource block for preflight caching
3. Add SPP's local dev port to the development origins block if not already present

**Output:** Modified `config/initializers/cors.rb`.

**Verification:**
- Preflight `OPTIONS` request from an SPP origin to `/api_public/v1/enquiries` returns correct CORS headers
- `X-Website-Slug` header passes through (covered by existing `headers: :any`)
- Non-SPP origins are still blocked
- Dev origins still work

---

### Task 3.2: Create SPP Integration Provisioning [AI-Assisted]

**Input:**
- `app/models/pwb/website_integration.rb` — existing integration model
- [Authentication doc](../authentication.md)

**Action:**
Create a rake task `spp:provision` that:
1. Takes a website subdomain as argument
2. Creates a `WebsiteIntegration` record with `category: 'spp'`, `provider: 'single_property_pages'`
3. Generates a secure API key via `SecureRandom.hex(32)`
4. Stores the key in encrypted `credentials`
5. Outputs the API key and configuration instructions for SPP

**Output:** Rake task at `lib/tasks/spp.rake`.

**Verification:**
- `rails spp:provision[my-tenant]` creates an integration and outputs the key
- The generated key authenticates successfully against `api_manage` endpoints
- Running the task twice for the same tenant doesn't create duplicates
- `last_used_at` is updated when the key is used for authentication

---

## Phase 4: SEO Coordination

**Goal:** Ensure search engines see SPP as the canonical page when an SPP listing is active, with correct sitemaps and JSON-LD.
**Deliverables:** Helper method, controller changes, sitemap changes.
**Dependencies:** Phase 1 (SppListing model).

---

### Task 4.1: Create `spp_live_url_for` Helper [AI-Assisted]

**Input:**
- [SEO doc: Shared Helper](../seo.md#shared-helper-spp_live_url_for)
- `app/helpers/seo_helper.rb`

**Action:**
Create a shared helper method `spp_live_url_for(property, listing_type = nil)` that:
1. Queries `property.spp_listings.active_listing`
2. Optionally scopes by `listing_type`
3. Returns `first&.live_url` (nil when no active SPP listing exists)

Place in a concern or helper module accessible to `PropsController`, `SitemapsController`, and `SeoHelper`.

**Output:** Helper method in appropriate location.

**Verification:**
- Returns SPP URL when an active, visible SppListing exists
- Returns nil when no SppListing exists
- Returns nil when SppListing exists but is not active
- Scopes correctly by listing_type when provided

---

### Task 4.2: Update Canonical URL on PWB Property Pages [AI-Assisted]

**Input:**
- `app/controllers/pwb/props_controller.rb:152-190` — `set_property_seo` method
- `app/helpers/seo_helper.rb:51-53` — `seo_canonical_url` rendering
- [SEO doc: Canonical URL](../seo.md#1-canonical-url-on-pwbs-property-page)

**Action:**
In `PropsController#set_property_seo`, check for an SPP live URL. If present, use it as the canonical URL instead of PWB's URL. Pass the appropriate `listing_type` based on the current page context (sale page passes `"sale"`, rental page passes `"rental"`).

**Output:** Modified `app/controllers/pwb/props_controller.rb`.

**Verification:**
- PWB's sale property page has `<link rel="canonical" href="https://...spp...">` when a sale SppListing is active
- PWB's rental property page canonicals to the rental SppListing URL
- PWB's property page uses its own URL as canonical when no SppListing exists
- No change in behavior for properties without SPP listings

---

### Task 4.3: Update Sitemap to Use SPP URLs [AI-Assisted]

**Input:**
- `app/controllers/sitemaps_controller.rb` — sitemap generation
- `app/views/sitemaps/index.xml.erb` — sitemap XML template
- [SEO doc: Sitemap Coordination](../seo.md#4-sitemap-coordination)

**Action:**
In the sitemap view, when building the `<loc>` for each property, check for an SPP URL via `spp_live_url_for`. If present, use the SPP URL instead of the PWB property URL.

**Output:** Modified sitemap template.

**Verification:**
- Sitemap contains SPP URL for properties with active SppListings
- Sitemap contains PWB URL for properties without SppListings
- Sitemap is valid XML

---

### Task 4.4: Update JSON-LD to Use SPP URL [AI-Assisted]

**Input:**
- `app/helpers/seo_helper.rb:160-245` — `property_json_ld` method
- [SEO doc: JSON-LD](../seo.md#5-json-ld-structured-data)

**Action:**
In `SeoHelper#property_json_ld`, check for an SPP URL. If present, use it as the `url` field in the `RealEstateListing` JSON-LD.

**Output:** Modified `app/helpers/seo_helper.rb`.

**Verification:**
- JSON-LD `url` field points to SPP when an active SppListing exists
- JSON-LD `url` field points to PWB when no SppListing exists
- JSON-LD is valid (test with Google's structured data testing tool)

---

## Phase 5: Data Freshness (Phase 1 — Cache Headers)

**Goal:** Ensure SPP gets reasonably fresh data from PWB's API without new infrastructure.
**Deliverables:** Cache TTL change on property detail endpoint.
**Dependencies:** None (can run in parallel).

---

### Task 5.1: Reduce Cache TTL on Property Detail API [AI-Assisted]

**Input:**
- `app/controllers/api_public/v1/base_controller.rb:21-22` — current `expires_in 5.hours, public: true`
- [Data Freshness doc: Phase 1](../data-freshness.md#phase-1-reduce-cache-ttl-immediate)

**Action:**
Reduce the `expires_in` on the property detail endpoint (`show` action) from 5 hours to 1 hour. Keep the 5-hour TTL on list/index endpoints where staleness is less critical.

**Output:** Modified controller.

**Verification:**
- Property detail API response includes `Cache-Control: max-age=3600, public`
- Property list API still returns `Cache-Control: max-age=18000, public`

---

## Phase 6: SppListing Content Management Endpoint

**Goal:** Allow SPP's admin UI to update SppListing content (texts, price, photos, features, settings).
**Deliverables:** PUT endpoint, request specs.
**Dependencies:** Phase 1 (SppListing model), Phase 2 (api_manage routing established).

---

### Task 6.1: Implement SppListing Update Endpoint [AI-Assisted]

**Input:**
- [SppListing model: Content Management](../spp-listing-model.md#how-spp-manages-these-texts)
- Existing `api_manage` patterns

**Action:**
Create `PUT /api_manage/v1/:locale/spp_listings/:id` endpoint that:
1. Finds `SppListing` by UUID, scoped to current website (via `realty_asset.website`)
2. Accepts: `title`, `description`, `seo_title`, `meta_description` (translated via Mobility), `price_cents`, `price_currency`, `photo_ids_ordered`, `highlighted_features`, `template`, `spp_settings`, `extra_data`
3. Validates `photo_ids_ordered` contains only IDs of PropPhotos belonging to the same RealtyAsset
4. Updates and saves
5. Returns the updated SppListing as JSON

**Output:** Controller action with route and request specs.

**Verification:**
- Updating title in English stores via Mobility translations
- Updating `photo_ids_ordered` with valid photo IDs succeeds
- Updating `photo_ids_ordered` with photo IDs from a different property fails (422)
- `extra_data` accepts arbitrary JSON
- Returns 404 for SppListings belonging to other tenants
- Returns 401 without valid API key

---

## Implementation Order

```
Phase 1: Data Model ──────────────────┐
  1.1 Migration                       │
  1.2 Model                           │
  1.3 RealtyAsset association         │
  1.4 Factory + specs                 │
                                      ▼
Phase 2: Endpoints ──────┐     Phase 3: CORS + Auth ──┐     Phase 5: Cache TTL
  2.1 Enquiry linking    │       3.1 CORS config       │       5.1 Reduce TTL
  2.2 Publish            │       3.2 Provisioning      │
  2.3 Unpublish          │                             │
  2.4 Leads              │                             │
  2.5 Request specs      │                             │
                         ▼                             ▼
               Phase 4: SEO ──────────────────────────────────
                 4.1 spp_live_url_for helper
                 4.2 Canonical URL
                 4.3 Sitemap
                 4.4 JSON-LD
                                      │
                                      ▼
                            Phase 6: Content Mgmt
                              6.1 Update endpoint
```

Phases 2, 3, and 5 can proceed in parallel after Phase 1. Phase 4 depends on Phase 1. Phase 6 depends on Phases 1 and 2.
