# PropertyWebBuilder Quick Reference Guide

## Model Quick Lookup

### Property Models

| Model | Table | Purpose | Key Methods |
|-------|-------|---------|-------------|
| `Pwb::RealtyAsset` | `pwb_realty_assets` | Physical property | `for_sale?`, `for_rent?`, `active_sale_listing`, `active_rental_listing` |
| `Pwb::SaleListing` | `pwb_sale_listings` | Sale transaction | `price_sale_current`, `visible`, `active` |
| `Pwb::RentalListing` | `pwb_rental_listings` | Rental transaction | `price_rental_monthly_current`, `for_rent_short_term?`, `vacation_rental?` |
| `Pwb::ListedProperty` | `pwb_properties` (view) | Query-optimized view | `refresh()`, Read-only |
| `Pwb::PropPhoto` | `pwb_prop_photos` | Property images | `has_one_attached :image` |
| `Pwb::Feature` | `pwb_features` | Property amenities | `feature_key` |

### Content Models

| Model | Table | Purpose | Key Methods |
|-------|-------|---------|-------------|
| `Pwb::Page` | `pwb_pages` | CMS page | `has_many :contents`, `translates :raw_html, :page_title, :link_title` |
| `Pwb::Content` | `pwb_contents` | Reusable block | `translates :raw`, `has_many :content_photos` |
| `Pwb::PageContent` | `pwb_page_contents` | Join table | `ordered_visible` scope |
| `Pwb::PagePart` | `pwb_page_parts` | Page section template | `block_contents` (JSON) |
| `Pwb::ContentPhoto` | `pwb_content_photos` | Block image | `optimized_image_url`, `variant_url(:thumb)` |
| `Pwb::Link` | `pwb_links` | Navigation link | `translates :link_title`, `ordered_visible_admin` |

### Contact & Enquiry Models

| Model | Table | Purpose | Key Methods |
|-------|-------|---------|-------------|
| `Pwb::Contact` | `pwb_contacts` | Lead/visitor record | `has_many :messages`, `primary_address` |
| `Pwb::Message` | `pwb_messages` | Form enquiry | `origin_email`, `delivery_success`, `content` |
| `Pwb::Address` | `pwb_addresses` | Location data | Reusable by contacts |

### Configuration & Admin Models

| Model | Table | Purpose | Key Attributes |
|-------|-------|---------|-----------------|
| `Pwb::Website` | `pwb_websites` | Tenant root | `subdomain`, `theme_name`, `supported_locales`, `configuration` |
| `Pwb::User` | `pwb_users` | Platform user | `email`, `admin`, `memberships` |
| `Pwb::UserMembership` | `pwb_user_memberships` | User-website link | `role` (owner/admin/member) |
| `Pwb::FieldKey` | `pwb_field_keys` | Translation keys | `global_key`, `tag`, `translates :label` |
| `Pwb::Plan` | `pwb_plans` | Subscription tier | `property_limit`, `user_limit`, `price_cents` |
| `Pwb::Subscription` | `pwb_subscriptions` | Active subscription | `status`, `current_period_ends_at` |

### Media Models

| Model | Table | Purpose | Key Methods |
|-------|-------|---------|-------------|
| `Pwb::Media` | `pwb_media` | Media library file | `has_one_attached :file`, `variant_url()` |
| `Pwb::MediaFolder` | `pwb_media_folders` | Folder hierarchy | `parent_id` (self-referential) |

---

## Common Queries

### Properties

```ruby
# Get all properties for a website
website.realty_assets
website.listed_properties                # Materialized view (optimized)

# Get properties by type
website.realty_assets.where(prop_type_key: "property.types.apartment")

# Properties for sale/rent
website.listed_properties.where(for_sale: true)
website.listed_properties.where(for_rent: true)

# Price filtering
website.listed_properties.where(
  "price_sale_current_cents >= ?", 100_000_00
)

# By location
website.listed_properties.where(city: "Barcelona")

# Featured properties
website.listed_properties.where(highlighted: true)

# With photos
website.realty_assets.joins(:prop_photos)

# By features
asset = Pwb::RealtyAsset.first
asset.features.map(&:feature_key)     # All feature keys
asset.get_features                    # Hash { key => true }
```

### Content & Pages

