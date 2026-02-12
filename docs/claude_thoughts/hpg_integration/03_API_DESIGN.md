# HPG Integration: API Design

## Route Structure

All HPG endpoints live under `api_public/v1/hpg/` — no locale prefix needed.

```ruby
# config/routes.rb — inside namespace :api_public / namespace :v1
scope :hpg do
  get  '/games',                           to: 'hpg/games#index'
  get  '/games/:slug',                     to: 'hpg/games#show'
  post '/games/:slug/estimates',           to: 'hpg/estimates#create'
  get  '/games/:slug/results/:session_id', to: 'hpg/results#show'
  get  '/leaderboards',                    to: 'hpg/leaderboards#index'
  post '/access_codes/check',              to: 'hpg/access_codes#check'
  get  '/listings/:uuid',                  to: 'hpg/listings#show'
end
```

**Full paths:**
- `GET  /api_public/v1/hpg/games`
- `GET  /api_public/v1/hpg/games/:slug`
- `POST /api_public/v1/hpg/games/:slug/estimates`
- `GET  /api_public/v1/hpg/games/:slug/results/:session_id`
- `GET  /api_public/v1/hpg/leaderboards`
- `POST /api_public/v1/hpg/access_codes/check`
- `GET  /api_public/v1/hpg/listings/:uuid`

---

## Controller Hierarchy

```
ApiPublic::V1::BaseController (existing)
  └── ApiPublic::V1::Hpg::BaseController (NEW — overrides caching)
        ├── ApiPublic::V1::Hpg::GamesController
        ├── ApiPublic::V1::Hpg::EstimatesController
        ├── ApiPublic::V1::Hpg::ResultsController
        ├── ApiPublic::V1::Hpg::LeaderboardsController
        ├── ApiPublic::V1::Hpg::AccessCodesController
        └── ApiPublic::V1::Hpg::ListingsController
```

---

## Endpoint 1: GET /api_public/v1/hpg/games

List all available games for the current website.

### Caching

1 hour, public. CDN-friendly.

### Response (200 OK)

```json
{
  "data": [
    {
      "slug": "london-challenge",
      "title": "London Property Challenge",
      "description": "Can you guess London property prices?",
      "bg_image_url": "https://images.example.com/london.jpg",
      "default_currency": "GBP",
      "default_country": "GB",
      "listings_count": 5,
      "sessions_count": 142,
      "estimates_count": 710,
      "active": true,
      "hidden_from_landing_page": false,
      "start_at": null,
      "end_at": null,
      "validation_rules": {}
    }
  ],
  "meta": {
    "total": 3
  }
}
```

### Implementation Notes

- Scoped to `current_website.realty_games.visible_on_landing`
- Include `game_listings.count` as `listings_count`
- Counter caches provide `sessions_count` and `estimates_count`
- Could also add `currently_available` scope to filter by date

---

## Endpoint 2: GET /api_public/v1/hpg/games/:slug

Game detail with all listing data needed for gameplay.

### Caching

5 minutes, public. Shorter TTL because game listings could change.

### Response (200 OK)

```json
{
  "slug": "london-challenge",
  "title": "London Property Challenge",
  "description": "Can you guess London property prices?",
  "bg_image_url": "https://images.example.com/london.jpg",
  "default_currency": "GBP",
  "default_country": "GB",
  "validation_rules": {
    "min_estimate": 10000,
    "max_estimate": 50000000
  },
  "listings": [
    {
      "id": "abc-123-uuid",
      "game_listing_id": "gl-uuid",
      "display_title": "Kensington 2BR Flat",
      "sort_order": 0,
      "property": {
        "uuid": "abc-123-uuid",
        "street_address": "123 High Street",
        "city": "London",
        "country": "GB",
        "bedrooms": 2,
        "bathrooms": 1,
        "area_sqm": 75.0,
        "latitude": 51.5074,
        "longitude": -0.1278,
        "photos": [
          {
            "id": 42,
            "url": "https://cdn.example.com/photo1.jpg",
            "thumbnail_url": "https://cdn.example.com/photo1_thumb.jpg"
          }
        ]
      }
    }
  ]
}
```

### Implementation Notes

- Finds game by `current_website.realty_games.find_by!(slug: params[:slug])`
- Eager loads: `game_listings.visible.ordered` with `.includes(realty_asset: :prop_photos)`
- Does NOT include actual prices (that would defeat the game!)
- Property photos limited to first 5 per listing for performance

