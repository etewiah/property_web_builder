# Favorites & Saved Searches Architecture Diagram

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        External Listings Page                        │
│                (pwb/site/external_listings/index.html.erb)           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Property Card Grid                      Top-Right Controls         │
│  ┌──────────────┐  ┌──────────────┐     ┌──────────────────┐      │
│  │   Property   │  │   Property   │     │ "Save Search" btn│      │
│  │    Card      │  │    Card      │     │  onclick: modal  │      │
│  │             │  │             │     │                  │      │
│  │  ❤️ Favorite │  │  ❤️ Favorite │     │                  │      │
│  │   (onclick:  │  │   (onclick:  │     │                  │      │
│  │ toggleFav)   │  │ toggleFav)   │     │                  │      │
│  └──────────────┘  └──────────────┘     └──────────────────┘      │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│  MODALS (Hidden by default, shown with JavaScript)                  │
│                                                                       │
│  ┌──────────────────────────┐  ┌──────────────────────────┐         │
│  │ Save to Favorites Modal  │  │ Save Search Modal        │         │
│  ├──────────────────────────┤  ├──────────────────────────┤         │
│  │ Email: [prefilled]       │  │ Email: [prefilled]       │         │
│  │ Notes: [textarea]        │  │ Name: [optional]         │         │
│  │                          │  │ Frequency: [dropdown]    │         │
│  │ [Save] [Cancel]          │  │ [Save] [Cancel]          │         │
│  └────────┬─────────────────┘  └────────┬─────────────────┘         │
│           │                             │                           │
└───────────┼─────────────────────────────┼───────────────────────────┘
            │ POST /my/favorites         │ POST /my/saved_searches
            │ (JSON response)             │ (HTML redirect)
            │                             │
            ▼                             ▼
      ┌─────────────────┐        ┌─────────────────┐
      │ SavedProperties │        │ SavedSearch     │
      │   Controller    │        │   Controller    │
      └────────┬────────┘        └────────┬────────┘
               │                          │
               │ @saved_property.save()   │ @saved_search.save()
               │                          │
               ▼                          ▼
      ┌─────────────────┐        ┌─────────────────┐
      │ SavedProperty   │        │ SavedSearch     │
      │     Model       │        │     Model       │
      ├─────────────────┤        ├─────────────────┤
      │ - email         │        │ - email         │
      │ - reference     │        │ - criteria      │
      │ - provider      │        │ - alert_freq    │
      │ - manage_token  │        │ - manage_token  │
      │ - property_data │        │ - unsubscribe   │
      │ - notes         │        │ - verification  │
      │ - price_*       │        │ - enabled       │
      │ - website_id    │        │ - website_id    │
      └────────┬────────┘        └────────┬────────┘
               │                          │
               │ ActiveRecord            │ ActiveRecord
               │                          │
               ▼                          ▼
      ┌─────────────────┐        ┌─────────────────┐
      │ pwb_saved_      │        │ pwb_saved_      │
      │ properties      │        │ searches        │
      │   (Database)    │        │   (Database)    │
      └─────────────────┘        └─────────────────┘
```

## User Access Flow

```
User visits external listings page
         │
         ▼
Sees property cards with ❤️ icons
         │
         ├─────────────────────────┬──────────────────────┐
         │                         │                      │
         ▼ (Click heart)           ▼ (Click Save Search)  │
  openFavoriteModal()        openSaveSearchModal()        │
         │                         │                      │
         ├─ localStorage.getItem   ├─ localStorage.getItem
         │  ('pwb_favorites_email')│  ('pwb_favorites_email')
         │  [Pre-fill email]       │  [Pre-fill email]    │
         │                         │                      │
         ▼                         ▼                      │
   Show favorite modal       Show save search modal       │
   - Email field             - Email field                │
   - Notes textarea          - Search name               │
   - Save button             - Frequency selector        │
         │                         │                      │
         │ [User fills form]       │ [User fills form]    │
         │                         │                      │
         ▼ [Submit]                ▼ [Submit]            │
  Form submission           Form submission              │
         │                         │                      │
         ├────POST /my/favorites───┼────POST /my/saved_searches
         │  email, notes           │   email, name, frequency, criteria
         │                         │
         ▼                         ▼
    Create SavedProperty     Create SavedSearch
    - Auto-assign token      - Auto-assign tokens
    - Cache property data    - Auto-generate name
    - Store to DB            - Mark as verified
    - Respond with success   - Respond with success
         │                         │
         ├─────────────────────────┤
         │                         │
    localStorage.setItem('pwb_favorites_email', email)
         │
         ▼