```ruby
# Get all pages
website.pages.where(visible: true)

# Get page by slug
website.pages.find_by(slug: "about-us")

# Page with content blocks (ordered, visible only)
page.ordered_visible_page_contents.includes(:content)

# Get specific content block
page.contents.find_by(page_part_key: "hero")

# Content photos
content.content_photos.map(&:optimized_image_url)
```

### Contacts & Messages

```ruby
# Get all enquiries
website.messages.recent

# By email
contact = website.contacts.find_by(primary_email: "visitor@example.com")

# Get contact's messages
contact.messages

# Failed deliveries
website.messages.where(delivery_success: false)

# Unread (assuming you add a read_at column)
website.messages.where(delivery_success: true)
```

### Translations

```ruby
# Current locale
listing.title                           # Uses I18n.locale

# Specific locale
listing.title_en
listing.title_es
listing.title_de

# Set translation
listing.title_es = "Apartamento Hermoso"
listing.save

# Get all translations
listing.translations                    # JSONB hash

# With locale switching
I18n.with_locale(:es) do
  listing.title                         # Spanish version
end

# Fallback example
listing.title_fr                        # French not set
# => Falls back to English (title_en)
```

### Admin/Users

```ruby
# Website admins
website.admins                          # Has owner or admin role, active

# All members
website.members                         # Via memberships

# Add user to website
website.user_memberships.create(
  user: user,
  role: 'admin',  # owner, admin, member
  active: true
)

# Get user's websites
user.websites                           # Via memberships
```

### Field Keys (Dropdowns)

```ruby
# Get property types for dropdown
Pwb::FieldKey.get_options_by_tag("property-types")
# => [OpenStruct(value: "property.types.apt", label: "Apartment"), ...]

# Get features for dropdown
Pwb::FieldKey.get_options_by_tag("features")

# All property states
Pwb::FieldKey.by_tag("property-states").visible.ordered

# Label for a key
key = Pwb::FieldKey.find("property.types.apartment")
key.display_label                       # Localized label
```

---

## Tenancy Patterns

### Web Request (Automatic Scoping)

```ruby
# In controller - ActsAsTenant middleware sets current_website
def index
  @properties = PwbTenant::RealtyAsset.all   # Auto-scoped!
  @contacts = PwbTenant::Contact.all         # Auto-scoped!
end
```

### Console (Manual Scoping)

```ruby
# Get specific website
website = Pwb::Website.find_by(slug: "mybrokerage")

# Option 1: Use ActsAsTenant block
ActsAsTenant.with_tenant(website) do
  RealtyAsset.all                        # Now scoped!
end

# Option 2: Manual where
website.realty_assets                    # All properties
Pwb::RealtyAsset.where(website_id: website.id)
```

### Background Jobs

```ruby
# In job
class UpdatePropertyJob < ApplicationJob
  def perform(property_id, website_id)
    website = Pwb::Website.find(website_id)
    
    ActsAsTenant.with_tenant(website) do
      property = RealtyAsset.find(property_id)
      property.update(...)
    end
  end
end

# Enqueue
UpdatePropertyJob.perform_later(property.id, website.id)
```

---

## Translation Attribute Patterns

### Models with Translations

```ruby
# Translatable attributes are defined in model
class SaleListing < ApplicationRecord
  translates :title, :description, :seo_title, :meta_description
end

# How they work:
# - Stored in 'translations' JSONB column
# - Mobility handles serialization
# - Locale accessors auto-generated
# - Fallback chain: xx -> en

# Usage in code:
listing.title = "English Title"
listing.title_es = "Título en Español"
listing.title_fr = "Titre en Français"

# Storage in DB:
# translations: {
#   "en": { "title": "English Title" },
#   "es": { "title": "Título en Español" },
#   "fr": { "title": "Titre en Français" }
# }
```

### Models Using Translations

- **RealtyAsset**: `title`, `description`
- **SaleListing**: `title`, `description`, `seo_title`, `meta_description`
- **RentalListing**: `title`, `description`, `seo_title`, `meta_description`
- **Content**: `raw` (HTML content)
- **Page**: `raw_html`, `page_title`, `link_title`
- **FieldKey**: `label` (dropdown label)
- **Link**: `link_title`

---

## Image/Media Handling

### PropPhoto (Property Images)

