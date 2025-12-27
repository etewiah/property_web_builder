# PropertyWebBuilder: Property Schema Diagram & Relationships

## Entity Relationship Diagram

```
                              ┌─────────────────┐
                              │   pwb_websites  │
                              │  (multi-tenant) │
                              │  website_id: int│
                              └────────┬────────┘
                                       │
                            ┌──────────┴──────────┐
                            │                     │
                    ┌───────▼────────────┐   (tenant scoping)
                    │ pwb_realty_assets  │
                    │   (Physical Props) │
                    │   id: uuid (PK)    │
                    │   website_id: int  │
                    │   website_fk───┘   │
                    │                    │
                    │ Fields:            │
                    │ • reference        │
                    │ • slug (unique)    │
                    │ • street_address   │
                    │ • city, region     │
                    │ • lat, lng         │
                    │ • count_beds       │
                    │ • count_baths      │
                    │ • constructed_area │
                    │ • plot_area        │
                    │ • year_built       │
                    │ • prop_type_key    │
                    │ • prop_state_key   │
                    │ • energy_rating    │
                    │ • translations     │
                    │ • created_at       │
                    └────┬──────────┬────┘
                         │          │
           ┌─────────────┘          └──────────────┐
           │                                       │
           │ (1:many)                     (1:many) │
           │                                       │
    ┌──────▼─────────────┐            ┌───────────▼──────────┐
    │ pwb_sale_listings  │            │pwb_rental_listings   │
    │ (Sales Data)       │            │ (Rental Data)        │
    │ id: uuid (PK)      │            │ id: uuid (PK)        │
    │ realty_asset_id▲   │            │ realty_asset_id▲     │
    │                │   │            │               │      │
    │ Constraint:    │   │            │ Constraint:   │      │
    │ UNIQUE         │   │            │ UNIQUE        │      │
    │ (realty_asset_ │   │            │ (realty_asset_│      │
    │  id, active)   │   │            │  id, active)  │      │
    │ WHERE active=1 │   │            │ WHERE active=1│      │
    │                │   │            │               │      │
    │ Fields:        │   │            │ Fields:       │      │
    │ • active ◄─────┘   │            │ • active ◄────┘      │
    │ • archived         │            │ • archived           │
    │ • visible          │            │ • visible            │
    │ • highlighted      │            │ • highlighted        │
    │ • furnished        │            │ • furnished          │
    │ • reserved         │            │ • reserved           │
    │ • noindex          │            │ • for_rent_long_term │
    │ • price_sale_*     │            │ • for_rent_short_tm  │
    │ • commission_*     │            │ • price_rental_*     │
    │ • reference        │            │ • reference          │
    │ • title_* (i18n)   │            │ • title_* (i18n)     │
    │ • description_*    │            │ • description_*      │
    │ • seo_title_*      │            │ • seo_title_*        │
    │ • meta_desc_*      │            │ • meta_desc_*        │
    │ • translations     │            │ • translations       │
    │ • created_at       │            │ • created_at         │
    └────────────────────┘            └──────────────────────┘

           ┌──────────────────────────────────────────────┐
           │                                              │
           │ (1:many) - Both models can be               │
           │           associated with same asset        │
           │                                              │
           └──────────────────────────────────────────────┘


    ┌──────────────────────┐         ┌──────────────────────┐
    │  pwb_prop_photos     │         │   pwb_features       │
    │  (Property Images)   │         │  (Amenities)         │
    │ id: int (PK)         │         │ id: int (PK)         │
    │ realty_asset_id▲─────┤         │ realty_asset_id▲─────┤
    │ prop_id (legacy)     │         │ prop_id (legacy)     │
    │                      │         │                      │
    │ Fields:              │         │ Fields:              │
    │ • image (binary)     │         │ • feature_key        │
    │ • external_url       │         │ • created_at         │
    │ • description        │         └──────────────────────┘
    │ • sort_order         │                    │
    │ • file_size          │                    │ (FK via feature_key)
    │ • folder             │                    │
    │ • created_at         │         ┌──────────▼──────────┐
    └──────────────────────┘         │  pwb_field_keys     │
                                     │  (Feature Config)   │
                                     │ global_key: string  │
                                     │ (PK, e.g. "prop..") │
                                     │ category            │
                                     │ tag                 │
                                     │ visible             │
                                     │ translations        │
                                     └─────────────────────┘


    ┌──────────────────────────────────────────────────────┐
    │         pwb_properties (MATERIALIZED VIEW)           │
    │    (Read-Only, Denormalized Property Data)           │
    │                                                      │
    │  This is a database view combining:                  │
    │  - All RealtyAsset fields                            │
    │  - SaleListing data (if exists)                      │
    │  - RentalListing data (if exists)                    │
    │  - sale_listing_id, rental_listing_id (FKs)         │
    │  - for_sale, for_rent (booleans)                    │
    │  - Combined price, visible, highlighted fields      │
    │                                                      │
    │  Used by:                                            │
    │  - ListedProperty model (read-only)                  │
    │  - Property searches and listings                    │
    │  - Performance optimized queries                     │
    │                                                      │
    └──────────────────────────────────────────────────────┘
```

