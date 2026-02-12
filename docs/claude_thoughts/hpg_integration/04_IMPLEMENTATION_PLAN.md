# HPG Integration: Implementation Plan

## Phase Overview

| Phase | Description | Files | Tests |
|-------|-------------|-------|-------|
| 0 | CORS + Integration Category | 2 modified | 2 spec files |
| 1 | Data Models + Migrations | 5 migrations, 5 models, 1 modified | 5 model specs, 5 factories |
| 2 | Core Game-Play API (7 endpoints) | 1 route file, 7 controllers, 4 serializers | 7 request specs |
| 3 | Website Provisioning | 1 rake task | — |

---

## Phase 0: CORS + Integration Category

### Step 0.1: Add HPG CORS Origins

**File:** `config/initializers/cors.rb`
**Action:** Add new `allow` block after line 21

```ruby
# HPG (HousePriceGuess) frontend
allow do
  origins 'https://housepriceguess.com',
          /.*\.housepriceguess\.com/
  resource '*',
    headers: :any,
    methods: [:get, :post, :put, :patch, :delete, :options, :head],
    max_age: 3600
end
```

Also add `http://localhost:4321` to the development block if not already there (it IS already there at line 4).

### Step 0.2: Add HPG Integration Category

**File:** `app/models/pwb/website_integration.rb`
**Action:** Add `hpg` entry to CATEGORIES hash after `spp` (line 118)

```ruby
hpg: {
  name: 'House Price Guess',
  description: 'Price guessing game integration via HPG',
  icon: 'game-controller'
}
```

### Step 0.3: Tests

**New file:** `spec/models/pwb/website_integration_hpg_spec.rb`
- Validates `hpg` is an accepted category
- Can create integration with category `hpg`

**New file:** `spec/requests/api_public/v1/hpg/cors_spec.rb`
- OPTIONS request from `housepriceguess.com` gets correct CORS headers
- OPTIONS request from random origin does NOT get HPG CORS headers

### Verification

```bash
bundle exec rspec spec/models/pwb/website_integration_hpg_spec.rb
bundle exec rspec spec/requests/api_public/v1/hpg/cors_spec.rb
```

---

## Phase 1: Data Models + Migrations

### Step 1.1: Create Migrations (5 files)

Order matters due to foreign key dependencies:

1. `create_pwb_realty_games` — depends on `pwb_websites`
2. `create_pwb_game_listings` — depends on `pwb_realty_games` + `pwb_realty_assets`
3. `create_pwb_game_sessions` — depends on `pwb_realty_games` + `pwb_websites`
4. `create_pwb_game_estimates` — depends on `pwb_game_sessions` + `pwb_game_listings`
5. `create_pwb_access_codes` — depends on `pwb_websites`

Timestamps generated with 10-second gaps: e.g., `20260212200000`, `20260212200010`, etc.

See [02_DATA_MODEL_DESIGN.md](02_DATA_MODEL_DESIGN.md) for full schema definitions.

### Step 1.2: Create Models (5 files)

All in `app/models/pwb/`:
- `realty_game.rb`
- `game_listing.rb`
- `game_session.rb`
- `game_estimate.rb`
- `access_code.rb`

See [02_DATA_MODEL_DESIGN.md](02_DATA_MODEL_DESIGN.md) for model code.

### Step 1.3: Update Website Model

**File:** `app/models/pwb/website.rb`
**Action:** Add `has_many` associations (after line 182)

### Step 1.4: Create Factories (5 files)

All in `spec/factories/`:
- `pwb_realty_games.rb`
- `pwb_game_listings.rb`
- `pwb_game_sessions.rb`
- `pwb_game_estimates.rb`
- `pwb_access_codes.rb`

### Step 1.5: Create Model Specs (5 files)

All in `spec/models/pwb/`:
- `realty_game_spec.rb` — validations, scopes, associations
- `game_listing_spec.rb` — uniqueness constraint, ordering
- `game_session_spec.rb` — score recalculation, leaderboard scope
- `game_estimate_spec.rb` — ScoreCalculator integration, callbacks
- `access_code_spec.rb` — validity checks, expiry, exhaustion

### Verification

```bash
bundle exec rails db:migrate
bundle exec rspec spec/models/pwb/realty_game_spec.rb
bundle exec rspec spec/models/pwb/game_listing_spec.rb
bundle exec rspec spec/models/pwb/game_session_spec.rb
bundle exec rspec spec/models/pwb/game_estimate_spec.rb
bundle exec rspec spec/models/pwb/access_code_spec.rb
```

---

## Phase 2: Core Game-Play API

### Step 2.1: Add Routes

**File:** `config/routes.rb`
**Action:** Add HPG scope inside `namespace :api_public` / `namespace :v1` block, before the closing `end` of `v1` (around line 992).

### Step 2.2: Create Base Controller

**New file:** `app/controllers/api_public/v1/hpg/base_controller.rb`

```ruby
module ApiPublic
  module V1
    module Hpg
      class BaseController < ApiPublic::V1::BaseController
        private

        def set_api_public_cache_headers
          expires_in 5.minutes, public: true
          response.headers["Vary"] = "X-Website-Slug"
        end

        def disable_cache!
          response.headers["Cache-Control"] = "no-store"
        end

        def find_game!
          @game = current_website.realty_games.find_by!(slug: params[:slug])
        end
      end
    end
  end
end
```

### Step 2.3: Create Controllers (6 files)

All in `app/controllers/api_public/v1/hpg/`:

1. **`games_controller.rb`** — `index`, `show`
2. **`estimates_controller.rb`** — `create`
3. **`results_controller.rb`** — `show`
4. **`leaderboards_controller.rb`** — `index`
5. **`access_codes_controller.rb`** — `check`
6. **`listings_controller.rb`** — `show`

See [03_API_DESIGN.md](03_API_DESIGN.md) for endpoint specifications.

### Step 2.4: Create Serializers (4 files)

All in `app/services/pwb/hpg/`:

1. **`game_serializer.rb`** — RealtyGame → game list item JSON
2. **`game_summary_serializer.rb`** — RealtyGame + listings → game detail JSON
3. **`estimate_processor.rb`** — Orchestrates estimate creation flow
4. **`result_board_serializer.rb`** — Session → result board JSON

### Step 2.5: Create Request Specs (7 files)

All in `spec/requests/api_public/v1/hpg/`:

1. **`games_spec.rb`** — GET /games (index, show, caching, 404)
2. **`estimates_spec.rb`** — POST /games/:slug/estimates (create, duplicate, invalid)
3. **`results_spec.rb`** — GET /games/:slug/results/:id (show, ranking)
4. **`leaderboards_spec.rb`** — GET /leaderboards (period filtering, game filtering)
5. **`access_codes_spec.rb`** — POST /access_codes/check (valid, invalid, expired)
6. **`listings_spec.rb`** — GET /listings/:uuid (show, not found)
7. **`cross_tenant_isolation_spec.rb`** — Games from website A not visible via website B

### Verification

```bash
bundle exec rspec spec/requests/api_public/v1/hpg/
```

Manual curl test:
```bash
curl -H "X-Website-Slug: hpg-london" http://localhost:3000/api_public/v1/hpg/games
```

---

## Phase 3: Website Provisioning

### Step 3.1: Create Rake Task

**New file:** `lib/tasks/hpg.rake`

```ruby
namespace :hpg do
  desc 'Provision HPG integration for a website. Usage: rails hpg:provision[subdomain]'
  task :provision, [:subdomain] => :environment do |_t, args|
    # Similar to spp:provision but for hpg category
  end

  desc 'Provision all 19 HPG websites'
  task :provision_all => :environment do
    # Create websites and integrations for all HPG cities
  end
end
```

### Verification

```bash
bundle exec rails hpg:provision[hpg-london]
```

---

## Complete New File Inventory

### Controllers (7 files)
```
app/controllers/api_public/v1/hpg/base_controller.rb
app/controllers/api_public/v1/hpg/games_controller.rb
app/controllers/api_public/v1/hpg/estimates_controller.rb
app/controllers/api_public/v1/hpg/results_controller.rb
app/controllers/api_public/v1/hpg/leaderboards_controller.rb
app/controllers/api_public/v1/hpg/access_codes_controller.rb
app/controllers/api_public/v1/hpg/listings_controller.rb
```

### Models (5 files)
```
app/models/pwb/realty_game.rb
app/models/pwb/game_listing.rb
app/models/pwb/game_session.rb
app/models/pwb/game_estimate.rb
app/models/pwb/access_code.rb
```

### Services (4 files)
```
app/services/pwb/hpg/game_serializer.rb
app/services/pwb/hpg/game_summary_serializer.rb
app/services/pwb/hpg/estimate_processor.rb
app/services/pwb/hpg/result_board_serializer.rb
```

### Migrations (5 files)
```
db/migrate/YYYYMMDD_create_pwb_realty_games.rb
db/migrate/YYYYMMDD_create_pwb_game_listings.rb
db/migrate/YYYYMMDD_create_pwb_game_sessions.rb
db/migrate/YYYYMMDD_create_pwb_game_estimates.rb
db/migrate/YYYYMMDD_create_pwb_access_codes.rb
```

### Rake Tasks (1 file)
```
lib/tasks/hpg.rake
```

### Specs (17+ files)
```
spec/models/pwb/realty_game_spec.rb
spec/models/pwb/game_listing_spec.rb
spec/models/pwb/game_session_spec.rb
spec/models/pwb/game_estimate_spec.rb
spec/models/pwb/access_code_spec.rb
spec/models/pwb/website_integration_hpg_spec.rb
spec/requests/api_public/v1/hpg/cors_spec.rb
spec/requests/api_public/v1/hpg/games_spec.rb
spec/requests/api_public/v1/hpg/estimates_spec.rb
spec/requests/api_public/v1/hpg/results_spec.rb
spec/requests/api_public/v1/hpg/leaderboards_spec.rb
spec/requests/api_public/v1/hpg/access_codes_spec.rb
spec/requests/api_public/v1/hpg/listings_spec.rb
spec/requests/api_public/v1/hpg/cross_tenant_isolation_spec.rb
spec/factories/pwb_realty_games.rb
spec/factories/pwb_game_listings.rb
spec/factories/pwb_game_sessions.rb
spec/factories/pwb_game_estimates.rb
spec/factories/pwb_access_codes.rb
```

### Modified Files
```
config/initializers/cors.rb              (add HPG origins)
app/models/pwb/website_integration.rb    (add hpg category)
app/models/pwb/website.rb                (add has_many associations)
config/routes.rb                         (add HPG routes)
```

---

## Build Order Summary

```
Phase 0 → Phase 1 → Phase 2 → Phase 3

Within Phase 2, build in this order:
  routes → base_controller → serializers → controllers → specs
```

Each phase is independently testable and deployable.
