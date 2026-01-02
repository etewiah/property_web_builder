# External Feed Configuration System - Documentation Index

This directory contains detailed documentation about PropertyWebBuilder's external property feed configuration system.

## Documents in This Collection

### 1. [EXTERNAL_FEED_SUMMARY.md](./EXTERNAL_FEED_SUMMARY.md) - **START HERE**
**Best for:** Quick understanding of the entire system  
**Length:** ~500 lines  
**Content:**
- What the system does
- How configuration is stored
- Filter options architecture
- Admin interface overview
- Search/filter flow
- Existing configuration options
- File locations

**Read this first if you want:** High-level overview and how things fit together

---

### 2. [EXTERNAL_FEED_QUICK_REFERENCE.md](./EXTERNAL_FEED_QUICK_REFERENCE.md)
**Best for:** Quick lookup while coding  
**Length:** ~600 lines  
**Content:**
- Configuration storage structure (code snippets)
- Filter options architecture diagram
- Search parameter flow
- Key classes and methods reference
- Controller endpoints list
- Cache TTLs
- Property type normalization
- Provider system overview
- Error handling classes
- Multi-tenancy explanation
- File locations organized by function
- Common operations code examples
- Extension checklist

**Read this when you need:** Quick reference, API documentation, method signatures

---

### 3. [EXTERNAL_FEED_DATA_FLOW.md](./EXTERNAL_FEED_DATA_FLOW.md)
**Best for:** Understanding how data moves through the system  
**Length:** ~700 lines  
**Content:**
- Admin configuration setup flow (detailed)
- Test connection flow
- Search/filter request flow (detailed)
- Filter options discovery flow
- Property detail lookup flow
- Configuration data structure (JSON)
- Caching strategy with examples
- Provider registration at startup
- Configuration layers diagram

**Read this when you need:** To understand request/response flow, debug data movement, or see the complete flow with all details

---

### 4. [EXTERNAL_FEED_CONFIG_EXPLORATION.md](./EXTERNAL_FEED_CONFIG_EXPLORATION.md)
**Best for:** Deep technical exploration  
**Length:** ~1500 lines  
**Content:**
- Website model configuration storage (with code)
- Database schema details
- Model methods documentation
- Configuration schema with examples
- ExternalFeed::Manager filter_options method (complete code)
- Filter options structure and response examples
- Manager initialization details
- External listings controller actions (complete code)
- Search parameters processing code
- Site admin controller actions (complete code)
- Provider configuration fields with examples
- Parameter handling code
- Provider system architecture
- NormalizedProperty attributes (80+)
- NormalizedSearchResult structure and methods
- Cache store implementation
- Cache invalidation strategy
- Error handling
- Key files summary
- Configuration flow explanation

**Read this when you need:** Complete code-level understanding, implementation details, or to review all methods and attributes

---

## Which Document Should I Read?

### "I need a quick overview"
→ Start with **EXTERNAL_FEED_SUMMARY.md**

### "I need to make a configuration change"
→ Use **EXTERNAL_FEED_QUICK_REFERENCE.md**

### "I need to understand how requests flow"
→ Read **EXTERNAL_FEED_DATA_FLOW.md**

### "I need complete technical details"
→ Read **EXTERNAL_FEED_CONFIG_EXPLORATION.md**

### "I need to add a new provider"
→ **EXTERNAL_FEED_QUICK_REFERENCE.md** (Extension Checklist) + **EXTERNAL_FEED_CONFIG_EXPLORATION.md** (Provider Implementation)

### "I'm debugging a problem"
→ **EXTERNAL_FEED_DATA_FLOW.md** (understand flow) + **EXTERNAL_FEED_QUICK_REFERENCE.md** (find methods/endpoints)

### "I want to understand everything"
→ Read in order: SUMMARY → QUICK_REFERENCE → DATA_FLOW → DETAILED_EXPLORATION

---

## System Overview

The external feed configuration system allows PropertyWebBuilder websites to display property listings from third-party providers (like Resales Online).

### Key Components

```
Website Model
  ├── external_feed_enabled (boolean)
  ├── external_feed_provider (string)
  └── external_feed_config (json)
       │
       ├── api_key, api_id_sales, etc. (provider credentials)
       ├── cache_ttl_search, cache_ttl_property (cache configuration)
       ├── results_per_page, default_locale (defaults)
       └── Optional: locations, property_types, features (custom mappings)
            │
            ├─→ Manager.filter_options() returns
            │   ├── locations (dynamic from provider)
            │   ├── property_types (dynamic from provider)
            │   ├── listing_types (static)
            │   ├── sort_options (static)
            │   ├── bedrooms (static)
            │   └── bathrooms (static)
            │
            └─→ Manager.search(params)
                ├── Normalizes parameters
                ├── Checks cache (1-hour TTL)
                ├── Calls Provider.search()
                └── Returns NormalizedSearchResult
                    └── Array of NormalizedProperty objects
```

### Data Flow

```
Admin Configuration
    ↓
Website.external_feed_config (JSON) 
    ↓
Manager (loads config)
    ├── Filter Options (static + dynamic)
    ├── Search (cache + provider)
    ├── Find Property (cache + provider)
    └── Similar Properties (search-based)
         │
         ├─→ Provider (talks to external API)
         │
         └─→ Cache Store (Redis/Memory)
              │
              └─→ NormalizedProperty objects
                   ↓
                   Controller
                    ↓
                   View/JSON Response
```