---

## Data Flow Diagrams

### Create Property Flow (Normalized Write)

```
User Input (Form or Bulk Import)
    ↓
    ├─────────────────────────────────────────┐
    │ ActiveRecord::Base.transaction DO      │
    │                                         │
    │  1. Create RealtyAsset                  │
    │     └─> auto-generate slug             │
    │     └─> geocode if address present     │
    │     └─> validate subscription limit    │
    │                                         │
    │  2. Create SaleListing (optional)       │
    │     └─> realty_asset_id FK             │
    │     └─> if for_sale? → price required  │
    │     └─> UNIQUE(realty_asset_id, active)│
    │                                         │
    │  3. Create RentalListing (optional)     │
    │     └─> realty_asset_id FK             │
    │     └─> if for_rent? → price required  │
    │     └─> UNIQUE(realty_asset_id, active)│
    │                                         │
    │  4. Create Features (array)             │
    │     └─> realty_asset_id FK             │
    │     └─> feature_key → FieldKey lookup  │
    │                                         │
    │  5. Create/Attach PropPhotos (array)    │
    │     └─> realty_asset_id FK             │
    │     └─> download from URL if needed    │
    │     └─> attach via ActiveStorage       │
    │     └─> sort_order for ordering        │
    │                                         │
    └─────────────────────────────────────────┘
    ↓
    After commit hook triggers:
    └─> Pwb::ListedProperty.refresh
    └─> Updates materialized view (pwb_properties)
    ↓
    Property now visible in search/listings
```

### Read Property Flow

```
Query for listings:
    ↓
    Use Pwb::ListedProperty.where(website_id: x)
    ├─> SQL: SELECT * FROM pwb_properties WHERE website_id = x
    ├─> Returns fast (pre-joined, indexed)
    └─> Includes all sale + rental data in one row
    ↓
    Query for editing:
    ├─> Load Pwb::ListedProperty.find(id)    [read-only view]
    ├─> Get .realty_asset                     [writable model]
    ├─> Get .sale_listing (if exists)         [writable model]
    ├─> Get .rental_listing (if exists)       [writable model]
    └─> Use these for updates/writes
```

### Update Property Flow

```
User edits property:
    ↓
    ├─────────────────────────────────────────┐
    │ ActiveRecord::Base.transaction DO      │
    │                                         │
    │  1. Update RealtyAsset                  │
    │     └─> physical data (address, beds)  │
    │                                         │
    │  2. Update SaleListing (first/init)     │
    │     └─> price, title, description      │
    │                                         │
    │  3. Update RentalListing (first/init)   │
    │     └─> seasonal prices, rental type   │
    │                                         │
    │  4. Sync Features                       │
    │     └─> delete unselected features     │
    │     └─> create new selected features   │
    │                                         │
    │  5. Handle photos                       │
    │     └─> add new photos                 │
    │     └─> remove deleted photos          │
    │     └─> reorder sort_order             │
    │                                         │
    └─────────────────────────────────────────┘
    ↓
    After commit hook triggers:
    └─> Pwb::ListedProperty.refresh
    └─> Updates materialized view immediately
    ↓
    Changes visible in search/listings
```