```ruby
# Add image to property
prop = Pwb::RealtyAsset.first
photo = prop.prop_photos.create(sort_order: 1)
photo.image.attach(io: File.open(path), filename: "photo.jpg")

# Get photos
prop.prop_photos.ordered                 # By sort_order
prop.ordered_photo(1)                    # First photo

# URL
photo.image.url                          # Original URL
photo.image.variant(resize_to_limit: [800, 600]).processed.url  # Variant
```

### ContentPhoto (Page Block Images)

```ruby
# Add image to content block
content = Pwb::Content.first
photo = content.content_photos.create(
  block_key: "hero_section",
  description: "Hero image"
)
photo.image.attach(...)

# Get URL
photo.optimized_image_url                # Smart URL (variants + CDN)
photo.variant_url(:thumb)                # 150x150
photo.variant_url(:medium)               # 600x600
```

### Media Library

```ruby
# Upload to library
media = website.media.create(
  filename: "property-photo.jpg",
  title: "Beautiful House"
)
media.file.attach(io: File.open(path), filename: "property.jpg")

# Find media
website.media.images.recent
website.media.search("bedroom")
website.media.with_tag("properties")

# Display
media.url                                # Original
media.variant_url(:thumb)                # Variant
media.display_name                       # Title or filename
media.human_file_size                    # "2.5 MB"
```

---

## Refresh Materialized View

```ruby
# After creating/updating properties, refresh the view:
Pwb::ListedProperty.refresh              # Concurrent (safe)
Pwb::ListedProperty.refresh(concurrently: false)  # Exclusive

# Automatic refresh:
# - RealtyAsset has callback: after_commit :refresh_properties_view
# - SaleListing includes RefreshesPropertiesView concern
# - RentalListing includes RefreshesPropertiesView concern
# - So view is auto-refreshed after saves

# For very large datasets:
# Use async refresh if job available
Pwb::ListedProperty.refresh_async        # Sidekiq/job queue
```

---

## Website Configuration Access

```ruby
website = Pwb::Website.first

# Basic info
website.company_display_name
website.subdomain
website.custom_domain

# Localization
website.supported_locales                # ["en-UK", "es", "de", ...]
website.default_client_locale
website.default_currency
website.supported_currencies

# Theme
website.theme_name                       # e.g., "brisbane"
website.selected_palette                 # Color palette
website.style_variables_for_theme        # CSS variables
website.raw_css                          # Custom CSS

# Search config
website.search_config_buy                # JSON
website.search_config_rent
website.search_config_landing

# Contact
website.email_for_general_contact_form
website.email_for_property_contact_form

# Integrations
website.maps_api_key
website.analytics_id
website.ntfy_enabled
website.external_image_mode              # Use external URLs

# Flexible config
website.configuration[:some_key]         # Arbitrary settings
website.admin_config[:theme_settings]    # Admin UI settings
```

---

## Pagination & Performance

### N+1 Query Prevention

```ruby
# Bad
properties.each { |p| p.features.count }  # N+1 query!

# Good
properties.includes(:features).each { |p| p.features.count }

# Materialized view (no N+1)
website.listed_properties                # Already has all data
```

### Scoping for Large Datasets

```ruby
# Paginate results
website.realty_assets.limit(20).offset(0)

# Or use kaminari/will_paginate
website.realty_assets.page(1).per(20)

# Query optimization
website.realty_assets
  .includes(:prop_photos, :features)
  .where(visible: true)
  .page(params[:page])
```

### Materialized View Refresh Strategy

```ruby
# For small sites: Refresh after each change
after_commit { Pwb::ListedProperty.refresh }

# For large sites: Batch refresh
# Run in background job daily
class RefreshListedPropertiesJob < ApplicationJob
  def perform
    Pwb::ListedProperty.refresh(concurrently: true)
  end
end
```

---

## Messaging & Enquiry System

### Create Enquiry

```ruby
message = website.messages.create(
  title: "Inquiry about property",
  content: "I'm interested in the apartment...",
  origin_email: "visitor@example.com",
  origin_ip: request.remote_ip,
  user_agent: request.user_agent,
  host: request.host,
  url: request.referrer,
  locale: I18n.locale,
  latitude: geoloc.latitude,
  longitude: geoloc.longitude
)

# Link to contact if exists
contact = website.contacts.find_by(primary_email: "visitor@example.com")
message.update(contact: contact)
```

