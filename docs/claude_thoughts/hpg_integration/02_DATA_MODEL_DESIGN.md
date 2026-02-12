# HPG Integration: Data Model Design

## Entity Relationship Diagram (Text)

```
Pwb::Website (existing, integer PK)
  │
  ├── has_many :realty_games (NEW)
  │     │
  │     ├── has_many :game_listings (NEW)
  │     │     └── belongs_to :realty_asset (existing, UUID PK)
  │     │
  │     └── has_many :game_sessions (NEW)
  │           └── has_many :game_estimates (NEW)
  │                 └── belongs_to :game_listing (NEW)
  │
  └── has_many :access_codes (NEW)
```

---

## Table 1: `pwb_realty_games`

The core game entity. Represents a "round" or "challenge" like "Guess London Properties" or "Barcelona Beach Villas".

### Schema

| Column | Type | Default | Null | Notes |
|--------|------|---------|------|-------|
| `id` | uuid | `gen_random_uuid()` | false | PK |
| `website_id` | bigint | — | false | FK to pwb_websites |
| `slug` | string | — | false | URL-friendly identifier, unique per website |
| `title` | string | — | false | Display name |
| `description` | text | — | true | Optional description |
| `bg_image_url` | string | — | true | Background/hero image URL |
| `default_currency` | string | `'EUR'` | false | Currency for game listings |
| `default_country` | string | — | true | Default country code |
| `active` | boolean | `true` | false | Whether game is playable |
| `hidden_from_landing_page` | boolean | `false` | false | Hides from game list but still playable via direct URL |
| `start_at` | datetime | — | true | Optional scheduled start |
| `end_at` | datetime | — | true | Optional scheduled end |
| `validation_rules` | jsonb | `{}` | false | Frontend validation config (e.g., min/max estimate) |
| `sessions_count` | integer | `0` | false | Counter cache |
| `estimates_count` | integer | `0` | false | Counter cache |
| `created_at` | datetime | — | false | |
| `updated_at` | datetime | — | false | |

### Indexes

| Columns | Unique | Notes |
|---------|--------|-------|
| `[website_id, slug]` | YES | Each game slug unique per tenant |
| `[website_id, active]` | no | Fast lookup of active games |
| `website_id` | no | FK index |

### Foreign Keys

- `website_id` → `pwb_websites(id)`

---

## Table 2: `pwb_game_listings`

Join table between game and realty_asset. Each entry represents a property included in a game.

### Schema

| Column | Type | Default | Null | Notes |
|--------|------|---------|------|-------|
| `id` | uuid | `gen_random_uuid()` | false | PK |
| `realty_game_id` | uuid | — | false | FK to pwb_realty_games |
| `realty_asset_id` | uuid | — | false | FK to pwb_realty_assets |
| `visible` | boolean | `true` | false | Can be hidden without removal |
| `sort_order` | integer | `0` | false | Display ordering |
| `display_title` | string | — | true | Override title for this game context |
| `extra_data` | jsonb | `{}` | false | Flexible additional data |
| `created_at` | datetime | — | false | |
| `updated_at` | datetime | — | false | |

### Indexes

| Columns | Unique | Notes |
|---------|--------|-------|
| `[realty_game_id, realty_asset_id]` | YES | No duplicate property per game |
| `realty_game_id` | no | FK index |
| `realty_asset_id` | no | FK index |

### Foreign Keys

- `realty_game_id` → `pwb_realty_games(id)` (uuid)
- `realty_asset_id` → `pwb_realty_assets(id)` (uuid)

---

## Table 3: `pwb_game_sessions`

A player's session through a game. Created when first estimate is submitted.

### Schema