---

## Endpoint 3: POST /api_public/v1/hpg/games/:slug/estimates

Submit a price estimate for a listing within a game.

### Caching

NO CACHE. Write endpoint.

### Request Body

```json
{
  "price_estimate": {
    "game_listing_id": "gl-uuid",
    "estimated_price": 450000,
    "currency": "GBP",
    "visitor_token": "abc123xyz",
    "guest_name": "Player One",
    "property_index": 0,
    "session_id": null
  }
}
```

**Notes:**
- `session_id` is null for the first estimate in a session (backend creates one and returns it)
- `session_id` is provided for subsequent estimates in the same session
- `visitor_token` identifies the anonymous player
- `property_index` tracks which property in the sequence

### Response (201 Created)

```json
{
  "estimate": {
    "id": "est-uuid",
    "estimated_price_cents": 45000000,
    "actual_price_cents": 42000000,
    "currency": "GBP",
    "percentage_diff": 7.14,
    "score": 90,
    "feedback": "Amazing guess! 7.1% above.",
    "emoji": "👏",
    "property_index": 0
  },
  "session": {
    "id": "sess-uuid",
    "total_score": 90,
    "estimates_count": 1,
    "game_listings_count": 5
  }
}
```

### Error Responses

**Already estimated this listing (409 Conflict):**
```json
{
  "error": {
    "code": "DUPLICATE_ESTIMATE",
    "message": "Already submitted an estimate for this listing in this session"
  }
}
```

**Game not found (404):**
Standard `ErrorHandler` response.

### Implementation Notes

- Find game: `current_website.realty_games.active.find_by!(slug: params[:slug])`
- Find game_listing: `game.game_listings.find(params[:price_estimate][:game_listing_id])`
- Get actual price from `game_listing.realty_asset.active_sale_listing.price_sale_current_cents` (or rental equivalent)
- Create/find session, create estimate with ScoreCalculator
- Update session total_score
- Delegated to `Pwb::Hpg::EstimateProcessor` service object

---

## Endpoint 4: GET /api_public/v1/hpg/games/:slug/results/:session_id

Results board for a completed (or in-progress) session.

### Caching

1 minute, public. Short TTL for near-real-time feel.

### Response (200 OK)

```json
{
  "session": {
    "id": "sess-uuid",
    "guest_name": "Player One",
    "total_score": 420,
    "performance_rating": "expert",
    "estimates_count": 5,
    "created_at": "2026-02-12T10:30:00Z"
  },
  "estimates": [
    {
      "property_index": 0,
      "game_listing_id": "gl-uuid",
      "estimated_price_cents": 45000000,
      "actual_price_cents": 42000000,
      "currency": "GBP",
      "percentage_diff": 7.14,
      "score": 90,
      "feedback": "Amazing guess!",
      "emoji": "👏",
      "property": {
        "display_title": "Kensington 2BR Flat",
        "city": "London",
        "photo_url": "https://cdn.example.com/photo1.jpg"
      }
    }
  ],
  "ranking": {
    "position": 3,
    "total_players": 142,
    "percentile": 97.9
  },
  "game": {
    "slug": "london-challenge",
    "title": "London Property Challenge",
    "listings_count": 5
  }
}
```

### Implementation Notes

- Find game + session
- Include all estimates with associated property info
- Calculate ranking by querying sessions with higher total_score
- `performance_rating` computed from total_score/possible_score ratio

---

## Endpoint 5: GET /api_public/v1/hpg/leaderboards

Global or game-specific leaderboard.

### Caching

1 minute, public.

### Query Parameters

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `game_slug` | string | nil | Filter by specific game (nil = all games) |
| `period` | string | `'all_time'` | `'all_time'`, `'monthly'`, `'weekly'`, `'daily'` |
| `limit` | integer | 20 | Max 100 |

### Response (200 OK)

```json
{
  "data": [
    {
      "rank": 1,
      "guest_name": "PropertyPro",
      "total_score": 480,
      "estimates_count": 5,
      "game_slug": "london-challenge",
      "game_title": "London Property Challenge",
      "created_at": "2026-02-10T14:20:00Z"
    }
  ],
  "meta": {
    "total": 142,
    "period": "all_time",
    "game_slug": "london-challenge"
  }
}
```

### Implementation Notes

