# HPG Integration: Codebase Research

## 1. CORS Configuration

**File:** `config/initializers/cors.rb`

Current structure has 3 CORS blocks:

1. **Development** (line 3-9): Allows `localhost:4200`, `4321`, `4322`, `4323` — no `max_age`
2. **Production** (line 11-21): Allows `*.workers.dev`, `*.propertywebbuilder.com`, `*.spp.propertywebbuilder.com` — with `max_age: 3600`
3. **Widgets** (line 23-44): Allows `*` origin but only for `/api_public/v1/widgets/*`, `/widget.js`, `/widget/*`

**What HPG needs:**
- Production origins: `https://housepriceguess.com`, `*.housepriceguess.com`
- Dev origin: `http://localhost:4321` (already included in block 1)
- Full method support (GET, POST for estimates)
- HPG routes are under `/api_public/v1/hpg/*` which is NOT covered by the widget wildcard

**Plan:** Add a new `allow` block after the production block (line 21) specifically for HPG origins.

---

## 2. WebsiteIntegration Model

**File:** `app/models/pwb/website_integration.rb`

### CATEGORIES Hash (line 68-119)

Currently 10 categories: `ai`, `crm`, `email_marketing`, `analytics`, `payment`, `maps`, `storage`, `communication`, `video`, `spp`.

The category validation (line 122) checks inclusion in `CATEGORIES.keys.map(&:to_s)`, so adding `hpg` to the hash is sufficient.

### Key Methods Used by HPG

- `credential('api_key')` — For authenticating HPG admin requests (future Phase 4)
- `record_usage!` — Touch `last_used_at` on each API request
- `connected?` / `status` — For admin dashboard reporting

### Validation Constraint

`provider` must be unique per `[website_id, category]` (line 124). Each HPG website will have exactly one `hpg` integration.

---

## 3. Routes Configuration

**File:** `config/routes.rb`

### api_public namespace (lines 895-993)

The `api_public/v1` namespace has two sections:
1. **Locale-prefixed** (line 902-937): `/:locale/properties`, etc.
2. **Non-locale** (line 939-992): `/properties`, etc.

HPG endpoints do NOT need locale prefixing — games are not locale-dependent. The HPG `scope :hpg` block goes inside `namespace :v1` but outside the locale scope, similar to `/enquiries`, `/contact`, `/favorites`.

### Existing game routes (from price_game_controller)

```ruby
get  "/g/:token" => "price_game#show"
post "/g/:token/guess" => "price_game#guess"
post "/g/:token/share" => "price_game#track_share"
```

These are server-rendered HTML endpoints in `Pwb::PriceGameController`. The HPG API endpoints are completely separate — they return JSON for the external Astro frontend.

---

## 4. API Public Base Controller

**File:** `app/controllers/api_public/v1/base_controller.rb`

```ruby
class BaseController < ActionController::Base
  include SubdomainTenant       # → sets Pwb::Current.website
  include ApiPublic::ResponseEnvelope  # → render_envelope, render_success, render_created
  include ApiPublic::ErrorHandler      # → rescue_from handlers
  include ApiPublic::SparseFieldsets   # → sparse fieldsets support
  include ActiveStorage::SetCurrent

  skip_before_action :verify_authenticity_token
  before_action :set_api_public_cache_headers  # → 1 hour public cache
end
```

**Key behaviors inherited by all HPG controllers:**
- Multi-tenancy via `SubdomainTenant` (resolves `current_website`)
- No CSRF protection (API is stateless)
- 1-hour public cache with `Vary: Accept-Language, X-Website-Slug`
- Standard error responses via `ErrorHandler`
- `render_envelope(data:, meta:)` for standard response format

**Important:** HPG controllers need to **override cache headers** for write endpoints (estimates). The `before_action :set_api_public_cache_headers` sets 1-hour cache on ALL actions. HPG's `estimates#create` and `access_codes#check` should NOT be cached.

---

## 5. SubdomainTenant Concern

**File:** `app/controllers/concerns/subdomain_tenant.rb`

Resolution priority:
1. `X-Website-Slug` header — HPG frontend will use this
2. Custom domain match
3. Subdomain match
4. Fallback to `Pwb::Website.first`

Sets both `Pwb::Current.website` and `ActsAsTenant.current_tenant`.

