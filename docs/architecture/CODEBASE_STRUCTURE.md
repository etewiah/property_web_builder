# PropertyWebBuilder Codebase Structure Overview

## Executive Summary

PropertyWebBuilder is a multi-tenant real estate property listing platform built on Rails 8. It manages websites where each website is a tenant. The architecture uses a modern normalized schema for properties, with separate models for the physical asset and transaction types (sales/rentals), plus a materialized view for optimized queries.

---

## 1. Property Model Structure

### Core Property Models (Normalized Schema)

The application uses a **three-tier property model**:

#### 1.1 **Pwb::RealtyAsset** (Physical Property)
**Table**: `pwb_realty_assets` (UUID primary key)

Represents the **physical property itself** - the building/land that never changes.

**Key Attributes**:
- Location: `street_address`, `street_number`, `street_name`, `city`, `region`, `postal_code`, `country`
- Dimensions: `constructed_area`, `plot_area`, `year_construction`
- Rooms: `count_bedrooms`, `count_bathrooms`, `count_toilets`, `count_garages`
- Energy: `energy_rating`, `energy_performance`
- Identifiers: `reference`, `slug`, `prop_type_key`, `prop_state_key`, `prop_origin_key`
- Location data: `latitude`, `longitude`
- Marketing: `title`, `description` (translatable via JSONB `translations` column)
- Relations: `website_id` (tenant scoping)

**Associations**:
```ruby
has_many :sale_listings      # One property can have multiple sale listings over time
has_many :rental_listings    # One property can have multiple rental listings over time
has_many :prop_photos        # Images of the property
has_many :features           # Property amenities (pool, garden, etc.)
belongs_to :website          # Tenant scoping
```

#### 1.2 **Pwb::SaleListing** (Sale Transaction)
**Table**: `pwb_sale_listings` (UUID primary key)

Represents a **sale transaction** for a property - marketing text and pricing specific to a sale.

**Key Attributes**:
- Marketing: `title`, `description` (translatable)
- Pricing: `price_sale_current_cents`, `price_sale_current_currency`
- Commission: `commission_cents`, `commission_currency`
- Status: `visible`, `active`, `reserved`, `archived`, `furnished`, `highlighted`
- SEO: `seo_title`, `meta_description` (translatable)
- Control: `noindex` (search engine visibility)

**Important**: Only **one active sale listing per property** (enforced via unique constraint on `realty_asset_id, active WHERE active=true`)

**Associations**:
```ruby
belongs_to :realty_asset
monetize :price_sale_current_cents
translates :title, :description, :seo_title, :meta_description
delegates: reference, website, count_bedrooms, count_bathrooms, street_address, city, prop_photos, features
```

#### 1.3 **Pwb::RentalListing** (Rental Transaction)
**Table**: `pwb_rental_listings` (UUID primary key)

Represents a **rental transaction** for a property - marketing text and pricing specific to a rental.

**Key Attributes**:
- Marketing: `title`, `description` (translatable)
- Rental Type: `for_rent_short_term`, `for_rent_long_term`
- Pricing: `price_rental_monthly_current_cents`, `price_rental_monthly_low_season_cents`, `price_rental_monthly_high_season_cents`
- Currency: `price_rental_monthly_current_currency`
- Status: `visible`, `active`, `reserved`, `archived`, `furnished`, `highlighted`
- SEO: `seo_title`, `meta_description` (translatable)
- Control: `noindex`

**Important**: Only **one active rental listing per property** (same unique constraint pattern)

**Associations**:
```ruby
belongs_to :realty_asset
monetize :price_rental_monthly_current_cents
translates :title, :description, :seo_title, :meta_description
delegates: reference, website, count_bedrooms, count_bathrooms, street_address, city, prop_photos, features
```

#### 1.4 **Pwb::ListedProperty** (Read-Only Materialized View)
**Table**: `pwb_properties` (materialized view, UUID primary key)

A **denormalized, query-optimized view** combining realty_asset + active listings data.

**Purpose**: Provides a single queryable interface for property search and display without JOINs.

**Key Attributes** (from the view):
- All realty_asset fields
- Sale listing fields: `for_sale`, `sale_listing_id`, `price_sale_current_cents`, `sale_reserved`, `sale_furnished`, `sale_highlighted`, `commission_cents`
- Rental listing fields: `for_rent`, `rental_listing_id`, `for_rent_short_term`, `for_rent_long_term`, `price_rental_monthly_current_cents`, `rental_reserved`, `rental_furnished`, `rental_highlighted`
- Computed fields: `visible` (either listing visible), `highlighted`, `reserved`, `furnished`, `currency`