| Column | Type | Default | Null | Notes |
|--------|------|---------|------|-------|
| `id` | uuid | `gen_random_uuid()` | false | PK |
| `realty_game_id` | uuid | — | false | FK to pwb_realty_games |
| `website_id` | bigint | — | false | FK to pwb_websites (denormalized for fast leaderboard queries) |
| `guest_name` | string | — | true | Optional player display name |
| `visitor_token` | string | — | false | Anonymous session identifier |
| `user_uuid` | string | — | true | Optional authenticated user ID |
| `total_score` | integer | `0` | false | Sum of all estimate scores |
| `performance_rating` | string | — | true | Computed label (e.g., "expert", "novice") |
| `created_at` | datetime | — | false | |
| `updated_at` | datetime | — | false | |

### Indexes

| Columns | Unique | Notes |
|---------|--------|-------|
| `[realty_game_id, visitor_token]` | no | Find session by player + game (not unique — player can replay) |
| `[website_id, total_score]` | no | Leaderboard query |
| `realty_game_id` | no | FK index |
| `website_id` | no | FK index |

### Foreign Keys

- `realty_game_id` → `pwb_realty_games(id)` (uuid)
- `website_id` → `pwb_websites(id)`

### Design Notes

- `website_id` is denormalized (could be derived via `realty_game.website_id`) for leaderboard query performance
- `visitor_token` is NOT unique-scoped per game — players can create multiple sessions (replays)
- `total_score` is updated after each estimate is recorded

---

## Table 4: `pwb_game_estimates`

Individual price guess within a session.

### Schema

| Column | Type | Default | Null | Notes |
|--------|------|---------|------|-------|
| `id` | uuid | `gen_random_uuid()` | false | PK |
| `game_session_id` | uuid | — | false | FK to pwb_game_sessions |
| `game_listing_id` | uuid | — | false | FK to pwb_game_listings |
| `website_id` | bigint | — | false | FK (denormalized) |
| `estimated_price_cents` | bigint | — | false | Player's guess |
| `actual_price_cents` | bigint | — | false | Snapshot of actual price at time of guess |
| `currency` | string | `'EUR'` | false | |
| `percentage_diff` | decimal(8,2) | — | true | Signed: positive = above, negative = below |
| `score` | integer | `0` | false | 0-100 from ScoreCalculator |
| `property_index` | integer | — | true | Which property in the game sequence (0-based) |
| `estimate_details` | jsonb | `{}` | false | Extra data (feedback, emoji, etc.) |
| `created_at` | datetime | — | false | |
| `updated_at` | datetime | — | false | |

### Indexes

| Columns | Unique | Notes |
|---------|--------|-------|
| `[game_session_id, game_listing_id]` | YES | One estimate per listing per session |
| `game_session_id` | no | FK index |
| `game_listing_id` | no | FK index |
| `website_id` | no | FK index |

### Foreign Keys

- `game_session_id` → `pwb_game_sessions(id)` (uuid)
- `game_listing_id` → `pwb_game_listings(id)` (uuid)
- `website_id` → `pwb_websites(id)`

### Design Notes

- Score calculation reuses `Pwb::PriceGame::ScoreCalculator`
- `actual_price_cents` is snapshotted at estimate time (not looked up later)
- `estimate_details` stores the full ScoreCalculator result (feedback message, emoji) for historical accuracy

---

## Table 5: `pwb_access_codes`

Per-website access codes for gated games.

### Schema

| Column | Type | Default | Null | Notes |
|--------|------|---------|------|-------|
| `id` | uuid | `gen_random_uuid()` | false | PK |
| `website_id` | bigint | — | false | FK to pwb_websites |
| `code` | string | — | false | The access code (e.g., "LONDON2026") |
| `active` | boolean | `true` | false | |
| `uses_count` | integer | `0` | false | How many times used |
| `max_uses` | integer | — | true | nil = unlimited |
| `expires_at` | datetime | — | true | nil = no expiry |
| `created_at` | datetime | — | false | |
| `updated_at` | datetime | — | false | |

### Indexes

| Columns | Unique | Notes |
|---------|--------|-------|
| `[website_id, code]` | YES | Each code unique per tenant |
| `website_id` | no | FK index |

### Foreign Keys

