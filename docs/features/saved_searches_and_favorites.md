# Saved Searches and Favorites

This document describes the saved searches and favorites functionality for external property listings.

## Overview

Users can save property searches and favorite individual properties without needing to create an account. All features use email-based identification with token-based authentication for managing saved items.

## Features

### Saved Searches
- Save search criteria (location, price range, bedrooms, etc.)
- Receive daily or weekly email alerts for new properties matching criteria
- Manage multiple saved searches per email address
- Unsubscribe from alerts via one-click link

### Favorites (Saved Properties)
- Save individual properties to a favorites list
- View all favorites via a unique link sent to email
- Track price changes on saved properties
- Add personal notes to saved properties

## Architecture

### Models

| Model | Purpose |
|-------|---------|
| `Pwb::SavedSearch` | Stores search criteria and alert preferences |
| `Pwb::SearchAlert` | Tracks individual alert executions and delivery status |
| `Pwb::SavedProperty` | Stores favorited properties with cached data |
| `PwbTenant::*` | Tenant-scoped proxies for multi-tenancy |

### Controllers

All controllers are in the `Pwb::Site::My` namespace:

- `SavedSearchesController` - CRUD for saved searches
- `SavedPropertiesController` - CRUD for favorites

### Routes

```ruby
# Under scope module: :pwb, locale scope
namespace :my do
  resources :saved_searches, only: [:index, :show, :create, :update, :destroy] do
    collection do
      get :unsubscribe
      get :verify
    end
  end

  resources :saved_properties, path: "favorites", as: "favorites",
            only: [:index, :show, :create, :update, :destroy] do
    collection do
      post :check
    end
  end
end
```

## Token-Based Authentication

Users don't need to log in. Instead, each saved search/property has:

| Token | Purpose |
|-------|---------|
| `manage_token` | Access and modify saved items |
| `unsubscribe_token` | One-click unsubscribe from alerts |
| `verification_token` | Email verification (optional) |

URLs include the token as a query parameter:
- `/my/saved_searches?token=abc123`
- `/my/favorites?token=xyz789`

## Email Alerts

### Alert Frequencies
- **None** - No alerts (saves search for later reference)
- **Daily** - Check once per day
- **Weekly** - Check once per week

### Background Job

`Pwb::SearchAlertJob` processes alerts:

1. Executes the saved search against the external feed
2. Compares results with previously seen properties
3. If new properties found, creates a `SearchAlert` record
4. Sends email via `SearchAlertMailer`
5. Updates `seen_property_refs` to avoid duplicate alerts

### Scheduled Execution

Use rake tasks to run alerts:

```bash
# Run daily alerts
bundle exec rake saved_searches:run_daily

# Run weekly alerts (run on specific day, e.g., Monday)
bundle exec rake saved_searches:run_weekly

# View statistics
bundle exec rake saved_searches:stats

# Cleanup old data
bundle exec rake saved_searches:cleanup
```

### Cron/Scheduler Setup

Example crontab entries:

```cron
# Daily alerts at 8am
0 8 * * * cd /path/to/app && bundle exec rake saved_searches:run_daily

# Weekly alerts on Monday at 9am
0 9 * * 1 cd /path/to/app && bundle exec rake saved_searches:run_weekly
```

For Solid Queue or other job schedulers, enqueue jobs directly:

```ruby
# In an initializer or scheduler config
Pwb::SavedSearch.daily_alerts.needs_run(:daily).find_each do |search|
  Pwb::SearchAlertJob.perform_later(search.id)
end
```

## Price Tracking (Favorites)

When a property is saved, the current price is recorded. When property data is refreshed:

- `original_price_cents` - Price when first saved
- `current_price_cents` - Most recent price
- `price_changed_at` - When price change was detected

Helper methods:
- `price_changed?` - Returns true if price differs from original
- `price_decreased?` / `price_increased?` - Direction of change
- `price_change_percentage` - Percentage change (e.g., -10.0 for 10% decrease)

## Database Schema

### pwb_saved_searches

| Column | Type | Description |
|--------|------|-------------|
| email | string | User's email address |
| name | string | Display name for the search |
| search_criteria | jsonb | Search parameters |
| alert_frequency | integer | Enum: none(0), daily(1), weekly(2) |
| enabled | boolean | Whether alerts are active |
| manage_token | string | Token for accessing/modifying |
| unsubscribe_token | string | Token for one-click unsubscribe |
| seen_property_refs | jsonb | Array of already-seen property references |
| last_run_at | datetime | When alerts last ran |
| email_verified | boolean | Whether email is verified |

### pwb_search_alerts

| Column | Type | Description |
|--------|------|-------------|
| saved_search_id | integer | FK to saved_search |
| new_properties | jsonb | Array of new property data |
| properties_count | integer | Number of new properties |
| sent_at | datetime | When email was sent |
| delivered_at | datetime | When delivery confirmed |
| email_status | string | Status: pending, sent, delivered, failed |

### pwb_saved_properties

| Column | Type | Description |
|--------|------|-------------|
| email | string | User's email address |
| provider | string | External feed provider name |
| external_reference | string | Property reference in external system |
| property_data | jsonb | Cached property details |
| notes | text | User's personal notes |
| manage_token | string | Token for access |
| original_price_cents | integer | Price when saved |
| current_price_cents | integer | Current price |
| price_changed_at | datetime | When price change detected |

## UI Integration

### Save Search Button

On the external listings index page, a "Save Search" button opens a modal:

```erb
<button onclick="openSaveSearchModal()">
  Save Search
</button>
```

The modal collects:
- Email address
- Alert frequency (none/daily/weekly)
- Optional: Custom name for the search

### Favorite Button

On property cards and detail pages:

```erb
<button onclick="toggleFavorite(event, '<%= property.reference %>')">
  ❤️
</button>
```

JavaScript handles:
- Checking if property is already saved (via `/my/favorites/check`)
- Saving/removing favorites
- Updating UI state

## Testing

### Factories

```ruby
# Create a saved search
create(:pwb_saved_search, :weekly, :with_price_filter)

# Create a saved property with price reduction
create(:pwb_saved_property, :price_reduced)

# Create a delivered alert
create(:pwb_search_alert, :delivered)
```

### Running Tests

```bash
# Model specs
bundle exec rspec spec/models/pwb/saved_search_spec.rb
bundle exec rspec spec/models/pwb/saved_property_spec.rb
bundle exec rspec spec/models/pwb/search_alert_spec.rb

# All related specs
bundle exec rspec spec/models/pwb/saved*.rb spec/models/pwb/search_alert_spec.rb
```

## Multi-Tenancy

All models are scoped to a website:

```ruby
# Correct: Uses tenant-scoped proxy
PwbTenant::SavedSearch.all  # Automatically scoped to current website

# Direct access (requires explicit website)
Pwb::SavedSearch.where(website: current_website)
```

The `PwbTenant::*` models use `acts_as_tenant` for automatic scoping.