---

## Multi-Tenancy Scoping

```
Website (pwb_websites, tenant identifier)
    │
    ├─> has_many RealtyAsset
    │   ├─> website_id column (FK)
    │   └─> Always filter by current_website.id
    │
    ├─> has_many SaleListing (through realty_asset)
    │   ├─> inherits website via realty_asset
    │   └─> Never has direct website_id
    │
    ├─> has_many RentalListing (through realty_asset)
    │   ├─> inherits website via realty_asset
    │   └─> Never has direct website_id
    │
    ├─> has_many PropPhoto (through realty_asset)
    │   ├─> inherits website via realty_asset
    │   └─> Never has direct website_id
    │
    └─> has_many Feature (through realty_asset)
        ├─> inherits website via realty_asset
        └─> Never has direct website_id


Security Pattern:
    Every query MUST include website_id filter:
    
    RealtyAsset.where(website_id: current_website.id)
    Pwb::ListedProperty.where(website_id: current_website.id)
    
    This prevents cross-tenant data leakage.
```

---

## Listing Uniqueness Constraints

```
For each RealtyAsset, maximum one active listing per type:

RealtyAsset ID: abc-123
    │
    ├─> SaleListing (active=true)  ◄─── ONLY ONE
    │   ├─> SaleListing (archived)
    │   ├─> SaleListing (archived)
    │   └─> SaleListing (archived)
    │
    ├─> RentalListing (active=true) ◄─── ONLY ONE
    │   ├─> RentalListing (archived)
    │   └─> RentalListing (archived)
    │
    └─> Can be for sale AND for rent simultaneously
        (both active listings at same time)

Database Constraints:
    UNIQUE (realty_asset_id, active) WHERE active = true
    
    Applied separately to:
    - pwb_sale_listings
    - pwb_rental_listings

This allows:
✓ Property listed for both sale and rent
✓ Multiple historical listings (archived)
✗ Two active sale listings for same property
✗ Two active rental listings for same property
```

---

## Internationalization (i18n) Structure

```
RealtyAsset
    └─> translations (JSONB column)
        └─ Stores {locale: {field: value}}
        └─ e.g., {"en-UK": {"title": "Nice House"}}
        └─ Accessed via Mobility gem
           └─ asset.title                → reads from current locale
           └─ asset.title_en             → reads from :en-UK
           └─ asset.title_es             → reads from :es

SaleListing
    └─> translations (JSONB column)
        ├─ title_en, title_es, title_it, etc.
        ├─ description_en, description_es, etc.
        ├─ seo_title_en, seo_title_es, etc.
        └─ meta_description_en, etc.

RentalListing
    └─> translations (JSONB column)
        ├─ title_en, title_es, title_it, etc.
        ├─ description_en, description_es, etc.
        ├─ seo_title_en, seo_title_es, etc.
        └─ meta_description_en, etc.

Feature
    └─> no direct translations
    └─> translations via FieldKey model
        └─ FieldKey.feature_pool
           ├─ i18n key: "property.feature.pool"
           └─ translated in locale files
```

---

## Database Table Structures

### pwb_realty_assets

```sql
CREATE TABLE pwb_realty_assets (
  id uuid NOT NULL PRIMARY KEY,
  website_id integer,
  reference varchar,
  slug varchar UNIQUE NOT NULL,
  
  -- Location
  street_number varchar,
  street_name varchar,
  street_address varchar,
  city varchar,
  region varchar,
  postal_code varchar,
  country varchar,
  latitude float,
  longitude float,
  
  -- Dimensions
  count_bedrooms integer DEFAULT 0,
  count_bathrooms float DEFAULT 0.0,
  count_garages integer DEFAULT 0,
  count_toilets integer DEFAULT 0,
  constructed_area float DEFAULT 0.0,
  plot_area float DEFAULT 0.0,
  year_construction integer DEFAULT 0,
  
  -- Energy
  energy_rating integer,
  energy_performance float,
  
  -- Classification
  prop_type_key varchar,
  prop_state_key varchar,
  prop_origin_key varchar,
  
  -- Marketing (i18n)
  title text,
  description text,
  translations jsonb NOT NULL,
  
  -- Timestamps
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  
  -- Indexes
  UNIQUE (slug),
  INDEX (website_id),
  INDEX (prop_type_key),
  INDEX (prop_state_key),
  INDEX (translations) USING GIN,
  INDEX (website_id, prop_type_key)
);
```