**Note:** `Website#slug` always returns `"website"` (line 247-249 of website.rb). This means `X-Website-Slug: website` would match the first website. HPG multi-tenancy will use `subdomain` matching instead — the HPG frontend sends `X-Website-Slug` with the subdomain value, and `find_by(slug:)` returns nil, then falls back to subdomain resolution.

**Wait — this is a problem.** The `X-Website-Slug` header checks `Pwb::Website.find_by(slug: slug)`. But `slug` is a method that always returns `"website"`, NOT a database column. Let me re-check...

Actually, looking at the schema (line 81), `slug` IS a database column (`slug :string`). The method `def slug; "website"; end` (line 247) OVERRIDES the column accessor. So if a website record has `slug: "hpg-london"` in the database, `find_by(slug: "hpg-london")` would work at the SQL level even though the Ruby accessor returns "website".

**Conclusion:** HPG frontend should use `X-Website-Slug` with the website's subdomain value (e.g., `hpg-london`). The `find_by(slug:)` call queries the database column directly, bypassing the Ruby method override. We need to ensure HPG websites have their `slug` column set to a unique value (not just the subdomain).

**Alternative:** HPG frontend could use the subdomain in the Host header instead.

---

## 6. SPP Listings Controller (Reference Pattern)

**File:** `app/controllers/api_manage/v1/spp_listings_controller.rb`

This is the closest reference for HPG's admin endpoints (Phase 4). Key patterns:

- Inherits from `ApiManage::V1::BaseController` (which has auth)
- Uses `before_action :require_user!` for all actions
- Scopes queries: `Pwb::RealtyAsset.where(website_id: current_website.id).find(params[:id])`
- Returns camelCase JSON keys (`listingType`, `priceCents`, `publishedAt`)
- Uses ISO8601 for timestamps
- Has `set_property` / `set_spp_listing` before_actions for DRY lookup

**For HPG public controllers:** No auth required (public game API), but still scoped to `current_website`.

---

## 7. ScoreCalculator Service

**File:** `app/services/pwb/price_game/score_calculator.rb`

Already exists and will be reused by HPG's `GameEstimate` model.

### Interface

```ruby
calculator = Pwb::PriceGame::ScoreCalculator.new(
  guessed_cents: 28000000,
  actual_cents: 30000000
)
calculator.score          # => 90 (integer 0-100)
calculator.percentage_diff # => -6.67 (signed float)
calculator.feedback_message # => "Amazing guess! 6.7% below."
calculator.emoji           # => "👏"
calculator.result          # => { score:, percentage_diff:, feedback:, emoji: }
```

### Score Brackets

| % diff | Score | Key |
|--------|-------|-----|
| 0-5%   | 100   | excellent |
| 5-10%  | 90    | amazing |
| 10-15% | 80    | great |
| 15-20% | 70    | very_close |
| 20-25% | 60    | good |
| 25-35% | 50    | not_bad |
| 35-50% | 40    | keep_trying |
| 50-75% | 30    | room_for_improvement |
| 75-100%| 20    | way_off |
| 100%+  | 10    | better_luck |

**Note:** Percentage diff is signed (positive = above, negative = below). Score uses absolute value.

---

## 8. PriceGuess Model (Existing Simple Game)

**File:** `app/models/pwb/price_guess.rb`

Existing model for the simple per-listing "Guess the Price" game:

- UUID primary key
- Polymorphic `belongs_to :listing` (SaleListing or RentalListing)
- One guess per visitor per listing (unique constraint on `[listing_type, listing_id, visitor_token]`)
- Auto-calculates score via `ScoreCalculator` in `before_validation`
- Uses `monetize` gem for price formatting

**HPG's `GameEstimate` will differ:**
- Belongs to `GameSession` (not directly to a listing)
- Belongs to `GameListing` (a join table, not a polymorphic listing)
- Multiple estimates per session (one per game listing)
- No `monetize` needed (HPG formats on frontend)

---

## 9. Gameable Concern

**File:** `app/models/concerns/gameable.rb`

Adds game functionality to `SaleListing`/`RentalListing`:
- `game_token`, `game_enabled`, `game_views_count`, `game_shares_count`
- Generates secure token via `SecureRandom.urlsafe_base64(16)`

**Not used by HPG.** HPG's `RealtyGame` is a standalone entity, not a concern on listings.

---

## 10. Website Model

