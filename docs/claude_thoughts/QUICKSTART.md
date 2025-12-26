# PropertyWebBuilder Property Model - Quick Start Guide

## 30-Second Summary

PropertyWebBuilder has a **normalized 3-model property architecture**:

1. **RealtyAsset** - The physical property (bedrooms, address, energy rating)
2. **SaleListing** - Sale transaction (price, visibility, title)
3. **RentalListing** - Rental transaction (seasonal prices, rental type)
4. **ListedProperty** - Read-only view combining all three for fast searches

Plus: **PropPhoto** (images) and **Feature** (amenities)

---

## Essential File Paths

| What | Path | Key Info |
|------|------|----------|
| Property Core | `/app/models/pwb/realty_asset.rb` | 277 lines, UUID PK, website_scoped |
| Sale Data | `/app/models/pwb/sale_listing.rb` | 71 lines, belongs_to RealtyAsset |
| Rental Data | `/app/models/pwb/rental_listing.rb` | 83 lines, belongs_to RealtyAsset |
| Images | `/app/models/pwb/prop_photo.rb` | 40 lines, ActiveStorage + external URLs |
| Amenities | `/app/models/pwb/feature.rb` | 44 lines, keyed by feature_key |
| Search View | `/app/models/pwb/listed_property.rb` | 243 lines, read-only, materialized |
| Import Parser | `/app/services/pwb/import_properties.rb` | 51 lines, INCOMPLETE |
| Field Mapper | `/app/services/pwb/import_mapper.rb` | 51 lines, JSON-based mapping |
| Controller | `/app/controllers/site_admin/props_controller.rb` | 280 lines, CRUD + photos |
| Config | `/config/import_mappings/api_pwb.json` | 162 lines, **USE THIS FOR BULK** |

---

## RealtyAsset Fields Cheat Sheet

```ruby
# Location
street_number, street_name, street_address
city, region, postal_code, country
latitude, longitude (auto-geocoded)
slug (auto-generated, unique)

# Size
count_bedrooms, count_bathrooms
count_garages, count_toilets
constructed_area, plot_area
year_construction

# Classification
prop_type_key        # "property.type.apartment"
prop_state_key       # "property.state.active"
prop_origin_key      # data source
reference            # external ID

# Marketing
title, description (JSONB i18n)
translations (raw JSONB)

# Multi-tenancy
website_id (FK)

# Metadata
created_at, updated_at
```

---

## Create Property Example

```ruby
# Atomic creation with transaction
ActiveRecord::Base.transaction do
  # 1. Create physical property
  asset = Pwb::RealtyAsset.create!(
    website_id: website.id,
    reference: 'EXT-123',
    street_address: '123 Main St',
    city: 'London',
    postal_code: 'SW1A 1AA',
    country: 'UK',
    count_bedrooms: 2,
    count_bathrooms: 1.5,
    constructed_area: 85.0,
    prop_type_key: 'property.type.apartment'
  )
  
  # 2. Create sale listing (optional)
  Pwb::SaleListing.create!(
    realty_asset: asset,
    price_sale_current_cents: 50000000,  # £500,000 in cents
    price_sale_current_currency: 'GBP',
    visible: true,
    title_en: 'Beautiful Apartment',
    description_en: 'Great location...'
  )
  
  # 3. Create rental listing (optional)
  Pwb::RentalListing.create!(
    realty_asset: asset,
    price_rental_monthly_current_cents: 150000,  # £1,500
    price_rental_monthly_current_currency: 'GBP',
    for_rent_long_term: true,
    visible: true,
    title_en: 'Monthly Rental',
    description_en: 'Available now...'
  )
  
  # 4. Add features/amenities
  asset.features.create!(feature_key: 'property.feature.pool')
  asset.features.create!(feature_key: 'property.feature.garden')
  
  # 5. Attach photos
  photo = asset.prop_photos.build(sort_order: 1)
  photo.image.attach(io: File.open('photo.jpg'), filename: 'photo.jpg')
  photo.save!
end

# 6. Refresh materialized view for search
Pwb::ListedProperty.refresh
```

---

## Read Property Example

```ruby
# For listing/search (optimized read-only view)
properties = Pwb::ListedProperty
  .where(website_id: website.id)
  .where(for_sale: true)
  .where('price_sale_current_cents > ?', 100000000)
  .order(created_at: :desc)

# For single property details
property = Pwb::ListedProperty.find(id)

# Access underlying writable models
realty_asset = property.realty_asset
sale_listing = property.sale_listing    # if exists
rental_listing = property.rental_listing # if exists
photos = property.prop_photos
features = property.features
```

---

## Update Property Example

```ruby
ActiveRecord::Base.transaction do
  asset = Pwb::RealtyAsset.find(id)
  
  # Update physical property
  asset.update!(
    count_bedrooms: 3,
    constructed_area: 100.0
  )
  
  # Update sale listing
  sale = asset.sale_listings.first_or_initialize
  sale.update!(
    price_sale_current_cents: 55000000,
    title_en: 'Updated Title'
  )
  
  # Sync features
  selected = ['property.feature.pool', 'property.feature.garage']
  asset.features.where.not(feature_key: selected).destroy_all
  selected.each do |key|
    asset.features.find_or_create_by(feature_key: key)
  end
end

Pwb::ListedProperty.refresh
```

---

## Import Mapping Structure