### Send Notification

```ruby
# Email delivered to
message.delivery_email = website.email_for_general_contact_form
message.delivery_success = send_email(...)
message.delivered_at = Time.current
message.save

# Push notification (if enabled)
if website.ntfy_enabled && website.ntfy_notify_inquiries
  # Ntfy notification sent automatically by concern
end
```

---

## Admin Controllers to Explore

| Path | Controller | Purpose |
|------|-----------|---------|
| `/tenant_admin/` | `dashboard_controller` | Stats & overview |
| `/tenant_admin/media_library` | `media_library_controller` | File management |
| `/tenant_admin/pages` | `pages_controller` | Page CRUD |
| `/tenant_admin/contents` | `contents_controller` | Content blocks |
| `/tenant_admin/email_templates` | `email_templates_controller` | Email setup |
| `/tenant_admin/domains` | `domains_controller` | Custom domain |
| `/site_admin/websites` | `websites_controller` | Website CRUD |
| `/site_admin/users` | `users_controller` | User management |
| `/site_admin/plans` | `plans_controller` | Subscription plans |

---

## Integration Points for AI Features

### Property Description Generation
```ruby
# Hook: After listing created
class SaleListing < ApplicationRecord
  after_create :generate_ai_description, if: :description_blank?
  
  private
  
  def generate_ai_description
    self.description = AiService.generate_listing_description(self)
    save
  end
end
```

### Image Analysis
```ruby
# Hook: After photo attached
class PropPhoto < ApplicationRecord
  after_create_commit :analyze_image
  
  def analyze_image
    return unless image.attached?
    metadata = AiService.analyze_image(image)
    # Store in details or create separate table
  end
end
```

### Content Suggestions
```ruby
# Hook: Page content generation
def create_ai_content_block(page, template)
  content = Pwb::Content.create(
    key: "ai_#{SecureRandom.hex(4)}",
    page_part_key: "hero"
  )
  
  content.update(
    raw_en: AiService.generate_content(:en, template),
    raw_es: AiService.generate_content(:es, template)
  )
  
  page.page_contents.create(
    content: content,
    sort_order: 0
  )
end
```

---

## Useful Scopes & Methods

### Scope Examples

```ruby
# Property status
property.for_sale?
property.for_rent?
property.visible?

# Listing status
sale_listing.visible?
sale_listing.active?

# Features
property.get_features              # Hash { key => true }
property.set_features = hash       # Set features

# Photos
property.ordered_photo(1)          # Nth photo
property.primary_image_url         # First photo or empty

# Content
page.ordered_visible_page_contents # Content sorted & visible only

# Messages
website.messages.where(delivery_success: false)
```

### Method Examples

```ruby
# Realty Asset
asset.for_sale?
asset.for_rent?
asset.visible?
asset.active_sale_listing
asset.active_rental_listing
asset.get_features
asset.extras_for_display            # Localized feature names

# Listing
listing.price_sale_current.format(no_cents: true)
listing.price_rental_monthly_current.format(no_cents: true)

# Page
page.get_page_part(key)
page.set_fragment_html(key, locale, html)
page.set_fragment_visibility(key, visible)

# Contact
contact.street_address              # Via primary_address
contact.city
contact.postal_code

# Media
media.url
media.variant_url(:thumb)
media.display_name
media.human_file_size
media.record_usage!
```

---

## Database Indexes to Know

```sql
-- Property search
index_pwb_properties_on_for_sale
index_pwb_properties_on_for_rent
index_pwb_properties_on_price_sale_cents
index_pwb_properties_on_price_rental_cents
index_pwb_properties_on_highlighted
index_pwb_properties_on_lat_lng

-- Property details
index_pwb_properties_on_slug
index_pwb_properties_on_reference
index_pwb_properties_on_prop_type

-- Content search
index_pwb_contents_on_translations (GIN - JSONB)
index_pwb_pages_on_translations (GIN - JSONB)

-- User scoping
index_pwb_user_memberships_on_user_and_website

-- Field keys
index_field_keys_unique_per_website
index_field_keys_on_website_and_tag

-- Media
index_pwb_media_on_website_id
index_pwb_media_on_tags (GIN)
index_pwb_media_on_folder_id
```

This quick reference should cover 80% of common operations in PropertyWebBuilder!