### pwb_sale_listings

```sql
CREATE TABLE pwb_sale_listings (
  id uuid NOT NULL PRIMARY KEY,
  realty_asset_id uuid NOT NULL REFERENCES pwb_realty_assets(id),
  
  -- Pricing
  price_sale_current_cents bigint DEFAULT 0,
  price_sale_current_currency varchar DEFAULT 'EUR',
  commission_cents bigint DEFAULT 0,
  commission_currency varchar DEFAULT 'EUR',
  
  -- Status
  active boolean DEFAULT false NOT NULL,
  archived boolean DEFAULT false,
  visible boolean DEFAULT false,
  highlighted boolean DEFAULT false,
  reserved boolean DEFAULT false,
  furnished boolean DEFAULT false,
  noindex boolean DEFAULT false NOT NULL,
  
  -- Marketing (i18n)
  reference varchar,
  translations jsonb NOT NULL,
  
  -- Timestamps
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  
  -- Constraints
  UNIQUE (realty_asset_id, active) WHERE active = true,
  
  -- Indexes
  INDEX (realty_asset_id),
  INDEX (active),
  INDEX (translations) USING GIN,
  INDEX (noindex)
);
```

### pwb_rental_listings

```sql
CREATE TABLE pwb_rental_listings (
  id uuid NOT NULL PRIMARY KEY,
  realty_asset_id uuid NOT NULL REFERENCES pwb_realty_assets(id),
  
  -- Pricing (3 seasonal tiers)
  price_rental_monthly_current_cents bigint DEFAULT 0,
  price_rental_monthly_current_currency varchar DEFAULT 'EUR',
  price_rental_monthly_low_season_cents bigint DEFAULT 0,
  price_rental_monthly_high_season_cents bigint DEFAULT 0,
  
  -- Rental Type
  for_rent_short_term boolean DEFAULT false,
  for_rent_long_term boolean DEFAULT false,
  
  -- Status
  active boolean DEFAULT false NOT NULL,
  archived boolean DEFAULT false,
  visible boolean DEFAULT false,
  highlighted boolean DEFAULT false,
  reserved boolean DEFAULT false,
  furnished boolean DEFAULT false,
  noindex boolean DEFAULT false NOT NULL,
  
  -- Marketing (i18n)
  reference varchar,
  translations jsonb NOT NULL,
  
  -- Timestamps
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  
  -- Constraints
  UNIQUE (realty_asset_id, active) WHERE active = true,
  
  -- Indexes
  INDEX (realty_asset_id),
  INDEX (active),
  INDEX (for_rent_short_term),
  INDEX (for_rent_long_term),
  INDEX (translations) USING GIN,
  INDEX (noindex)
);
```

### pwb_prop_photos

```sql
CREATE TABLE pwb_prop_photos (
  id integer NOT NULL PRIMARY KEY,
  realty_asset_id uuid REFERENCES pwb_realty_assets(id),
  prop_id integer,  -- Legacy
  
  -- Image Data
  image varchar,  -- ActiveStorage attachment key
  external_url varchar,
  
  -- Metadata
  description varchar,
  sort_order integer,
  file_size integer,
  folder varchar,
  
  -- Timestamps
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  
  -- Indexes
  INDEX (realty_asset_id),
  INDEX (prop_id),
  INDEX (sort_order)
);
```

### pwb_features