```json
{
  "name": "api_pwb",
  "mappings": {
    "reference": {
      "fieldName": "reference",
      "default": null
    },
    "price-sale-current-cents": {
      "fieldName": "price_sale_current_cents",
      "default": 0
    },
    "title-en": {
      "fieldName": "title_en",
      "default": ""
    },
    "for-sale": {
      "fieldName": "for_sale",
      "default": false
    },
    "property-photos": {
      "fieldName": "property_photos",
      "default": []
    }
  }
}
```

**Usage:**
```ruby
mapper = Pwb::ImportMapper.new("api_pwb")
mapped = mapper.map_property(csv_row)
```

---

## Key Constraints & Rules

| Constraint | Details |
|-----------|---------|
| **Slug Uniqueness** | Must be unique across entire system; auto-generated from address/reference |
| **Active Listing** | Only 1 SaleListing can have active=true per RealtyAsset (unique constraint) |
| **Active Rental** | Only 1 RentalListing can have active=true per RealtyAsset (unique constraint) |
| **Website Scoping** | RealtyAsset.website_id required; all queries filtered by website_id |
| **Subscription Limit** | website.can_add_property? must pass before creating |
| **Materialized View** | Must call Pwb::ListedProperty.refresh after bulk creates |
| **Both Sale & Rent** | Same property can have both active SaleListing AND RentalListing |
| **Feature Keys** | Must exist in FieldKey system; use feature_key lookup |
| **Translations** | SaleListing/RentalListing use Mobility; access via title_en, description_es, etc. |

---

## Common Operations Cheat Sheet

```ruby
# Check if property visible
property.for_sale?
property.for_rent?
property.visible?

# Get price
property.price  # Returns formatted price string

# Get features
property.get_features  # Returns {feature_key => true} hash

# Get photos
property.prop_photos  # Ordered by sort_order
property.ordered_photo(1)  # Get first photo
property.primary_image_url  # URL to first photo

# Get location
property.location  # Formatted address string
property.geocodeable_address  # For geocoding

# Get dimensions
property.bedrooms, property.bathrooms, property.surface_area

# Get convenience delegates (from listing)
property.title, property.description
property.reference
property.street_address, property.city
```

---

## Bulk Import Checklist

To implement bulk import, you'll need:

- [ ] Extend ImportProperties service to CREATE properties (not just parse)
- [ ] Handle RealtyAsset + SaleListing/RentalListing creation atomically
- [ ] Download images from URLs and attach via ActiveStorage
- [ ] Create Features from extras array
- [ ] Handle multi-locale translations (title_en, description_es, etc.)
- [ ] Validate subscription limits (website.can_add_property?)
- [ ] Call Pwb::ListedProperty.refresh after bulk create
- [ ] Handle errors gracefully with detailed logging
- [ ] Create async job for large imports (Sidekiq/SolidQueue)
- [ ] Provide progress tracking and user notifications

---

## Bulk Export Checklist

To implement bulk export, you'll need:

- [ ] Create BulkExporter service
- [ ] Serialize RealtyAsset + Listings + Features + Photos
- [ ] Support CSV format (minimum)
- [ ] Support JSON format (optional)
- [ ] Handle multi-locale fields (title_en, description_es, etc.)
- [ ] Include filtering options (date range, type, status)
- [ ] Generate downloadable file
- [ ] Handle large exports efficiently

---

## Related Models to Know

| Model | Purpose | Scoping |
|-------|---------|---------|
| Website | Multi-tenant anchor | parent |
| FieldKey | Feature/amenity definitions | global, i18n |
| ListedProperty | Materialized view (optimized read) | website_id |
| PropPhoto | Images (ActiveStorage + external URLs) | through RealtyAsset |
| Feature | Amenities (linked by feature_key) | through RealtyAsset |

---

## Important Gem Dependencies

```ruby
# In Gemfile (already included):
gem 'mobility'  # i18n translations
gem 'monetize'  # Currency/price handling
gem 'scenic'    # Materialized views
gem 'active_hash'  # Static data (ImportSource)
gem 'active_json'  # JSON-based config (ImportMapping)
gem 'sidekiq'   # (if using async jobs)
```

---

## Code Examples Location

For more detailed examples, see:
- `/docs/claude_thoughts/property_model_analysis.md` - Complete analysis
- `/docs/claude_thoughts/property_files_reference.md` - File reference
- `/docs/claude_thoughts/property_schema_diagram.md` - Database schema
- `/app/controllers/site_admin/props_controller.rb` - Real controller code
- `/app/models/pwb/realty_asset.rb` - Complete model implementation

---

## Quick Debugging Tips

```ruby
# Inspect a property
property = Pwb::ListedProperty.find(id)
property.attributes

# Check relationships
property.realty_asset.sale_listings
property.realty_asset.rental_listings
property.realty_asset.features

# Verify materialized view
Pwb::ListedProperty.refresh
Pwb::ListedProperty.count

# Check subscriptions
website.can_add_property?
website.property_limit
Pwb::RealtyAsset.where(website_id: website.id).count

# Validate translations
sale_listing.title_en
sale_listing.description_es
sale_listing.translations
```

---

## Where to Start

1. **For Understanding:** Read `property_model_analysis.md` (20 min read)
2. **For Implementation:** Reference `property_files_reference.md` and code files
3. **For Schema:** Check `property_schema_diagram.md` for database details
4. **For Coding:** Use `/app/controllers/site_admin/props_controller.rb` as reference for patterns

---

## Need Help?

- Model structure → property_model_analysis.md
- File locations → property_files_reference.md  
- Database schema → property_schema_diagram.md
- Code patterns → props_controller.rb
- All of above → SUMMARY.md
