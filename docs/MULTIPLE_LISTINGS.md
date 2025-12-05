# Multiple Listings per Property

This document describes the feature that allows multiple sale and rental listings per property (RealtyAsset), with only one active listing of each type at a time.

## Overview

A property (RealtyAsset) can have multiple sale listings and/or multiple rental listings over time. This is useful for:

- Tracking price history (e.g., property was listed at $300K, then $280K, now $260K)
- Re-listing properties after a period off-market
- Managing seasonal pricing changes for rentals
- Keeping a history of listings for reporting purposes

**Key Constraint**: Only one sale listing and one rental listing can be "active" at a time per property. The active listing is the one displayed on the website.

## Database Schema

### New Fields

Both `pwb_sale_listings` and `pwb_rental_listings` tables now include:

- `active` (boolean, default: false) - Indicates if this is the currently active listing

### Unique Index

A partial unique index ensures only one active listing per property:

```sql
CREATE UNIQUE INDEX index_pwb_sale_listings_unique_active
ON pwb_sale_listings (realty_asset_id, active)
WHERE active = true;

CREATE UNIQUE INDEX index_pwb_rental_listings_unique_active
ON pwb_rental_listings (realty_asset_id, active)
WHERE active = true;
```

## Model Changes

### SaleListing and RentalListing

New scopes:
- `active_listing` - Returns only active listings
- `not_archived` - Returns non-archived listings

New methods:
- `activate!` - Sets this listing as active, deactivating any other active listing for the same property
- `deactivate!` - Removes active status from this listing
- `archive!` - Archives the listing (only works on non-active listings)
- `unarchive!` - Removes archived status
- `can_destroy?` - Returns true if the listing can be deleted (only non-active listings can be deleted)

Callbacks:
- Before save: If activating, deactivates other listings for the same property
- Validation: Cannot archive an active listing
- Validation: Cannot delete an active listing

### RealtyAsset

New methods:
- `active_sale_listing` - Returns the active sale listing (or nil)
- `active_rental_listing` - Returns the active rental listing (or nil)

### Materialized View (pwb_properties)

The materialized view now joins only on `active = true` listings:

```sql
LEFT JOIN pwb_sale_listings sl
  ON sl.realty_asset_id = a.id
  AND sl.active = true
LEFT JOIN pwb_rental_listings rl
  ON rl.realty_asset_id = a.id
  AND rl.active = true
```

## Admin Interface

### Properties List View (`/site_admin/props`)

The list now shows:
- **Active Listings** column with clickable badges:
  - "Sale (Active)" - Green badge, links to edit the active sale listing
  - "Sale (Hidden)" - Gray badge, links to edit the sale listing that's active but not visible
  - "Rent (Active)" - Purple badge, links to edit the active rental listing
  - "Rent (Hidden)" - Gray badge, links to edit the rental listing that's active but not visible
  - "No active listings" - Shown when no active listings exist
- **Actions** column now includes "Listings" link

### Listings Management View (`/site_admin/props/:id/edit/sale_rental`)

Completely redesigned to manage multiple listings:

**For each listing type (Sale/Rental):**
1. Header with "New Listing" button
2. List of all listings (sorted: active first, then by creation date)
3. Each listing shows:
   - Status badges (Active, Visible, Archived, Featured, etc.)
   - Price
   - Creation date
   - Actions:
     - Edit - Always available
     - Activate - Only for non-active listings
     - Archive/Unarchive - Only for non-active listings
     - Delete - Only for non-active listings

### New/Edit Listing Views

Each listing type has dedicated new/edit forms:

**Sale Listing** (`/site_admin/props/:prop_id/sale_listings/new|:id/edit`):
- Active checkbox with explanation
- Visibility flags (Visible, Highlighted, Reserved, Furnished)
- Pricing (Sale price + currency, Commission)
- Title & Description per locale

**Rental Listing** (`/site_admin/props/:prop_id/rental_listings/new|:id/edit`):
- Active checkbox with explanation
- Visibility flags (Visible, Highlighted, Reserved, Furnished)
- Rental type (Short Term, Long Term)
- Pricing (Monthly rent, Low/High season prices)
- Title & Description per locale

## Routes

New nested routes under `props`:

```ruby
resources :props do
  resources :sale_listings, controller: 'props/sale_listings' do
    member do
      patch :activate
      patch :archive
      patch :unarchive
    end
  end

  resources :rental_listings, controller: 'props/rental_listings' do
    member do
      patch :activate
      patch :archive
      patch :unarchive
    end
  end
end
```

## Migration Guide

After running the migration:

1. Existing visible, non-archived listings are automatically set as active
2. If multiple listings exist for a property, the most recent one becomes active
3. Review properties with multiple listings to ensure the correct one is active

## Usage Examples

### Creating a New Listing

```ruby
asset = Pwb::RealtyAsset.find(id)

# Create and activate a new sale listing
listing = asset.sale_listings.create!(
  price_sale_current_cents: 250_000_00,
  visible: true,
  active: true  # This will deactivate any other active sale listing
)
```

### Switching Active Listing

```ruby
# Find an old listing to reactivate
old_listing = asset.sale_listings.find(old_id)

# Activate it (automatically deactivates current active listing)
old_listing.activate!
```

### Archiving a Listing

```ruby
listing = asset.sale_listings.find(id)

# First deactivate if it's active
listing.deactivate! if listing.active?

# Then archive
listing.archive!
```

### Getting Active Listing

```ruby
asset = Pwb::RealtyAsset.find(id)

# Get active listings
active_sale = asset.active_sale_listing
active_rental = asset.active_rental_listing

# Check if property has active listings
asset.for_sale?  # true if active sale listing is visible
asset.for_rent?  # true if active rental listing is visible
```

## Tests

New tests added to `spec/models/pwb/sale_listing_spec.rb` and `spec/models/pwb/rental_listing_spec.rb`:

- Active listing management
- Activation/deactivation behavior
- Archive restrictions
- Deletion restrictions
- Scope behavior

Run tests with:

```bash
bundle exec rspec spec/models/pwb/sale_listing_spec.rb
bundle exec rspec spec/models/pwb/rental_listing_spec.rb
```