**Important**: Read-only! For writes, use RealtyAsset, SaleListing, or RentalListing directly, then call `Pwb::ListedProperty.refresh` to update the view.

**Refresh Methods**:
```ruby
Pwb::ListedProperty.refresh                    # Refresh concurrently (allows reads)
Pwb::ListedProperty.refresh(concurrently: false)  # Refresh exclusively
Pwb::ListedProperty.refresh_async              # Async refresh if RefreshPropertiesViewJob available
```

---

### Legacy Property Model (Pwb::Prop)

Still exists for backwards compatibility but being phased out in favor of the normalized schema. Located in `pwb_props` table.

**Warning**: Do not extend this model. Use RealtyAsset + SaleListing + RentalListing instead.

---

## 2. Property Photos & Media

### 2.1 **Pwb::PropPhoto**
**Table**: `pwb_prop_photos`

**Purpose**: Images attached to properties

**Key Attributes**:
- `image` (ActiveStorage attachment with `has_one_attached :image`)
- `sort_order` (display order)
- `description`, `external_url`, `file_size`, `folder`

**Associations**:
```ruby
belongs_to :realty_asset    # or :prop (legacy)
belongs_to :prop            # backwards compat
has_one_attached :image     # ActiveStorage
```

**External Image Support**:
- If website has `external_image_mode: true`, images can use `external_url` instead of attachments
- Useful for syncing external property listings

### 2.2 **Pwb::ContentPhoto**
**Table**: `pwb_content_photos`

**Purpose**: Images in page content blocks (hero images, section images, etc.)

**Key Attributes**:
- `image` (ActiveStorage attachment)
- `block_key` (which content block)
- `description`, `external_url`

**Methods**:
```ruby
def optimized_image_url        # Uses variants for CDN/R2
def image_filename             # Extracts from URL or ActiveStorage
def external_image_mode?       # Checks website setting
```

### 2.3 **Pwb::Media** (Media Library)
**Table**: `pwb_media`

**Purpose**: Centralized media library for managing all files (images, documents, PDFs)

**Key Attributes**:
- `filename`, `content_type`, `byte_size`, `checksum`
- `width`, `height` (for images)
- `title`, `alt_text`, `caption`, `description`
- `tags` (array), `source_type`, `source_url`
- `folder_id` (hierarchical folders)
- `usage_count`, `last_used_at`

**ActiveStorage**:
```ruby
has_one_attached :file        # The actual file
```

**Scopes**:
```ruby
Media.images                   # Filter by content type
Media.documents
Media.recent
Media.search(query)
Media.with_tag(tag)
```

**Variant URLs** (image only):
```ruby
media.url                      # Original file
media.variant_url(:thumb)      # 150x150
media.variant_url(:small)      # 300x300
media.variant_url(:medium)     # 600x600
media.variant_url(:large)      # 1200x1200
```

**File Handling**:
```ruby
Pwb::Media.allowed_content_types   # List of allowed MIME types
Pwb::Media.max_file_size           # 25 MB
media.within_size_limit?           # Validation
```

**Metadata Extraction**:
```ruby
before_validation :set_metadata_from_file   # Extracts filename, content_type, byte_size
after_commit :extract_dimensions            # Analyzes images for width/height
```

---

## 3. Features System

### **Pwb::Feature**
**Table**: `pwb_features`

**Purpose**: Property amenities/features (swimming pool, garden, garage, elevator, etc.)

**Key Attributes**:
- `feature_key` (translation key like "property.amenities.pool")
- `realty_asset_id` (which property)
- `prop_id` (legacy)

**Associations**:
```ruby
belongs_to :realty_asset
belongs_to :feature_field_key, 
  class_name: 'Pwb::FieldKey',
  foreign_key: :feature_key, 
  primary_key: :global_key
```

**Usage**:
```ruby
realty_asset.features           # All features for a property
realty_asset.get_features       # Hash { feature_key => true }
realty_asset.extras_for_display # Localized feature names for display

# Setting features
realty_asset.set_features = {
  "property.amenities.pool" => true,
  "property.amenities.garden" => false
}
```

