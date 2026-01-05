# Favorites and Saved Searches Implementation Summary

## Overview

The PropertyWebBuilder application has a **fully implemented favorites (saved properties) and saved searches system** for external property feeds. The system is email-based, allowing users to save properties and searches without logging in.

## Current Implementation

### 1. Database Models & Schema

#### SavedProperty Model
**Model Files:**
- `/app/models/pwb/saved_property.rb` (base model)
- `/app/models/pwb_tenant/saved_property.rb` (tenant-scoped)

**Database Table:** `pwb_saved_properties`

**Schema:**
```
- id (primary key)
- email (string, indexed) - normalized email for the user
- external_reference (string) - unique identifier from external feed
- provider (string) - feed provider name
- manage_token (string, unique) - token for managing favorites without login
- property_data (jsonb) - cached property data (title, price, images, etc.)
- notes (text) - user notes about the property
- original_price_cents (integer) - price when saved
- current_price_cents (integer) - current price for tracking
- price_changed_at (datetime) - when price last changed
- website_id (bigint, foreign key) - tenant scoping
- created_at, updated_at
```

**Key Indexes:**
- `(email)`
- `(manage_token)` - UNIQUE
- `(website_id, email)`
- `(website_id, provider, external_reference)` - UNIQUE per email

**Features:**
- Token-based access (no user login required)
- Price tracking (original vs current price)
- Property data caching (full JSONB storage)
- User notes/annotations
- Email-based uniqueness (same user can't save same property twice)

#### SavedSearch Model
**Model Files:**
- `/app/models/pwb/saved_search.rb` (base model)
- `/app/models/pwb_tenant/saved_search.rb` (tenant-scoped)

**Database Table:** `pwb_saved_searches`

**Schema:**
```
- id (primary key)
- email (string, indexed) - user email
- name (string) - optional search name
- search_criteria (jsonb) - saved filter parameters
- alert_frequency (integer, enum) - none/daily/weekly
- enabled (boolean) - if alerts are enabled
- email_verified (boolean) - email verification status
- verify_token (string) - email verification token
- unsubscribe_token (string, unique) - for email unsubscribe links
- manage_token (string, unique) - for managing searches
- seen_property_refs (jsonb) - array of seen property references (up to 1000)
- last_run_at (datetime) - last alert sent
- last_result_count (integer) - number of results in last run
- verified_at (datetime)
- website_id (bigint, foreign key) - tenant scoping
- created_at, updated_at
```

**Key Indexes:**
- `(email)`
- `(manage_token)` - UNIQUE
- `(unsubscribe_token)` - UNIQUE
- `(verification_token)` - UNIQUE
- `(website_id, email)`
- `(website_id, enabled, alert_frequency)` - for alert queries

**Features:**
- Email-based alerts (daily/weekly/none)
- Search criteria storage
- Email verification flow
- Unsubscribe functionality
- Tracking seen properties to avoid duplicate alerts
- Automatic search naming based on criteria

### 2. Controllers

#### SavedPropertiesController
**Location:** `/app/controllers/pwb/site/my/saved_properties_controller.rb`

**Routes:**
- `POST /my/favorites` - Save a property
- `GET /my/favorites?token=XXX` - List saved properties
- `GET /my/favorites/:id?token=XXX` - Show single property
- `PATCH /my/favorites/:id?token=XXX` - Update notes
- `DELETE /my/favorites/:id?token=XXX` - Remove from favorites
- `POST /my/favorites/check` - Check if properties are saved (for UI)

**Key Methods:**
- `create` - Save property with optional property data caching
- `index` - List all properties for an email (token-based)
- `show` - Display single property with optional refresh
- `update` - Update user notes
- `destroy` - Remove from favorites
- `check` - JSON endpoint to check saved status for multiple properties

**Authentication:** Token-based (no login required)
- `manage_token` query parameter provides access

#### SavedSearchesController
**Location:** `/app/controllers/pwb/site/my/saved_searches_controller.rb`

**Routes:**
- `POST /my/saved_searches` - Create new saved search
- `GET /my/saved_searches?token=XXX` - List searches
- `GET /my/saved_searches/:id?token=XXX` - Show single search
- `PATCH /my/saved_searches/:id?token=XXX` - Update alert settings
- `DELETE /my/saved_searches/:id?token=XXX` - Delete search
- `GET /my/saved_searches/verify?token=XXX` - Verify email
- `GET /my/saved_searches/unsubscribe?token=XXX` - Unsubscribe from alerts

**Key Methods:**
- `create` - Save search with alert frequency
- `index` - List all searches for email
- `show` - Display search details and recent alerts
- `update` - Change alert frequency or enabled status
- `destroy` - Delete search
- `verify` - Verify email address
- `unsubscribe` - Disable alerts

**Authentication:** Token-based (manage_token or unsubscribe_token)

### 3. Views & UI

#### Favorites Management Page
**Location:** `/app/views/pwb/site/my/saved_properties/index.html.erb`

**Features:**
- Grid layout showing all saved properties
- Property cards with:
  - Main image
  - Favorite badge (red)
  - Price change indicators (green/orange)
  - Title, location, price, bedrooms, bathrooms
  - User notes display
  - View Property link
  - Delete button
- No favorites empty state page

#### Saved Searches Management Page
**Location:** `/app/views/pwb/site/my/saved_searches/index.html.erb`

**Features:**
- List of all searches
- Each search shows:
  - Search name
  - Search criteria summary (location, type, price, beds, etc.)
  - Alert frequency badge
  - Last checked timestamp
  - Matching properties count
  - Edit and View Results buttons
- Instructions to create new searches

### 4. Frontend Implementation

#### Save to Favorites Modal
**Location:** `/app/views/pwb/site/external_listings/index.html.erb` (lines 287-355)

**Features:**
- Modal dialog triggered by heart icon on property cards
- Email field (prefilled from localStorage)
- Optional notes textarea
- Submit button

#### Save Search Modal
**Location:** `/app/views/pwb/site/external_listings/index.html.erb` (lines 207-285)

**Features:**
- Modal triggered by "Save Search" button
- Email field (prefilled from localStorage)
- Optional search name field
- Alert frequency dropdown (daily/weekly/none)
- Submit button

#### Property Card Favorite Button
**Location:** `/app/views/pwb/site/external_listings/_property_card.html.erb` (lines 36-58)

**Features:**
- Heart icon in top-right corner of image
- Calls `toggleFavorite()` JavaScript function
- Passes property data as JSON
- Pre-filled from localStorage

### 5. JavaScript/LocalStorage Usage

**Current localStorage Implementation:**
```javascript
// Key: 'pwb_favorites_email'
// Stores user's email for convenience

// Usage in external_listings/index.html.erb:
openSaveSearchModal() {
  var savedEmail = localStorage.getItem('pwb_favorites_email');
  // Pre-fill email field if available
}

toggleFavorite(event, reference, title, propertyData) {
  var savedEmail = localStorage.getItem('pwb_favorites_email');
  // Pre-fill email field
  document.getElementById('favorite-modal').classList.remove('hidden');
}

// Save email on form submission:
document.addEventListener('DOMContentLoaded', function() {
  favoriteForm.addEventListener('submit', function() {
    localStorage.setItem('pwb_favorites_email', emailInput.value);
  });
});
```

**Locations Using localStorage:**
1. `/app/views/pwb/site/external_listings/index.html.erb` - Save/Favorite modals
2. `/app/themes/default/views/pwb/props/show.html.erb` - Property detail page
3. `/app/views/pwb/editor/show.html.erb` - Page editor panel height
4. `/app/views/layouts/site_admin/_navigation.html.erb` - Admin nav state
5. `/app/views/layouts/site_admin.html.erb` - Tour completion tracking

### 6. API/JSON Endpoints

**Check if properties are saved:**
```
POST /my/favorites/check
Parameters: email, references[]
Response: { saved: ["ref1", "ref2", ...] }
```

## Key Characteristics

### Email-Based System (No Login Required)
- Users save properties/searches with just their email
- Access via token-based manage URLs
- Can manage multiple saves from the same email
- No user account creation needed

### Token-Based Authentication
- **manage_token**: For accessing/managing saved items
- **unsubscribe_token**: For email unsubscribe links
- **verification_token**: For email verification
- All tokens are secure 32-byte base64 strings

### LocalStorage Usage (NOT GDPR-BLOCKED)
- Currently stores only `pwb_favorites_email`
- **Not sensitive** - just email address for convenience
- Pre-fills forms to improve UX
- Persists across page refreshes

### No Cookie Consent Banner
- **No consent/GDPR banner currently implemented**
- Code includes utilities for scraper to close cookie dialogs on external sites
- No first-party cookies set by app for storage

### Price Tracking
- Saves original price when favorited
- Tracks current price in separate column
- Includes price_changed_at timestamp
- Calculates percentage change

### Search Alerts
- Email frequency options: daily, weekly, none
- Tracks seen properties to avoid duplicate alerts
- Maintains last_run_at and last_result_count

## Database Migrations

- `/db/migrate/20260101225640_create_pwb_saved_searches.rb`
- `/db/migrate/20260101225644_create_pwb_saved_properties.rb`

Both created January 1, 2026.

## Multi-Tenancy

Both models use `acts_as_tenant :website` to scope data:
- Saved properties are website-specific
- Searches are website-specific
- Data isolation by website_id

## Routing

```ruby
# From routes.rb
namespace :pwb do
  namespace :site do
    namespace :my do
      resources :saved_properties do
        collection do
          post :check
        end
      end
      resources :saved_searches do
        member do
          get :verify
          get :unsubscribe
        end
      end
    end
  end
end
```

## Current Limitations/Notes

1. **Email Verification**: Saved searches immediately mark as verified (line 22 in saved_searches_controller)
   - Comment suggests optional future email verification flow
   - Currently bypassed for simplicity

2. **Property Data**: External references are fetched and cached
   - Falls back to provided property_data if available
   - Prevents issues when external feed doesn't return full data

3. **Seen Properties**: Limited to last 1000 (saved_search.rb line 137)
   - Prevents unbounded growth of tracking array

4. **localStorage Scope**: Simple, single-key approach
   - Only stores email
   - No complex state management
   - Survives only within same browser/domain

## Summary for Feature Development

### What's Already Implemented:
- Database models with proper relationships
- Controllers for CRUD operations
- Email-based authentication/access
- Token-based management URLs
- Property price tracking
- Search alert frequency options
- localStorage for email persistence
- Modal UI components for save actions

### What Would Needed for Enhancement:

1. **Cookie Consent Banner** - If storing more data in localStorage
   - Currently not needed as only storing email
   - Might be needed for analytics tracking

2. **User Accounts** - To link favorites/searches to login
   - Currently works anonymously via email + token
   - Would require redesigning token system

3. **Enhanced Notifications** - For price changes, new matches
   - Infrastructure exists for alert_frequency
   - Would need email template system

4. **Collaborative Features** - Share saved searches/favorites
   - Would need sharing token system

5. **Advanced Analytics** - Track search behavior
   - Would need separate tracking table
   - Requires explicit consent if GDPR applies