```sql
CREATE TABLE pwb_features (
  id integer NOT NULL PRIMARY KEY,
  realty_asset_id uuid REFERENCES pwb_realty_assets(id),
  prop_id integer,  -- Legacy
  
  -- Feature Reference
  feature_key varchar,
  
  -- Timestamps
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL,
  
  -- Indexes
  INDEX (realty_asset_id),
  INDEX (prop_id),
  INDEX (feature_key),
  UNIQUE (realty_asset_id, feature_key)
);
```

### pwb_properties (Materialized View)

```sql
CREATE MATERIALIZED VIEW pwb_properties AS
  SELECT
    ra.id,
    ra.website_id,
    ra.reference,
    ra.slug,
    -- Address
    ra.street_number, ra.street_name, ra.street_address,
    ra.city, ra.region, ra.postal_code, ra.country,
    ra.latitude, ra.longitude,
    -- Dimensions
    ra.count_bedrooms, ra.count_bathrooms, ra.count_garages, ra.count_toilets,
    ra.constructed_area, ra.plot_area, ra.year_construction,
    -- Energy
    ra.energy_rating, ra.energy_performance,
    -- Classification
    ra.prop_type_key, ra.prop_state_key, ra.prop_origin_key,
    -- Sales
    COALESCE(sl.id, NULL::uuid) as sale_listing_id,
    sl.visible as sale_visible,
    sl.highlighted as sale_highlighted,
    sl.reserved as sale_reserved,
    sl.furnished as sale_furnished,
    sl.price_sale_current_cents,
    sl.price_sale_current_currency,
    (sl.id IS NOT NULL) as for_sale,
    -- Rentals
    COALESCE(rl.id, NULL::uuid) as rental_listing_id,
    rl.visible as rental_visible,
    rl.highlighted as rental_highlighted,
    rl.reserved as rental_reserved,
    rl.furnished as rental_furnished,
    rl.for_rent_short_term,
    rl.for_rent_long_term,
    rl.price_rental_monthly_current_cents,
    rl.price_rental_monthly_current_currency,
    rl.price_rental_monthly_low_season_cents,
    rl.price_rental_monthly_high_season_cents,
    (rl.id IS NOT NULL) as for_rent,
    -- Combined fields
    COALESCE(sl.visible, rl.visible, false) as visible,
    COALESCE(sl.highlighted, rl.highlighted, false) as highlighted,
    COALESCE(sl.reserved, rl.reserved, false) as reserved,
    COALESCE(sl.furnished, rl.furnished) as furnished,
    
    ra.created_at, ra.updated_at
  FROM pwb_realty_assets ra
  LEFT JOIN pwb_sale_listings sl ON ra.id = sl.realty_asset_id AND sl.active = true
  LEFT JOIN pwb_rental_listings rl ON ra.id = rl.realty_asset_id AND rl.active = true;

-- Indexes on materialized view
CREATE UNIQUE INDEX idx_pwb_properties_id ON pwb_properties(id);
CREATE INDEX idx_pwb_properties_website_id ON pwb_properties(website_id);
CREATE INDEX idx_pwb_properties_slug ON pwb_properties(slug);
CREATE INDEX idx_pwb_properties_for_sale ON pwb_properties(for_sale);
CREATE INDEX idx_pwb_properties_for_rent ON pwb_properties(for_rent);
CREATE INDEX idx_pwb_properties_visible ON pwb_properties(visible);
CREATE INDEX idx_pwb_properties_price_sale ON pwb_properties(price_sale_current_cents);
CREATE INDEX idx_pwb_properties_price_rent ON pwb_properties(price_rental_monthly_current_cents);
CREATE INDEX idx_pwb_properties_bedrooms ON pwb_properties(count_bedrooms);
CREATE INDEX idx_pwb_properties_bathrooms ON pwb_properties(count_bathrooms);
CREATE INDEX idx_pwb_properties_lat_lng ON pwb_properties(latitude, longitude);
```

---

## Import Data Structure (api_pwb.json)