### Admin Interface

```
/site_admin/external_feed
├── Show: List providers, display config form
├── Update: Save credentials and settings
├── Test: Verify connection to provider
└── Clear Cache: Force refresh of data
```

### Frontend Endpoints

```
/external_listings              → Search with filters
/external_listings/:reference   → Property details
/external_listings/filters      → JSON - all filter options
/external_listings/locations    → JSON - locations only
/external_listings/property_types → JSON - property types only
```

---

## Key Files

**Configuration Storage:**
- `/app/models/pwb/website.rb` - Model with external_feed methods

**Business Logic:**
- `/app/services/pwb/external_feed/manager.rb` - Main coordinator (includes filter_options)
- `/app/services/pwb/external_feed/providers/resales_online.rb` - Resales Online provider

**Controllers:**
- `/app/controllers/pwb/site/external_listings_controller.rb` - Frontend
- `/app/controllers/site_admin/external_feeds_controller.rb` - Admin

**Documentation:**
- `/docs/admin/external_feeds.md` - Admin user guide
- `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` - Full architecture (2000+ lines)

---

## Quick Facts

- **Storage:** `pwb_websites.external_feed_config` (JSON column)
- **Current Provider:** Resales Online (Spanish properties)
- **Languages Supported:** EN, ES, DE, FR, NL, DA, RU, SV, PL, NO, TR
- **Cache TTLs:** 1 hour (search), 24 hours (property), 6 hours (similar), 1 week (static)
- **Multi-tenant:** Yes - each website isolated
- **Admin Interface:** `/site_admin/external_feed`
- **Frontend Routes:** `/external_listings` + sub-routes
- **API Endpoints:** Filter discovery via JSON endpoints

---

## Configuration Options Summary

### Required (Resales Online)
- `api_key` - API credentials
- `api_id_sales` - Sales listings ID

### Optional (Resales Online)
- `api_id_rentals` - Rental listings ID
- `p1_constant` - Provider constant
- `default_country` - Location default
- `image_count` - Number of images

### Cache Settings
- `cache_ttl_search` - Search cache (seconds)
- `cache_ttl_property` - Property cache (seconds)
- `cache_ttl_similar` - Similar cache (seconds)
- `cache_ttl_static` - Static data cache (seconds)

### Defaults
- `results_per_page` - Results per page
- `default_locale` - Default language
- `supported_locales` - Supported languages

### Custom Data (optional)
- `locations` - Custom location list
- `property_types` - Custom property types
- `features` - Feature name mappings

---

## Filter Options

What `Manager.filter_options()` returns:

```json
{
  "locations": [
    {"value": "Marbella", "label": "Marbella"}
  ],
  "property_types": [
    {"value": "1-1", "label": "Apartment", "subtypes": [...]}
  ],
  "listing_types": [
    {"value": "sale", "label": "For Sale"},
    {"value": "rental", "label": "For Rent"}
  ],
  "sort_options": [
    {"value": "price_asc", "label": "Price (Low to High)"},
    {"value": "price_desc", "label": "Price (High to Low)"},
    {"value": "newest", "label": "Newest First"},
    {"value": "updated", "label": "Recently Updated"}
  ],
  "bedrooms": [
    {"value": "1", "label": "1+"},
    {"value": "2", "label": "2+"},
    ...
  ],
  "bathrooms": [
    {"value": "1", "label": "1+"},
    ...
  ]
}
```

---

## Common Tasks

### Configure External Feed for a Website
```ruby
website.configure_external_feed(
  provider: :resales_online,
  config: {
    api_key: "xxx",
    api_id_sales: "123"
  },
  enabled: true
)
```

### Get Filter Options
```ruby
options = website.external_feed.filter_options(locale: :en)
# returns hash with all filter options
```

### Search Properties
```ruby
result = website.external_feed.search(
  listing_type: :sale,
  location: "Marbella",
  min_price: 100000
)
result.properties  # Array of NormalizedProperty
result.total_count # Total matches
result.total_pages # For pagination
```

### Clear Cache
```ruby
website.clear_external_feed_cache
```

---

## Next Steps

1. **To understand the system:** Read EXTERNAL_FEED_SUMMARY.md
2. **To work with it:** Bookmark EXTERNAL_FEED_QUICK_REFERENCE.md
3. **To debug issues:** Use EXTERNAL_FEED_DATA_FLOW.md
4. **For complete details:** Refer to EXTERNAL_FEED_CONFIG_EXPLORATION.md
5. **For implementation details:** See original files in `/docs/admin/` and `/docs/architecture/`

---

## Related Documentation

**Official System Documentation:**
- `/docs/admin/external_feeds.md` - Admin guide
- `/docs/architecture/EXTERNAL_FEEDS_INTEGRATION.md` - Complete architecture

**Code Files:**
- See EXTERNAL_FEED_QUICK_REFERENCE.md or EXTERNAL_FEED_CONFIG_EXPLORATION.md for file locations

---

## Questions?

Refer to the appropriate document:
- "How does it work?" → SUMMARY or DATA_FLOW
- "What's the code?" → QUICK_REFERENCE or DETAILED_EXPLORATION
- "How do I...?" → QUICK_REFERENCE
- "Where's the file?" → FILE LOCATIONS sections in any document