- Base query: `current_website.game_sessions.for_leaderboard`
- Period filtering: `where('created_at >= ?', period_start)`
- Game filtering: `joins(:realty_game).where(pwb_realty_games: { slug: params[:game_slug] })`
- Uses `render_envelope` for standard pagination

---

## Endpoint 6: POST /api_public/v1/hpg/access_codes/check

Validate an access code for the current website.

### Caching

NO CACHE. Validation endpoint.

### Request Body

```json
{
  "code": "LONDON2026"
}
```

### Response (200 OK)

```json
{
  "valid": true,
  "code": "LONDON2026"
}
```

### Response (200 OK — invalid)

```json
{
  "valid": false,
  "code": "WRONGCODE"
}
```

**Note:** Always returns 200 — `valid: false` is not an error. This prevents timing attacks that could enumerate valid codes.

### Implementation Notes

- Look up: `current_website.access_codes.valid.find_by(code: params[:code])`
- Do NOT increment `uses_count` on check — only on actual game session creation
- Response deliberately minimal to avoid leaking information

---

## Endpoint 7: GET /api_public/v1/hpg/listings/:uuid

Individual listing details by UUID.

### Caching

1 hour, public.

### Response (200 OK)

```json
{
  "uuid": "abc-123-uuid",
  "reference": "PROP-42",
  "title": "2 Bedroom Flat, Kensington",
  "street_address": "123 High Street",
  "city": "London",
  "country": "GB",
  "postal_code": "W8 5SA",
  "bedrooms": 2,
  "bathrooms": 1,
  "area_sqm": 75.0,
  "latitude": 51.5074,
  "longitude": -0.1278,
  "prop_type": "apartment",
  "photos": [
    {
      "id": 42,
      "url": "https://cdn.example.com/photo1.jpg",
      "thumbnail_url": "https://cdn.example.com/photo1_thumb.jpg"
    }
  ]
}
```

### Implementation Notes

- Find by UUID: `current_website.realty_assets.find(params[:uuid])`
- Does NOT include price (game context)
- Include up to 10 photos

---

## Serializer Design

Service objects in `app/services/pwb/hpg/`:

### `GameSerializer`

Serializes `RealtyGame` → game list item (for index endpoint).

### `GameSummarySerializer`

Serializes `RealtyGame` with listings → full game detail (for show endpoint).

### `EstimateProcessor`

Orchestrates estimate creation:
1. Find/create GameSession
2. Resolve actual price from game_listing's realty_asset
3. Create GameEstimate (triggers ScoreCalculator via callback)
4. Return estimate + session data

### `ResultBoardSerializer`

Serializes session → result board (for results endpoint).
Includes ranking calculation.

---

## Caching Strategy

| Endpoint | Cache | TTL | Rationale |
|----------|-------|-----|-----------|
| `GET /games` | public | 1 hour | Game list rarely changes |
| `GET /games/:slug` | public | 5 min | Listings could be updated |
| `POST /games/:slug/estimates` | no-store | — | Write operation |
| `GET /games/:slug/results/:id` | public | 1 min | Near-real-time ranking |
| `GET /leaderboards` | public | 1 min | Frequently updating |
| `POST /access_codes/check` | no-store | — | Must be real-time |
| `GET /listings/:uuid` | public | 1 hour | Property data rarely changes |

### Implementation

HPG's `BaseController` will override the parent's cache headers:

```ruby
module ApiPublic
  module V1
    module Hpg
      class BaseController < ApiPublic::V1::BaseController
        private

        # Override: 5-minute default instead of 1 hour
        def set_api_public_cache_headers
          expires_in 5.minutes, public: true
          response.headers["Vary"] = "X-Website-Slug"
        end

        # Helper for write endpoints
        def disable_cache!
          response.headers["Cache-Control"] = "no-store"
        end
      end
    end
  end
end
```

Individual controllers then call `disable_cache!` in write actions or override `set_api_public_cache_headers` for custom TTLs.

---

## Error Response Format

All HPG endpoints use the existing `ApiPublic::ErrorHandler` responses:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "RealtyGame not found",
    "status": 404,
    "request_id": "req-uuid"
  }
}
```

Custom error codes for HPG:
- `DUPLICATE_ESTIMATE` (409) — Already estimated this listing in this session
- `GAME_INACTIVE` (422) — Game is not currently active
- `GAME_NOT_STARTED` (422) — Game hasn't started yet
- `GAME_ENDED` (422) — Game has ended
