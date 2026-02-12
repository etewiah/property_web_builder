# HPG Integration: Design Decisions

## Decision 1: New Models vs. Extending PriceGuess

**Decision:** Create new models (`RealtyGame`, `GameListing`, `GameSession`, `GameEstimate`) rather than extending the existing `PriceGuess` model.

**Rationale:**
- `PriceGuess` is tightly coupled to SaleListing/RentalListing via polymorphic association
- HPG needs multi-property sessions with aggregate scoring — fundamentally different from one-off guesses
- HPG needs a `GameListing` join table to curate which properties appear in a game
- Shared behavior (ScoreCalculator) is already extracted as a service object that both systems can use
- Keeping them separate avoids breaking the existing simple game feature

**Trade-off:** More tables/models, but cleaner separation of concerns.

---

## Decision 2: Denormalized `website_id` on GameSession and GameEstimate

**Decision:** Store `website_id` directly on `game_sessions` and `game_estimates` even though it could be derived via `realty_game.website_id`.

**Rationale:**
- Leaderboard queries need to filter by website: `WHERE website_id = ?`
- Without denormalization, every leaderboard query requires a JOIN to `realty_games`
- Counter: adds data redundancy, but website_id never changes after creation
- This follows the same pattern as `PriceGuess` which denormalizes `website_id`

---

## Decision 3: `api_public/v1/hpg/` Scope (Not a Full Namespace)

**Decision:** Use `scope :hpg` in routes rather than `namespace :hpg`.

**Rationale:**
- `scope :hpg` adds `/hpg/` to the URL path but controllers are at `api_public/v1/hpg/` (module nesting)
- With `scope ... to: 'hpg/games#index'`, we get the URL prefix AND the controller module
- A full `namespace :hpg` would also work, but `scope` gives us the same result with explicit routing
- Using explicit `to:` declarations makes the route file self-documenting

**Note:** The controllers still live in `ApiPublic::V1::Hpg` module for clean organization.

---

## Decision 4: Visitor Token (Frontend-Generated) vs. Server Cookie

**Decision:** Accept `visitor_token` from the frontend request body rather than setting a server-side cookie.

**Rationale:**
- HPG is a separate Astro.js frontend on a different domain — cookies won't work cross-domain
- The frontend already generates and persists a visitor token in localStorage
- Server cookies only work for same-origin (the existing PriceGame uses cookies because it's server-rendered)
- UUID/random token from frontend is sufficient for anonymous game sessions

**Security note:** Visitor tokens are not secrets — they only prevent accidental duplicate submissions. A determined user could submit multiple sessions with different tokens. This is acceptable for a casual game.

---

## Decision 5: GameSession Allows Replays

**Decision:** No unique constraint on `[realty_game_id, visitor_token]` for game sessions. Players can create multiple sessions for the same game.

**Rationale:**
- HPG is a casual game — replaying should be allowed
- The unique constraint IS on `[game_session_id, game_listing_id]` for estimates — one guess per property per session
- Leaderboard shows best session score, not latest

---

## Decision 6: Actual Price Snapshotted at Estimate Time

**Decision:** Copy `actual_price_cents` into the `game_estimates` table at creation time rather than looking it up from the listing.

**Rationale:**
- Property prices can change (market updates, corrections)
- A player's score should be based on the price at the time they guessed
- Historical accuracy is important for leaderboard integrity
- Follows the same pattern as `PriceGuess#set_actual_price`

---

## Decision 7: No Authentication for Public Endpoints

**Decision:** All 7 HPG endpoints are public (no API key required).

**Rationale:**
- These are game endpoints — anyone should be able to play
- Multi-tenancy is handled by `SubdomainTenant` (X-Website-Slug header)
- Rate limiting can be added later at the infrastructure level (CloudFlare, etc.)
- Admin endpoints (future Phase 4) WILL require authentication

---

## Decision 8: HPG Base Controller Overrides Cache Headers

**Decision:** HPG's `BaseController` overrides the parent's 1-hour cache to 5 minutes default, with explicit `disable_cache!` for write endpoints.

**Rationale:**
- Parent `ApiPublic::V1::BaseController` sets 1-hour public cache on ALL actions
- This is too aggressive for game data (estimates change frequently)
- 5 minutes is a reasonable default for read endpoints
- Write endpoints (estimates, access_code check) must not be cached at all
- Individual controllers can further override (e.g., games index → 1 hour)

---

## Decision 9: Serializers as Plain Service Objects (Not ActiveModelSerializer)

**Decision:** Use plain Ruby service objects in `app/services/pwb/hpg/` rather than a serializer gem.

**Rationale:**
- PWB doesn't use ActiveModelSerializer or jsonapi-serializer
- Existing patterns (SppListingsController) use inline hash construction or method-based serialization
- Service objects give full control over response shape
- `EstimateProcessor` needs to orchestrate creation logic, not just serialization
- Keeps dependencies minimal

---

## Decision 10: Price in Cents (Integer)

**Decision:** Store and transmit all prices as integer cents (e.g., 45000000 = $450,000.00).

**Rationale:**
- Follows PWB convention (`price_sale_current_cents`, `price_rental_monthly_current_cents`)
- Avoids floating-point precision issues
- The HPG frontend handles formatting/display
- `ScoreCalculator` already works with cents

---

## Decision 11: Where to Get Actual Price

**Decision:** Get actual price from the realty_asset's active sale listing (or rental listing based on game context).

**Rationale:**
- `RealtyAsset` doesn't have a price — prices live on `SaleListing` and `RentalListing`
- `GameListing` references `RealtyAsset`, not a specific listing type
- The `EstimateProcessor` will check `realty_asset.active_sale_listing.price_sale_current_cents`
- If no active sale listing exists, falls back to rental, then raises an error
- This could be enhanced later with an explicit `listing_type` on `GameListing` if needed

**Alternative considered:** Store price directly on `GameListing`. Rejected because it would go stale and create a maintenance burden.

---

## Decision 12: Tenant Resolution for HPG

**Decision:** HPG frontend uses the `X-Website-Slug` header with the website's subdomain value for tenant resolution.

**Rationale:**
- The `SubdomainTenant` concern first checks `X-Website-Slug` header via `Pwb::Website.find_by(slug:)`
- BUT `Website#slug` method always returns `"website"` (overrides the column accessor)
- `find_by(slug:)` queries the database column directly, bypassing the Ruby method
- If HPG websites have their `slug` DB column set properly, this works
- Alternative: HPG uses Host header with subdomain — also works but is less explicit

**Action needed:** The provisioning rake task must set the `slug` column on HPG website records to a unique value (e.g., the subdomain name). Currently the slug column may be nil or "website" for all records.

**Safer alternative:** Have HPG send the subdomain as a custom header and add resolution logic. But the existing `X-Website-Slug` mechanism should work if we set the DB column.

---

## Open Questions

1. **How should HPG handle properties without an active sale listing?** Currently the plan assumes all game properties have active sale listings. If a property only has rentals, the estimate processor needs to know which price to use.

2. **Should leaderboards be cross-game or per-game?** Current design supports both via query param. The frontend will likely default to per-game.

3. **Max listings per game?** No hard limit in the schema. The frontend typically shows 5-10 properties per game round.

4. **Rate limiting?** Not implemented in Phase 2. Could be added via Rack::Attack or CloudFlare rules.