---

## 4. Content Management System

### 4.1 **Pwb::Page**
**Table**: `pwb_pages`

**Purpose**: CMS pages like "About", "Contact", "Services"

**Key Attributes**:
- `slug` (URL slug, unique per website)
- `visible` (published/unpublished)
- `show_in_top_nav`, `show_in_footer` (navigation)
- `sort_order_top_nav`, `sort_order_footer`
- `seo_title`, `meta_description` (SEO)
- `details` (JSON for flexible extra data)
- `flags` (bitwise flags)

**Translatable** (via Mobility JSONB):
- `raw_html` (page content)
- `page_title` (browser tab title)
- `link_title` (navigation link text)

**Associations**:
```ruby
belongs_to :website
translates :raw_html, :page_title, :link_title
has_many :page_contents      # Join table
has_many :contents, through: :page_contents
has_many :page_parts         # Page building blocks
has_many :links              # Navigation links
```

### 4.2 **Pwb::Content**
**Table**: `pwb_contents`

**Purpose**: Reusable content blocks (hero text, testimonial, CTA section, etc.)

**Key Attributes**:
- `key` (unique identifier per website)
- `page_part_key` (which page section)
- `sort_order` (display order)
- `input_type`, `tag`, `section_key`, `target_url`, `status`

**Translatable** (via Mobility JSONB):
- `raw` (HTML content)

**Associations**:
```ruby
belongs_to :website
translates :raw
has_many :content_photos     # Images in this block
has_many :page_contents      # Join table
has_many :pages, through: :page_contents
```

**Photo Management**:
```ruby
def default_photo            # First photo
def default_photo_url        # URL or placeholder
```

### 4.3 **Pwb::PageContent** (Join Table)
**Table**: `pwb_page_contents`

**Purpose**: Links pages and content blocks with ordering and visibility