User can view favorites at /my/favorites?token=XXXXX
User can view searches at  /my/saved_searches?token=XXXXX
```

## Email Access Flow

```
User clicks email link in:
- Email from favorites page: /my/favorites?token=MANAGE_TOKEN
- Email from searches page:  /my/saved_searches?token=MANAGE_TOKEN
- Email to unsubscribe:      /my/saved_searches/unsubscribe?token=UNSUB_TOKEN
- Email to verify:           /my/saved_searches/verify?token=VERIFY_TOKEN

         │
         ▼
  Extract token from URL
         │
         ├──────────────────────────┬──────────────────┐
         │                          │                  │
    MANAGE_TOKEN?           UNSUB_TOKEN?         VERIFY_TOKEN?
         │                          │                  │
         ▼                          ▼                  ▼
  Find SavedProperty/     Find SavedSearch      Find SavedSearch
  SavedSearch by          Unsubscribe!          Verify Email!
  manage_token            update(enabled: false)verify_email!()
         │                          │                  │
         ▼                          ▼                  ▼
  Show list of items      Show confirmation     Redirect to
  for that email          page                  /my/saved_searches
```

## Database Structure

```
┌────────────────────────────────────────┐
│    pwb_saved_properties (Favorites)    │
├────────────────────────────────────────┤
│ id (PK)                                │
│ email (indexed)                        │
│ external_reference (unique per email)  │
│ provider (Feed provider name)          │
│ manage_token (UNIQUE)                  │
│ property_data (JSONB cache)            │
│ notes (User annotations)               │
│ original_price_cents                   │
│ current_price_cents (Price tracking)   │
│ price_changed_at (Timestamp)           │
│ website_id (FK to websites)            │
│ created_at, updated_at                 │
└────────────────────────────────────────┘
          │
          │ acts_as_tenant
          ▼
┌────────────────────────────────────┐
│     pwb_websites (Tenants)         │
├────────────────────────────────────┤
│ id (PK)                            │
│ ...                                │
└────────────────────────────────────┘

┌─────────────────────────────────────────┐
│     pwb_saved_searches (Alerts)         │
├─────────────────────────────────────────┤
│ id (PK)                                 │
│ email (indexed)                         │
│ name (Auto-generated from criteria)     │
│ search_criteria (JSONB)                 │
│ alert_frequency (enum: none/daily/week) │
│ enabled (boolean)                       │
│ email_verified (boolean)                │
│ manage_token (UNIQUE)                   │
│ unsubscribe_token (UNIQUE)              │
│ verification_token (UNIQUE)             │
│ seen_property_refs (JSONB array)        │
│ last_run_at (Alert timestamp)           │
│ last_result_count (Results in last run) │
│ website_id (FK to websites)             │
│ created_at, updated_at                  │
└─────────────────────────────────────────┘
```

## API Endpoints Summary

```
SAVED PROPERTIES (Favorites)
────────────────────────────────────────
POST   /my/favorites
       Save new property
       Params: email, external_reference, provider, property_data, notes

GET    /my/favorites?token=MANAGE_TOKEN
       List all properties for email (via token)

GET    /my/favorites/:id?token=MANAGE_TOKEN
       Show single property details

PATCH  /my/favorites/:id?token=MANAGE_TOKEN
       Update property notes
       Params: notes

DELETE /my/favorites/:id?token=MANAGE_TOKEN
       Remove from favorites

POST   /my/favorites/check
       Check if properties are saved (for UI indicator)
       Params: email, references[]
       Returns: { saved: ["ref1", "ref2"] }

SAVED SEARCHES (Alerts)
────────────────────────────────────────
POST   /my/saved_searches
       Create new saved search
       Params: email, search_criteria, name, alert_frequency

GET    /my/saved_searches?token=MANAGE_TOKEN
       List all searches for email (via token)

GET    /my/saved_searches/:id?token=MANAGE_TOKEN
       Show search details with recent alerts

PATCH  /my/saved_searches/:id?token=MANAGE_TOKEN
       Update alert frequency or status
       Params: name, alert_frequency, enabled

DELETE /my/saved_searches/:id?token=MANAGE_TOKEN
       Delete search

GET    /my/saved_searches/verify?token=VERIFY_TOKEN
       Verify email address (from email link)

GET    /my/saved_searches/unsubscribe?token=UNSUB_TOKEN
       Unsubscribe from alerts (from email link)
```

## LocalStorage Usage

```
┌─────────────────────────────────────────┐
│        Browser LocalStorage             │
├─────────────────────────────────────────┤
│ Key: 'pwb_favorites_email'              │
│ Value: user@example.com                 │
│ Purpose: Pre-fill email in forms        │
│ Set: On form submission (favorite/search)
│ Read: When opening modals               │
│ Scope: Single domain, persistent        │
└─────────────────────────────────────────┘