```
Input CSV/JSON Columns        →  Target Model      →  Database Field
─────────────────────────────────────────────────────────────────────
reference                     →  RealtyAsset       →  reference
price-sale-current-cents      →  SaleListing       →  price_sale_current_cents
price-rental-monthly-current  →  RentalListing     →  price_rental_monthly_current_cents
price-rental-monthly-low-s.   →  RentalListing     →  price_rental_monthly_low_season_cents
price-rental-monthly-high-s.  →  RentalListing     →  price_rental_monthly_high_season_cents
commission-cents              →  SaleListing       →  commission_cents
title-en                      →  SaleListing       →  translations->>'en'->>'title'
title-es                      →  SaleListing       →  translations->>'es'->>'title'
description-en                →  SaleListing       →  translations->>'en'->>'description'
constructed-area              →  RealtyAsset       →  constructed_area
count-bedrooms                →  RealtyAsset       →  count_bedrooms
count-bathrooms               →  RealtyAsset       →  count_bathrooms
count-garages                 →  RealtyAsset       →  count_garages
count-toilets                 →  RealtyAsset       →  count_toilets
street-number                 →  RealtyAsset       →  street_number
street-address                →  RealtyAsset       →  street_address
city                          →  RealtyAsset       →  city
region                        →  RealtyAsset       →  region
postal-code                   →  RealtyAsset       →  postal_code
country                       →  RealtyAsset       →  country
latitude                      →  RealtyAsset       →  latitude
longitude                     →  RealtyAsset       →  longitude
year-construction             →  RealtyAsset       →  year_construction
energy-rating                 →  RealtyAsset       →  energy_rating
energy-performance            →  RealtyAsset       →  energy_performance
prop-type-key                 →  RealtyAsset       →  prop_type_key
prop-state-key                →  RealtyAsset       →  prop_state_key
prop-origin-key               →  RealtyAsset       →  prop_origin_key
for-sale                      →  SaleListing       →  [create if true]
for-rent-long-term            →  RentalListing     →  for_rent_long_term
for-rent-short-term           →  RentalListing     →  for_rent_short_term
visible                       →  Both Listings     →  visible
highlighted                   →  Both Listings     →  highlighted
reserved                      →  Both Listings     →  reserved
furnished                     →  Both Listings     →  furnished
property-photos (urls array)  →  PropPhoto         →  [create + download]
extras (feature keys array)   →  Feature           →  [create entries]
area-unit                     →  Website default   →  [uses website setting]
currency                      →  Website default   →  [uses website setting]
```

---

## Key Validation Points

```
On Property Create/Update:

✓ slug: must be unique across entire system
✓ website_id: must be present (tenant scoping)
✓ subscription_limit: website.property_limit check
✓ address: optional but triggers geocoding if present
✓ reference: optional external ID
✓ translations: required (JSONB, at minimum empty {})
✓ sale_listings: price required if for_sale
✓ rental_listings: price required if for_rent_*
✓ only one active SaleListing per asset
✓ only one active RentalListing per asset
✓ features: feature_key must exist in FieldKey system
✓ prop_photos: sort_order must be sequential
✓ images: must be valid ActiveStorage or external URL
```

---

## Summary of Key Relationships

| Relationship | From | To | Cardinality | Key Field |
|--------------|------|-----|--------------|-----------|
| Tenant Scoping | Website | RealtyAsset | 1:many | website_id |
| Physical Property | RealtyAsset | SaleListing | 1:many | realty_asset_id |
| Physical Property | RealtyAsset | RentalListing | 1:many | realty_asset_id |
| Physical Property | RealtyAsset | PropPhoto | 1:many | realty_asset_id |
| Physical Property | RealtyAsset | Feature | 1:many | realty_asset_id |
| Feature Reference | Feature | FieldKey | many:1 | feature_key (PK) |
| View Composition | ListedProperty | RealtyAsset | 1:1 (view) | id |
| View Composition | ListedProperty | SaleListing | 1:0..1 | sale_listing_id |
| View Composition | ListedProperty | RentalListing | 1:0..1 | rental_listing_id |

---

This comprehensive schema documentation should serve as a complete reference for implementing bulk import/export functionality.