**Key Attributes**:
- `sort_order` (display order)
- `visible_on_page` (show/hide content)
- `page_part_key` (which section of page)
- `label` (admin label)
- `is_rails_part` (indicates if it's a Rails component vs custom content)

**Associations**:
```ruby
belongs_to :page
belongs_to :content
belongs_to :website
```

**Scopes**:
```ruby
ordered_visible   # WHERE visible_on_page = true ORDER BY sort_order
```

### 4.4 **Pwb::PagePart**
**Table**: `pwb_page_parts`

**Purpose**: Template definition for page sections

**Key Attributes**:
- `page_slug` (which page)
- `page_part_key` (section identifier)
- `template` (template code)
- `block_contents` (JSON block data)
- `editor_setup` (JSON editor config)
- `show_in_editor` (include in editor UI)
- `order_in_editor` (editor panel order)

---

## 5. Content Translations & i18n

### Configuration

**Mobility Setup** (`config/initializers/mobility.rb`):
```ruby
# Uses container backend - JSONB single column storage
translates :raw                    # Each model defines its translatable attributes
# Supported locales: en, es, de, fr, nl, pt, it
# Fallback chain: All fall back to English
```

### Pattern Used

Models using translations:
- **Pwb::RealtyAsset**: `title`, `description` (in `translations` JSONB column)
- **Pwb::SaleListing**: `title`, `description`, `seo_title`, `meta_description`
- **Pwb::RentalListing**: `title`, `description`, `seo_title`, `meta_description`
- **Pwb::Content**: `raw`
- **Pwb::Page**: `raw_html`, `page_title`, `link_title`
- **Pwb::FieldKey**: `label`
- **Pwb::Link**: `link_title`

**Accessing Translations**:
```ruby
# Direct access
realty_asset.title                    # Current locale
realty_asset.title = "New Title"      # Set current locale

# Locale-specific accessors (provided by Mobility)
realty_asset.title_en                 # English
realty_asset.title_es                 # Spanish
realty_asset.title_en = "English Title"

# Get all translations
realty_asset.translations             # { "en" => "...", "es" => "..." }
```

### **Pwb::FieldKey** (Field Translation Keys)
**Table**: `pwb_field_keys`

**Purpose**: Translation keys for dynamic fields (property types, property states, features)

**Key Attributes**:
- `global_key` (translation key identifier)
- `tag` (category: "property-types", "property-states", "features")
- `visible`, `show_in_search_form`
- `sort_order`, `props_count`

**Translatable**:
- `label` (localized display name)

**Unique Constraint**: Scoped to `pwb_website_id` and `global_key`

**Usage**:
```ruby
# Get dropdown options for search
Pwb::FieldKey.get_options_by_tag("property-types")
# Returns: [
#   OpenStruct.new(value: "property.types.apartment", label: "Apartment"),
#   OpenStruct.new(value: "property.types.house", label: "House"),
#   ...
# ]

# Display label
field_key.display_label              # Uses translated label or falls back to global_key
```

---

## 6. Enquiries & Contacts System

### **Pwb::Contact**
**Table**: `pwb_contacts`

**Purpose**: Represents a person/entity (leads, clients, agents)

**Key Attributes**:
- Personal: `first_name`, `last_name`, `other_names`, `title` (enum: mr, mrs)
- Contact: `primary_email`, `other_email`, `primary_phone_number`, `other_phone_number`, `fax`
- Identification: `documentation_type`, `documentation_id`
- Social: `twitter_id`, `facebook_id`, `linkedin_id`, `skype_id`
- Addresses: `primary_address_id`, `secondary_address_id`
- Details: `details` (JSON), `flags` (bitwise)

**Associations**:
```ruby
belongs_to :website
belongs_to :primary_address, class_name: 'Pwb::Address'
belongs_to :secondary_address, class_name: 'Pwb::Address'
belongs_to :user
has_many :messages
```

**Methods**:
```ruby
# Address delegation
contact.street_number          # Via primary_address
contact.street_address
contact.city
contact.postal_code
```

### **Pwb::Message**
**Table**: `pwb_messages`

**Purpose**: Enquiries/messages from website visitors

**Key Attributes**:
- `title`, `content` (enquiry text)
- `origin_email` (from visitor)
- `delivery_email` (where sent)
- `delivery_success`, `delivered_at`, `delivery_error`
- `origin_ip`, `user_agent` (visitor info)
- Location: `latitude`, `longitude`, `host`
- Context: `locale`, `url`

**Associations**:
```ruby
belongs_to :website
belongs_to :contact
belongs_to :client
```

---

## 7. Website Configuration

### **Pwb::Website** (Tenant Root)
**Table**: `pwb_websites`

**Purpose**: The tenant itself - represents one real estate website

**Key Attributes**:

**Identity**:
- `subdomain` (e.g., "mybrokerage")
- `custom_domain` (custom domain with verification)
- `slug` (internal identifier)

**Display**:
- `company_display_name` (shown to visitors)
- `main_logo_url`, `favicon_url`
- `theme_name` (which Tailwind theme)

**Localization**:
- `supported_locales` (array: ["en-UK", "es", ...])
- `default_client_locale` (frontend default)
- `default_admin_locale` (backend default)
- `default_currency`, `supported_currencies`
- `default_area_unit` (sqmt or sqft)

**Search & Pricing**:
- `search_config_buy`, `search_config_rent`, `search_config_landing` (JSON)
- `sale_price_options_from/till`, `rent_price_options_from/till` (price ranges for filters)

**Styling**:
- `selected_palette` (color theme)
- `style_variables_for_theme` (CSS variables)
- `raw_css` (custom CSS)
- `dark_mode_setting` (light_only, dark_only, auto)

**SEO & Content**:
- `default_seo_title`, `default_meta_description`
- `configuration` (JSON for page settings)
- `admin_config` (JSON for admin UI config)

**Contact**:
- `email_for_general_contact_form`
- `email_for_property_contact_form`
- `owner_email`, `contact_address_id`

**Integrations**:
- `maps_api_key`
- `recaptcha_key`
- `analytics_id`, `analytics_id_type`
- `ntfy_*` (Ntfy.sh push notification settings)
- `external_image_mode` (use external image URLs)

**Subscription**:
- `provisioning_state` (live, provisioning, failed)
- `subscription` relationship

**Associations**:
```ruby
has_many :realty_assets
has_many :sale_listings, through: :realty_assets
has_many :rental_listings, through: :realty_assets
has_many :listed_properties          # Materialized view
has_many :pages, :links, :contents
has_many :contacts, :messages
has_many :users, :members (through memberships)
has_many :field_keys
has_many :media, :media_folders
belongs_to :theme (ActiveHash)
```

**Important Scoping**:
```ruby
# Always scope queries to current website in web context
website.realty_assets                # All properties
website.listed_properties            # Materialized view
website.admins                       # Users with admin/owner role
website.page_parts                   # All page building blocks
```

---

## 8. Admin Interfaces

### Two-Tier Admin Architecture

#### **site_admin** (Platform Admins)
- Path: `/site_admin/`
- Manages: Websites, users, subscriptions, plans
- Controllers in: `/app/controllers/site_admin/`
- Views in: `/app/views/site_admin/`

**Key Controllers**:
- `site_admin/websites_controller` - Create/manage websites
- `site_admin/users_controller` - Platform users
- `site_admin/plans_controller` - Subscription plans
- `site_admin/subscriptions_controller` - Active subscriptions
- `site_admin/subdomains_controller` - Subdomain management

#### **tenant_admin** (Website Admins - Tenant Users)
- Path: `/tenant_admin/`
- Manages: Properties, content, contacts, media for their website
- Controllers in: `/app/controllers/tenant_admin/`
- Views in: `/app/views/tenant_admin/`
- Uses: `current_website` scoping

**Key Controllers**:
- `tenant_admin/media_library_controller` - Media management
- `tenant_admin/pages_controller` - Page management
- `tenant_admin/contents_controller` - Content blocks
- `tenant_admin/pages/settings_controller` - Page-specific settings
- `tenant_admin/onboarding_controller` - Setup wizard
- `tenant_admin/dashboard_controller` - Overview
- `tenant_admin/email_templates_controller` - Email setup
- `tenant_admin/domains_controller` - Custom domains

**Missing Property Controllers**: Note - no dedicated properties controllers in tenant_admin yet (these may be in API or embedded in theme editor)

---

## 9. Data Flow & Content Pipeline

### Property Creation & Publishing

```
1. RealtyAsset created
   └─ Physical property registered in system

2. SaleListing or RentalListing created
   └─ Transaction details added
   └─ Only one can be active per property

3. PropPhotos attached
   └─ Images uploaded to ActiveStorage
   └─ ActiveStorage handles local/R2 storage

4. Features assigned
   └─ Links property to FieldKey amenities

5. Pwb::ListedProperty view refreshed
   └─ Materialized view updated
   └─ Queryable for frontend

6. Frontend queries
   └─ Use ListedProperty view (optimized)
   └─ Renders property details with photos & features
```

### Content Block Flow

```
1. Page created
   └─ Slug, visibility, navigation settings

2. Content blocks created
   └─ Reusable content with translations

3. Page connected to Content
   └─ PageContent join table
   └─ Controls ordering & visibility per page

4. Photos added to Content
   └─ ContentPhoto for block-level images

5. Frontend renders
   └─ Page fetches ordered_visible_page_contents
   └─ Renders with translations, photos, styling
```

### Message/Enquiry Flow

```
1. Visitor submits contact form
   └─ Creates Message record
   └─ Captures: text, email, IP, geolocation, user agent

2. Optional: Contact record created/updated
   └─ Tracks visitor as contact

3. Delivery notification
   └─ Email sent to configured email address
   └─ Delivery status tracked

4. Admin notification
   └─ If Ntfy enabled: push notification to admin
```

---

## 10. Tenant Scoping (Multi-Tenancy)

### Pattern

All models prefixed `Pwb::*` are **global models** - they have `website_id` but aren't automatically scoped.

All models in `PwbTenant::*` are **tenant-scoped models** - they automatically scope queries to `current_website` in web requests.

**Web Request Context**:
```ruby
# Set by middleware
ActsAsTenant.current_tenant = current_website

# Use tenant-scoped models in web controllers
PwbTenant::RealtyAsset.all        # Only this website's properties
PwbTenant::ListedProperty.all     # Only this website's listings
PwbTenant::Contact.all            # Only this website's contacts

# NOT PwbTenant::ListedProperty - that's a view, use directly
Pwb::ListedProperty.where(website_id: current_website.id)
```

**Console/Background Job Context**:
```ruby
# No automatic scoping - must scope manually
Pwb::RealtyAsset.where(website_id: website.id)

# Or use explicit scoping
ActsAsTenant.with_tenant(website) do
  RealtyAsset.all  # Scoped automatically
end
```

---

## 11. File Storage & Images

### ActiveStorage Setup

**Configuration**:
- Development: Local disk (`/storage`)
- Production: Cloudflare R2 (S3-compatible)

**Attachments in System**:
```ruby
PropPhoto.has_one_attached :image
ContentPhoto.has_one_attached :image
Media.has_one_attached :file
```

**URL Generation**:
```ruby
# Uses Rails blob URLs (work with any storage backend)
Rails.application.routes.url_helpers.rails_blob_path(attachment, only_path: true)

# Variants (images only)
image.variant(resize_to_fill: [150, 150])
Rails.application.routes.url_helpers.rails_representation_path(variant.processed, only_path: true)
```

**CDN Integration**:
- When `CDN_IMAGES_URL` set: Direct CDN URLs
- When `R2_PUBLIC_URL` set: Direct R2 URLs
- Otherwise: Rails redirect URLs

---

## 12. Key Integration Points for AI Features

Based on the structure, here are ideal integration points for AI enhancements:

### Content Generation
- **Property Descriptions**: Hook into SaleListing/RentalListing after_create to auto-generate descriptions
- **Page Content**: Auto-generate Page content blocks from templates
- **Email Templates**: Generate customized email templates

### Image Analysis
- **Photo Metadata**: Extract dimensions, analyze image quality, suggest alt text
- **Listing Images**: Detect property type/condition from images
- **Media Library**: Auto-tag images in media library

### Search & Discovery
- **Property Recommendations**: Query ListedProperty view for similar properties
- **Feature Suggestions**: Auto-suggest missing features based on property type
- **Price Estimation**: Analyze similar properties for pricing recommendations

### Admin Features
- **Draft Suggestions**: Auto-suggest page content titles/descriptions
- **SEO Optimization**: Check SEO fields, suggest improvements
- **Translation Assistance**: Help translate content blocks

### Visitor Features
- **Smart Search**: Enhanced property search with AI
- **Enquiry Processing**: Auto-categorize/summarize visitor messages
- **Chatbot**: FAQ support from Page/Content blocks

---

## 13. Database Relationships at a Glance

```
Website (Tenant Root)
├─ RealtAsset (Physical Property)
│  ├─ SaleListing (Sale Transaction) [0-1 active]
│  ├─ RentalListing (Rental Transaction) [0-1 active]
│  ├─ PropPhoto (Images)
│  └─ Feature (Amenities)
├─ Page (CMS Pages)
│  └─ PageContent (Join)
│     └─ Content (Content Blocks)
│        └─ ContentPhoto (Block Images)
├─ Contact (Visitor/Lead)
│  └─ Message (Enquiry)
├─ Media (Media Library)
│  └─ MediaFolder (Hierarchical folders)
├─ FieldKey (Translation Keys for dropdowns)
├─ Link (Navigation links)
├─ User (Admins)
│  └─ UserMembership (Can access multiple websites)
└─ Subscription (Plan + Billing)
```

---

## 14. Important Configuration Classes

### **Pwb::Theme** (ActiveHash)
Defines available Tailwind themes. Pre-loaded from config, not database.

### **Pwb::Plan** (Subscription Plans)
**Table**: `pwb_plans`

Defines subscription tiers:
- `property_limit` - Max properties
- `user_limit` - Max admin users
- `features` (JSON array) - Feature flags
- `price_cents`, `price_currency` - Pricing
- `trial_days` - Free trial length

### **Pwb::Subscription** (Active Subscriptions)
**Table**: `pwb_subscriptions`

Tracks active subscriptions for websites:
- `status` - trialing, active, past_due, cancelled
- `external_id` - Stripe subscription ID
- `current_period_starts_at`, `current_period_ends_at`
- `trial_ends_at`
- `metadata` (JSON)

---

## Summary for AI Integration

This is a well-architected multi-tenant system with:

1. **Clear data isolation** - website_id scoping + ActsAsTenant
2. **Optimized querying** - Materialized view for property searches
3. **Rich translations** - Mobility JSONB translations
4. **Media management** - Centralized media library with variant support
5. **Content flexibility** - Reusable content blocks with photos
6. **Transaction tracking** - Separate listing models for audit trail
7. **Professional UI** - Two-tier admin (platform + tenant)

**Best Integration Patterns**:
- Hook into model callbacks (after_create, after_update)
- Use existing translations columns (JSONB)
- Query via tenant-scoped models in web context
- Store AI metadata in JSON columns (details, configuration, admin_config)
- Use background jobs for heavy processing (AI API calls)