Usage in Views:
- /app/views/pwb/site/external_listings/index.html.erb
  * openSaveSearchModal() - reads to prefill
  * toggleFavorite() - reads to prefill
  * Form submit handlers - writes after submission

- /app/themes/default/views/pwb/props/show.html.erb
  * Same pattern as external listings

Security Note:
- Only stores email address (not sensitive on its own)
- No auth tokens stored in localStorage
- Used purely for UX convenience
- No personal data beyond email
```

## Authentication Flow

```
┌────────────────────────────────────────────┐
│   Token-Based Access (No Login)            │
├────────────────────────────────────────────┤
│                                            │
│ 1. User saves property/search              │
│    ↓                                       │
│ 2. Server generates unique manage_token    │
│    ↓                                       │
│ 3. Server generates unsubscribe_token      │
│    ↓                                       │
│ 4. Tokens sent in email links              │
│    ↓                                       │
│ 5. User clicks email link with token       │
│    ↓                                       │
│ 6. Server finds record by token            │
│    ↓                                       │
│ 7. User can manage without login           │
│                                            │
│ Security: Token = SecureRandom.urlsafe    │
│           base64(32) = 256-bit entropy    │
│                                            │
└────────────────────────────────────────────┘
```

## Data Flow: Saving a Property

```
┌─ User on property card
│   Click ❤️ heart icon
│   └─ event.preventDefault()
│      event.stopPropagation()
│
├─ toggleFavorite() JS function called
│   - Gets reference, title, propertyData
│   - Reads localStorage for email
│   - Populates modal hidden inputs
│   - Shows modal dialog
│
├─ User fills email (or uses pre-filled)
│   User adds optional notes
│   Click "Save to Favorites" button
│
├─ Form submit
│   POST /my/favorites
│   Content-Type: application/x-www-form-urlencoded
│   Body: {
│     saved_property[email]: 'user@example.com',
│     saved_property[external_reference]: 'property-123',
│     saved_property[provider]: 'external_feed_name',
│     saved_property[property_data]: {...},
│     saved_property[notes]: '...'
│   }
│
├─ SavedPropertiesController#create
│   - Validate parameters
│   - Check if external feed configured
│   - Create SavedProperty record
│   - Auto-generate manage_token
│   - Fetch/cache property data if needed
│   - Save to database
│
├─ Database insert
│   INSERT INTO pwb_saved_properties (
│     email, external_reference, provider, manage_token,
│     property_data, notes, original_price_cents,
│     current_price_cents, website_id, created_at
│   ) VALUES (...)
│
├─ Response (JSON)
│   {
│     "success": true,
│     "message": "Property saved to favorites",
│     "manage_url": "https://example.com/my/favorites?token=...",
│     "saved_property_id": 123
│   }
│
├─ localStorage updated
│   localStorage.setItem('pwb_favorites_email', 'user@example.com')
│
└─ Modal closes, user can continue browsing
   Email sent via background job with manage_url
```

## Data Flow: Saving a Search

```
┌─ User on external listings page
│   Click "Save Search" button
│   └─ openSaveSearchModal()
│      Reads localStorage for email
│      Shows modal
│
├─ User fills:
│   - Email
│   - Search name (optional)
│   - Alert frequency (daily/weekly/none)
│   Click "Save Search" button
│
├─ Form submit
│   POST /my/saved_searches
│   Body: {
│     saved_search[email]: 'user@example.com',
│     saved_search[name]: 'Beachfront Rentals',
│     saved_search[alert_frequency]: 'daily',
│     saved_search[search_criteria]: {
│       location: 'Miami',
│       min_price: 500,
│       max_price: 2000,
│       property_types: ['apartment'],
│       listing_type: 'rental'
│     }
│   }
│
├─ SavedSearchesController#create
│   - Validate parameters
│   - Check if external feed configured
│   - Create SavedSearch record
│   - Auto-generate tokens (manage, unsubscribe, verify)
│   - Auto-generate name if not provided
│   - Mark as verified (skip email verification for now)
│   - Save to database
│
├─ Database insert
│   INSERT INTO pwb_saved_searches (
│     email, name, search_criteria,
│     alert_frequency, enabled, email_verified,
│     manage_token, unsubscribe_token, verification_token,
│     website_id, created_at
│   ) VALUES (...)
│
├─ Response (redirect)
│   GET /my/saved_searches?token=MANAGE_TOKEN
│   Shows success message "Search saved!"
│
├─ localStorage updated
│   localStorage.setItem('pwb_favorites_email', 'user@example.com')
│
└─ Email sent with:
   - Link to manage: /my/saved_searches?token=MANAGE_TOKEN
   - Link to unsubscribe: /my/saved_searches/unsubscribe?token=UNSUB_TOKEN
   - Alert frequency confirmation
```