- `website_id` → `pwb_websites(id)`

---

## Model Definitions

### `Pwb::RealtyGame`

```ruby
class RealtyGame < ApplicationRecord
  self.table_name = 'pwb_realty_games'

  belongs_to :website
  has_many :game_listings, dependent: :destroy
  has_many :realty_assets, through: :game_listings
  has_many :game_sessions, dependent: :destroy

  validates :slug, presence: true, uniqueness: { scope: :website_id }
  validates :title, presence: true
  validates :default_currency, presence: true

  scope :active, -> { where(active: true) }
  scope :visible_on_landing, -> { active.where(hidden_from_landing_page: false) }
  scope :currently_available, -> { active.where('start_at IS NULL OR start_at <= ?', Time.current)
                                        .where('end_at IS NULL OR end_at >= ?', Time.current) }
end
```

### `Pwb::GameListing`

```ruby
class GameListing < ApplicationRecord
  self.table_name = 'pwb_game_listings'

  belongs_to :realty_game
  belongs_to :realty_asset
  has_many :game_estimates, dependent: :destroy

  validates :realty_asset_id, uniqueness: { scope: :realty_game_id }

  scope :visible, -> { where(visible: true) }
  scope :ordered, -> { order(sort_order: :asc, created_at: :asc) }
end
```

### `Pwb::GameSession`

```ruby
class GameSession < ApplicationRecord
  self.table_name = 'pwb_game_sessions'

  belongs_to :realty_game
  belongs_to :website
  has_many :game_estimates, dependent: :destroy

  validates :visitor_token, presence: true

  scope :for_leaderboard, -> { order(total_score: :desc, created_at: :asc) }

  def recalculate_total_score!
    update!(total_score: game_estimates.sum(:score))
  end
end
```

### `Pwb::GameEstimate`

```ruby
class GameEstimate < ApplicationRecord
  self.table_name = 'pwb_game_estimates'

  belongs_to :game_session
  belongs_to :game_listing
  belongs_to :website

  validates :estimated_price_cents, presence: true, numericality: { greater_than: 0 }
  validates :actual_price_cents, presence: true, numericality: { greater_than: 0 }
  validates :game_listing_id, uniqueness: { scope: :game_session_id }

  before_validation :calculate_score, on: :create
  after_create :update_session_score!
  after_create :increment_game_counter

  private

  def calculate_score
    return unless estimated_price_cents.present? && actual_price_cents.present?

    calculator = Pwb::PriceGame::ScoreCalculator.new(
      guessed_cents: estimated_price_cents,
      actual_cents: actual_price_cents
    )
    self.score = calculator.score
    self.percentage_diff = calculator.percentage_diff
    self.estimate_details = calculator.result
  end

  def update_session_score!
    game_session.recalculate_total_score!
  end

  def increment_game_counter
    game_listing.realty_game.increment!(:estimates_count)
  end
end
```

### `Pwb::AccessCode`

```ruby
class AccessCode < ApplicationRecord
  self.table_name = 'pwb_access_codes'

  belongs_to :website

  validates :code, presence: true, uniqueness: { scope: :website_id }

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :not_exhausted, -> { where('max_uses IS NULL OR uses_count < max_uses') }
  scope :valid, -> { active.not_expired.not_exhausted }

  def valid_code?
    active? && !expired? && !exhausted?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def exhausted?
    max_uses.present? && uses_count >= max_uses
  end

  def redeem!
    increment!(:uses_count)
  end
end
```

---

## Associations to Add to Existing Models

### `Pwb::Website` (app/models/pwb/website.rb)

Add after the existing `has_many :integrations` line (~line 182):

```ruby
# HPG Game Engine
has_many :realty_games, class_name: 'Pwb::RealtyGame', dependent: :destroy
has_many :game_sessions, class_name: 'Pwb::GameSession', dependent: :destroy
has_many :access_codes, class_name: 'Pwb::AccessCode', dependent: :destroy
```