**File:** `app/models/pwb/website.rb`

### Key Facts

- Primary key is `integer` (NOT uuid) — `id :integer`
- `slug` column exists but is overridden by method to always return `"website"`
- `subdomain` is unique and the primary tenant identifier
- `default_currency` defaults to `"EUR"`
- Has `has_many :integrations`

### Associations to Add

```ruby
has_many :realty_games, class_name: 'Pwb::RealtyGame', dependent: :destroy
has_many :game_sessions, class_name: 'Pwb::GameSession', dependent: :destroy
has_many :access_codes, class_name: 'Pwb::AccessCode', dependent: :destroy
```

---

## 11. SPP Rake Task (Provisioning Pattern)

**File:** `lib/tasks/spp.rake`

Simple pattern:
1. Find website by subdomain
2. Check if integration exists
3. If not, create with `SecureRandom.hex(32)` API key
4. Print configuration for external service

HPG's rake task will be similar but provision multiple websites (19 HPG sites).

---

## 12. Migration Conventions

**File:** `db/migrate/20260212153030_create_pwb_spp_listings.rb`

Patterns to follow:
- UUID PKs: `id: :uuid, default: -> { "gen_random_uuid()" }`
- Foreign keys as UUID: `t.uuid :realty_asset_id, null: false`
- JSONB with defaults: `t.jsonb :extra_data, default: {}`
- Boolean with null: `t.boolean :active, default: false, null: false`
- Named indexes: `name: "index_pwb_spp_listings_unique_active"`
- Conditional unique indexes: `unique: true, where: "(active = true)"`
- Foreign key constraints: `add_foreign_key :table, :ref_table, column: :col, type: :uuid`

**Note on foreign keys:** `website_id` is `bigint` (Website PK is integer). UUID FKs reference UUID PKs (like `realty_asset_id`).

---

## 13. Factory Conventions

From `spec/factories/`:

- Class name: `class: 'Pwb::ModelName'`
- Use `sequence` for unique fields: `sequence(:subdomain) { |n| "tenant#{n}" }`
- Use traits for states: `trait :published { ... }`
- Use `association` for belongs_to
- `after(:create)` for setup that needs persisted records

---

## 14. Request Spec Conventions

From `spec/requests/api_public/v1/cross_tenant_isolation_spec.rb`:

- `type: :request`
- `host!` for subdomain routing: `host! 'tenant.example.com'`
- `response.parsed_body` for JSON parsing
- Standard assertions: `expect(response).to have_http_status(:ok)`
- Cross-tenant tests: Create two websites, verify isolation

---

## 15. Response Envelope Concern

**File:** `app/controllers/concerns/api_public/response_envelope.rb`

Available helpers:
- `render_envelope(data:, meta:, links:, errors:, status:)` — Standard envelope
- `render_success(message:, data:, status:)` — Simple success
- `render_created(data:, location:)` — 201 response
- `build_pagination_meta(total:, page:, per_page:)` — Pagination metadata

**HPG endpoints should use:**
- `render_envelope` for list endpoints (games index, leaderboards)
- `render json:` directly for game detail and estimate responses (matching HPG frontend expectations)

---

## 16. Error Handler Concern

**File:** `app/controllers/concerns/api_public/error_handler.rb`

Auto-rescued exceptions:
- `ActiveRecord::RecordNotFound` → 404 with `{ error: { code: "NOT_FOUND", ... } }`
- `ActiveRecord::RecordInvalid` → 422 with validation details
- `ActionController::ParameterMissing` → 400

Available helpers:
- `render_not_found_error(message)` — Manual 404
- `render_bad_request(message, code:, details:)` — Manual 400

All error responses include `request_id: request.uuid` for debugging.

---

## 17. Realty Asset Model

**File:** `app/models/pwb/realty_asset.rb`

The core property entity:
- UUID primary key
- `website_id` (bigint) — tenant scoping
- Location fields: `street_address`, `city`, `country`, `latitude`, `longitude`
- Property details: `count_bedrooms`, `count_bathrooms`, `constructed_area`
- `has_many :sale_listings`, `:rental_listings`, `:spp_listings`, `:prop_photos`
- `slug` for URL-friendly identification

**HPG's `GameListing` will reference `RealtyAsset` via `realty_asset_id` (UUID FK).** This allows HPG games to include any property from the tenant's asset inventory.
