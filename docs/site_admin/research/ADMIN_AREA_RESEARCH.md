# PropertyWebBuilder Admin Area - Comprehensive Research

Date: 2025-12-31
Status: Research Only (No Code Changes)

## Executive Summary

PropertyWebBuilder is a multi-tenant Rails application where each website is a tenant. The admin area is split into two controller namespaces:

1. **SiteAdmin** - Tenant-level administration (per-website admin panel)
2. **TenantAdmin** - Platform-level administration (system-wide admin)

This document provides a detailed inventory of the admin system's current state, database models, functionality, and implementation patterns.

---

## Architecture Overview

### Multi-Tenancy Model

- **Tenant Scope**: Each `Pwb::Website` is a separate tenant
- **Scoping Pattern**: All models use `website_id` foreign key for isolation
- **View Models**: Tenant-scoped query classes in `app/models/pwb_tenant/` (e.g., `PwbTenant::RealtyAsset`, `PwbTenant::Message`)
- **Read Optimization**: Materialized views for complex queries (e.g., `Pwb::ListedProperty`)

### Key Architectural Patterns

- **Materialized Views**: `pwb_properties` view denormalizes `realty_assets + sale_listings + rental_listings`
- **Mobility Translations**: Uses Mobility gem for multi-language support (JSONB storage)
- **Money Gem**: Monetize gem for currency handling on price fields
- **AASM State Machine**: Used for subscription status management
- **ActiveStorage**: File uploads with support for local disk and Cloudflare R2

---

## 1. DASHBOARD

### Controllers
- **SiteAdmin**: `/app/controllers/site_admin/dashboard_controller.rb`
- **TenantAdmin**: `/app/controllers/tenant_admin/dashboard_controller.rb`

### SiteAdmin Dashboard (Per-Website)

**Endpoint**: `/site_admin/` (DashboardController#index)

**Views**: `/app/views/site_admin/dashboard/index.html.erb`

**Statistics Displayed**:
```ruby
@stats = {
  total_properties: Pwb::ListedProperty count (website-scoped),
  total_pages: Pwb::Page count,
  total_contents: Pwb::Content count,
  total_messages: Pwb::Message count,
  total_contacts: Pwb::Contact count
}

@weekly_stats = {
  new_messages: Messages created this week,
  new_contacts: Contacts created this week,
  new_properties: Properties created this week
}

@unread_messages_count: Unread message count
```

**Recent Activity**:
- Recent properties (5 items, from ListedProperty materialized view)
- Recent messages (5 items)
- Recent contacts (5 items)
- Combined activity timeline (10 items total)

**Activity Timeline Structure**:
```ruby
{
  type: :message | :property | :contact,
  icon: 'email' | 'property' | 'contact',
  title: String,
  time: DateTime,
  path: route_path
}
```

**Website Health/Setup Checklist** (7 checks):
1. Agency profile complete (company_name, email_primary present)
2. At least one property added
3. Theme configured
4. Custom domain set up
5. Social media links added
6. SEO meta tags configured
7. Logo uploaded

Returns: `{ checks, completed, total, percentage }`

**Subscription Information**:
```ruby
@subscription_info = {
  status: String,
  plan_name: String,
  plan_price: String (formatted),
  trial_days_remaining: Integer | nil,
  trial_ending_soon: Boolean,
  in_good_standing: Boolean,
  current_period_ends_at: DateTime,
  property_limit: Integer | nil,
  remaining_properties: Integer | nil,
  features: Array<Hash> (key, description)
}
```

**Getting Started Guide**: 
- Shows only if health < 70% OR total_properties < 3
- Can be dismissed via cookie

### TenantAdmin Dashboard (Platform-Level)

**Endpoint**: `/tenant_admin/` (DashboardController#index)

**System-Wide Statistics**:
```ruby
@total_websites: All websites count
@total_users: All users count
@total_properties: All properties count (ListedProperty)
@active_tenants: Websites updated in last 30 days

@recent_websites: Last 5 websites created
@recent_users: Last 10 users created
@recent_messages: Last 10 messages
@recent_properties: Last 10 properties
```

**Subscription Statistics**:
```ruby
@subscription_stats = {
  total: Pwb::Subscription count,
  active: active_subscriptions count,
  trialing: trialing subscriptions count,
  past_due: past_due subscriptions count,
  canceled: canceled subscriptions count,
  expiring_soon: expiring within 7 days count
}

@plan_stats = {
  total: Pwb::Plan count,
  active: active plans count
}

@expiring_trials: Trials ending within 7 days (5 items) with includes(:website, :plan)
```

**Database Queries Made**:
- Uses `unscoped` to bypass default scopes
- Uses materialized view for property counts (more efficient than joins)
- No N+1 queries visible (limited to 5-10 items with eager loading)

---

## 2. PROPERTIES ADMIN

### Controllers
- **Primary**: `/app/controllers/site_admin/props_controller.rb`
- **Sale Listings**: `/app/controllers/site_admin/props/sale_listings_controller.rb`
- **Rental Listings**: `/app/controllers/site_admin/props/rental_listings_controller.rb`

### Routes Structure
```
/site_admin/props               # List properties
/site_admin/props/:id           # Show property
/site_admin/props/new           # New property
/site_admin/props/:id/edit_general     # Edit basic info
/site_admin/props/:id/edit_text        # Edit titles/descriptions
/site_admin/props/:id/edit_sale_rental # Edit sale/rental listings
/site_admin/props/:id/edit_location    # Edit coordinates
/site_admin/props/:id/edit_labels      # Edit features/amenities
/site_admin/props/:id/edit_photos      # Manage photos
/site_admin/props/:id/upload_photos    # Upload photos
/site_admin/props/:id/remove_photo     # Delete photo
/site_admin/props/:id/reorder_photos   # Drag-drop reorder
/site_admin/props/:id                  # Update property
```

### Property Models

#### Pwb::RealtyAsset (Primary Model - Writes)
**Table**: `pwb_realty_assets` (UUID PK)

**Key Columns**:
```
Physical Property Data:
  - reference: String (ID/SKU)
  - title: String (via translations JSONB)
  - description: Text
  - street_number, street_name, street_address: String
  - city, postal_code, region, country: String
  - latitude, longitude: Float (from geocoding)
  
Building/Land Data:
  - count_bedrooms: Integer
  - count_bathrooms: Float
  - count_garages: Integer
  - count_toilets: Integer
  - plot_area: Float (square meters)
  - constructed_area: Float
  - year_construction: Integer
  
Classifications:
  - prop_type_key: String (e.g., 'apartment', 'house')
  - prop_state_key: String (e.g., 'new', 'renovated')
  - prop_origin_key: String (e.g., 'standard', 'foreclosure')
  
Energy:
  - energy_rating: Integer
  - energy_performance: Float
  
Associations:
  - website_id: Integer (foreign key - multi-tenant scoping)
  - slug: String (unique, auto-generated)
  - translations: JSONB (Mobility - stores i18n data)
  - created_at, updated_at: DateTime
```

**Associations**:
- `has_many :sale_listings` - For sale transactions
- `has_many :rental_listings` - For rental transactions
- `has_many :prop_photos` - Property images
- `has_many :features` - Amenities/features (e.g., pool, gym)
- `belongs_to :website`

**Scopes & Methods**:
- `:with_eager_loading` - Loads associated photos to avoid N+1
- `geocoded_by :geocodeable_address` - Auto-geocoding via Geocoder gem

#### Pwb::ListedProperty (Read-Only - Materialized View)
**View**: `pwb_properties` (denormalized join of realty_assets + listings)

**Query Optimization**: Materialized view refreshes after writes via `RefreshesPropertiesView` concern

**Unique Columns** (beyond RealtyAsset):
```
Listing Status (from SaleListing):
  - for_sale: Boolean
  - sale_listing_id: UUID
  - price_sale_current_cents: Bigint
  - price_sale_current_currency: String
  - sale_furnished, sale_highlighted, sale_reserved: Boolean

Listing Status (from RentalListing):
  - for_rent: Boolean
  - rental_listing_id: UUID
  - for_rent_long_term, for_rent_short_term: Boolean
  - price_rental_monthly_current_cents: Bigint
  - price_rental_monthly_high_season_cents: Bigint
  - price_rental_monthly_low_season_cents: Bigint
  - rental_furnished, rental_highlighted, rental_reserved: Boolean

Denormalized Fields (for search):
  - price_rental_monthly_for_search_cents: Bigint
  - visible: Boolean (true if either listing is visible)
```

**Indexes**:
- `(website_id)` - Tenant scoping
- `(for_sale, for_rent)` - Listing type filtering
- `(price_sale_current_cents, price_rental_monthly_current_cents)` - Price filtering
- `(latitude, longitude)` - Map/geo search
- `(created_at, updated_at)` - Recent properties
- Unique: `(slug)` - URL-friendly identifier

### Listing Models

#### Pwb::SaleListing
**Table**: `pwb_sale_listings` (UUID PK)

**Columns**:
```
Transaction Data:
  - price_sale_current_cents: Bigint
  - price_sale_current_currency: String (e.g., 'EUR')
  - commission_cents: Bigint
  - commission_currency: String
  
Listing Status:
  - visible: Boolean (hidden from public)
  - active: Boolean (unique constraint with realty_asset_id)
  - archived: Boolean
  - highlighted: Boolean (featured listing)
  - reserved: Boolean (under contract)
  - furnished: Boolean
  
SEO/Marketing:
  - translations: JSONB (Mobility)
    - title_{locale}
    - description_{locale}
    - seo_title_{locale}
    - meta_description_{locale}
  
Misc:
  - reference: String (alternative ID)
  - noindex: Boolean (block search engines)
  - created_at, updated_at: DateTime
  - realty_asset_id: UUID (FK)
```

**Constraints**:
- Unique constraint: one active listing per realty_asset (`active = true`)

#### Pwb::RentalListing
**Table**: `pwb_rental_listings` (UUID PK)

**Columns** (similar structure):
```
Transaction Data:
  - price_rental_monthly_current_cents: Bigint
  - price_rental_monthly_low_season_cents: Bigint
  - price_rental_monthly_high_season_cents: Bigint
  - price_rental_monthly_current_currency: String
  
Rental-Specific:
  - for_rent_short_term: Boolean (vacation rentals)
  - for_rent_long_term: Boolean (annual rentals)
  
(Rest same as SaleListing)
```

### Photo Management

#### Pwb::PropPhoto
**Associations**:
- `belongs_to :realty_asset`
- `has_one_attached :image` (ActiveStorage)

**Fields**:
- `sort_order: Integer` - Display order
- `external_url: String` (optional, for external image mode)
- `image: ActiveStorage::Attachment`

**Modes**:
1. **File Upload Mode** (default): Files stored in ActiveStorage
2. **External URL Mode**: URLs stored in `external_url` column (for CDN)

**Current Implementation** (PropsController):
```ruby
# File uploads
params[:photos].each_with_index do |photo, index|
  prop_photo = @prop.prop_photos.build(sort_order: index + 1)
  prop_photo.image.attach(photo)
  prop_photo.save
end

# External URLs
urls.each_with_index do |url, index|
  @prop.prop_photos.build(
    sort_order: index + 1,
    external_url: url
  ).save
end

# Reorder via drag-drop
photo_ids.each_with_index { |id, idx| update sort_order: idx + 1 }
```

### Features/Amenities

#### PwbTenant::Feature
**Relationship**: `has_many :features` on RealtyAsset

**Fields**:
- `feature_key: String` (e.g., 'pool', 'gym', 'parking')
- `realty_asset_id: UUID`

**Implementation**:
```ruby
# Get available labels by category
@labels_by_category = {}
PwbTenant::FieldKey.where(tag: tag).visible.order(:sort_order)

# Update features
selected_features = Array(params[:features])
@prop.features.where.not(feature_key: selected_features).destroy_all
selected_features.each { |key| @prop.features.find_or_create_by(feature_key: key) }
```

### Controller Flow

**Index (List Properties)**:
- Uses `Pwb::ListedProperty.with_eager_loading` for reads
- Scope: `where(website_id: current_website.id)`
- Search: ILIKE on reference, title, street_address, city
- Pagination: 25 items per page
- No sorting options visible

**New/Create**:
- Create `Pwb::RealtyAsset` with required fields (reference, prop_type_key, coordinates, rooms)
- Validates within subscription property limit
- Redirects to `edit_general` to continue

**Show**:
- Uses read-only `Pwb::ListedProperty` view
- Pre-loads FieldKeys for display

**Edit Steps**:
1. `edit_general` - Basic property info (rooms, area, year, location)
2. `edit_text` - Titles/descriptions (per locale)
3. `edit_sale_rental` - Pricing, availability, listing status
4. `edit_location` - Coordinates, map
5. `edit_labels` - Amenities/features
6. `edit_photos` - Image management

**Update**:
- Runs in transaction
- Updates RealtyAsset, SaleListing, RentalListing, Features atomically
- Refreshes materialized view

### Database Fields Summary

**Asset Types (prop_type_key)**:
- Stored in `FieldKey` system (tag: 'property-types')
- Examples: apartment, house, villa, land, commercial

**Asset States (prop_state_key)**:
- Examples: new, renovated, needs_repair

**Field Keys System**:
- Centralized in `PwbTenant::FieldKey` model
- Used for dropdowns, filters, amenities
- Supports internationalization

### Gaps/Areas Needing Work

1. **Bulk Actions**: No bulk edit, delete, or property migration
2. **Batch Import**: No CSV/Excel import UI in admin panel
3. **Property Cloning**: No "duplicate property" feature
4. **Templates**: No property templates for quick setup
5. **Merge/Move**: No ability to move property to different website
6. **History/Audit**: No change history or version tracking in admin UI
7. **Conditional Listing**: Can't show different prices/descriptions by date range

---

## 3. MESSAGES/INBOX

### Controllers
- **Messages**: `/app/controllers/site_admin/messages_controller.rb`
- **Inbox**: `/app/controllers/site_admin/inbox_controller.rb` (CRM-style unified view)
- **Contacts**: `/app/controllers/site_admin/contacts_controller.rb`

### Routes Structure
```
/site_admin/messages/:id      # Show single message
/site_admin/inbox             # Contact list with thread view
/site_admin/inbox/:id         # Conversation with specific contact
/site_admin/contacts/:id      # Contact detail page
```

### Models

#### Pwb::Message
**Table**: `pwb_messages`

**Columns**:
```
Content:
  - title: String
  - content: Text
  
Sender Information:
  - origin_email: String (source email)
  - origin_ip: String
  
Delivery/Response:
  - delivery_email: String (where we sent response)
  - delivered_at: DateTime
  - delivery_success: Boolean
  - delivery_error: Text
  
Status:
  - read: Boolean (marked as read in admin)
  
Context:
  - url: String (page message came from)
  - host: String (domain)
  - user_agent: String
  - locale: String
  - latitude, longitude: Float (if geocoded)
  
Relationships:
  - website_id: Bigint (FK, multi-tenant scoping)
  - contact_id: Integer (optional, links to contact)
  - client_id: Integer (optional, legacy)
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Scopes**:
- `:unread` - where(read: false)
- `:read` - where(read: true)
- `:recent` - order(created_at: :desc)

**Methods**:
```ruby
sender_email      # contact.primary_email || origin_email
sender_name       # contact.display_name || extract from email || 'Unknown'
```

#### Pwb::Contact
**Table**: `pwb_contacts`

**Columns**:
```
Personal Information:
  - first_name: String
  - last_name: String
  - title: Enum (mr, mrs)
  - other_names: String
  
Contact Details:
  - primary_email: String
  - other_email: String
  - primary_phone_number: String
  - other_phone_number: String
  - fax: String
  - website_url: String
  
Social/Profiles:
  - facebook_id: String
  - twitter_id: String
  - linkedin_id: String
  - skype_id: String
  
Documentation:
  - documentation_type: Integer (enum)
  - documentation_id: String
  
Address References:
  - primary_address_id: Integer (FK to Address)
  - secondary_address_id: Integer (FK to Address)
  
Metadata:
  - details: JSON
  - flags: Integer (bit flags for custom statuses)
  - nationality: String
  
Relationships:
  - website_id: Bigint (FK)
  - user_id: Integer (optional, linked user account)
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Associations**:
- `has_many :messages` - All messages from this contact
- `belongs_to :website`
- `belongs_to :primary_address` (optional, Address model)
- `belongs_to :secondary_address` (optional, Address model)
- `belongs_to :user` (optional, links to system user)

**Scopes**:
- `:with_messages` - Contacts that have at least one message
- `:ordered_by_recent_message` - Sorted by latest message time

**Methods**:
```ruby
display_name  # "[first] [last]" or email local part or "Unknown Contact"
unread_messages_count  # Count of unread messages (scoped to website)
last_message  # Most recent message (scoped to website)
```

### Inbox View (CRM-Style)

**MessagesController**:
- Includes `SiteAdminIndexable` concern
- Config: model=Pwb::Message, search_columns=%i[origin_email content], limit=100
- On show: marks message as read + logs audit

**InboxController**:
- Unified contact/message view
- Shows contacts with unread counts
- Displays conversation threads

**Contact List Query**:
```sql
SELECT pwb_contacts.*,
       MAX(pwb_messages.created_at) as last_message_at,
       COUNT(pwb_messages.id) as messages_count,
       SUM(CASE WHEN pwb_messages.read = false THEN 1 ELSE 0 END) as unread_count
FROM pwb_contacts
  JOIN pwb_messages ON pwb_messages.contact_id = pwb_contacts.id
WHERE pwb_contacts.website_id = ? 
  AND pwb_messages.website_id = ?
GROUP BY pwb_contacts.id
ORDER BY last_message_at DESC
LIMIT 100
```

**Conversation View**:
```ruby
@messages = Pwb::Message.where(
  website_id: current_website.id,
  contact_id: contact_id
).order(created_at: :asc)
```

**Orphan Messages**: Count messages with `contact_id IS NULL`

**On Conversation View**:
- Auto-marks all unread messages as read
- Logs audit entry for each message read (via `Pwb::AuthAuditLog.log_message_read`)
- Updates nav counts

### Gaps/Areas Needing Work

1. **Contact Status**: Flags field exists but not exposed in UI
2. **Tags/Labels**: No message/contact tagging system
3. **Conversation View**: No reply/draft functionality
4. **Search**: Limited to email and content; no advanced filters
5. **Export**: No bulk export of contacts or messages
6. **Assignment**: No ability to assign contacts to team members
7. **Automation**: No automatic contact deduplication or merge
8. **Analytics**: No sentiment analysis or intent classification

---

## 4. PAGES/CMS

### Controllers
- **Pages**: `/app/controllers/site_admin/pages_controller.rb`
- **Page Parts**: `/app/controllers/site_admin/page_parts_controller.rb`

### Routes Structure
```
/site_admin/pages              # List pages
/site_admin/pages/:id          # Show page
/site_admin/pages/:id/edit     # Edit page parts (drag-drop)
/site_admin/pages/:id/settings # Edit page metadata
/site_admin/pages/:id/reorder_parts  # Update page parts order
```

### Models

#### Pwb::Page
**Table**: `pwb_pages`

**Columns**:
```
Metadata:
  - slug: String (URL path)
  - visible: Boolean
  
Navigation:
  - show_in_top_nav: Boolean
  - show_in_footer: Boolean
  - sort_order_top_nav: Integer
  - sort_order_footer: Integer
  
SEO:
  - seo_title: String
  - meta_description: Text
  
Content:
  - translations: JSONB (via Mobility)
    - raw_html_{locale}
    - page_title_{locale}
    - link_title_{locale}
  
Relationships:
  - website_id: Integer (FK)
  - last_updated_by_user_id: Integer
  
Metadata:
  - details: JSON
  - flags: Integer (custom statuses)
  - setup_id: String
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Indexes**:
- Unique: `(slug, website_id)` - URL per website
- Separate: `(show_in_top_nav)`, `(show_in_footer)`, `(translations)` JSONB

**Associations**:
- `belongs_to :website`
- `has_many :page_parts` - Content sections via slug
- `has_many :links` - Navigation links
- `has_one :main_link` - Primary nav link
- `has_many :page_contents` - Content join table
- `has_many :contents` - Content items
- `has_many :ordered_visible_page_contents` - Visible contents

**Translations** (via Mobility):
- `:raw_html` - HTML content
- `:page_title` - H1 title
- `:link_title` - Nav text

**Methods**:
```ruby
get_page_part(page_part_key)
create_fragment_photo(page_part_key, block_label, photo_file)
set_fragment_visibility(page_part_key, visible_on_page)
set_fragment_html(page_part_key, locale, html)
update_page_part_content(page_part_key, locale, fragment_block)
```

#### Pwb::PagePart
**Table**: `pwb_page_parts`

**Columns**:
```
- page_slug: String (FK)
- website_id: Bigint
- page_part_key: String (template identifier)
- order_in_editor: Integer (drag-drop order)
- show_in_editor: Boolean (include in UI)
- visible_in_frontend: Boolean
- theme_section: String
- translations: JSONB (Mobility, for theme edits)
```

**Associations**:
- `belongs_to :page` - Via page_slug
- `belongs_to :website` - Scoping

#### Pwb::Content
**Table**: `pwb_contents`

**Purpose**: Stores page fragment/block content (HTML, rich text, etc.)

**Associations**:
- `has_many :page_contents` - Join to pages
- `has_many :pages` (through page_contents)

### Controller Flow

**Index**:
- Lists pages for current website
- Scope: `where(website_id: current_website.id)`
- Search: ILIKE on slug
- Pagination: 25 per page

**Show**: Display page view

**Edit** (Main Editor):
- Shows draggable page parts
- Filters: `show_in_editor: true`, ordered by `order_in_editor`
- Supports drag-drop reordering

**Settings** (Metadata):
- Edit slug, visibility, navigation placement
- Permittable: `:slug, :visible, :show_in_top_nav, :show_in_footer, :sort_order_top_nav, :sort_order_footer`

**Reorder Parts**:
- Takes `part_ids` array
- Updates `order_in_editor` for each part

### Gaps/Areas Needing Work

1. **Page Builder UI**: No visual page builder; parts/sections are pre-defined
2. **Versioning**: No page version history or rollback
3. **Scheduling**: No publish date/scheduled publishing
4. **Preview**: No staging/preview mode before publishing
5. **Page Hierarchy**: No parent/child page relationships
6. **Menus**: Limited to top nav and footer; no custom menus
7. **Widget System**: No drag-drop widget system for page parts
8. **Mobile Responsiveness Settings**: No per-page mobile layout options

---

## 5. MEDIA LIBRARY

### Controllers
- **Media**: `/app/controllers/site_admin/media_library_controller.rb`

### Routes Structure
```
/site_admin/media_library                    # Gallery view
/site_admin/media_library/:id                # Show/edit media details
/site_admin/media_library/:id/edit           # Edit metadata
/site_admin/media_library/:id                # Destroy media
/site_admin/media_library/bulk_destroy       # Bulk delete
/site_admin/media_library/bulk_move          # Bulk move to folder
/site_admin/media_library/folders            # List folders
/site_admin/media_library/folders/create     # Create folder
/site_admin/media_library/folders/:id/update # Update folder
/site_admin/media_library/folders/:id/destroy # Delete folder
```

### Models

#### Pwb::Media
**Table**: `pwb_media`

**Columns**:
```
File Information:
  - filename: String (required)
  - content_type: String (MIME type)
  - byte_size: Bigint
  - checksum: String (for deduplication)
  
Metadata:
  - title: String
  - alt_text: String
  - description: Text
  - caption: String
  - tags: Array<String> (JSONB array)
  
Image Specific:
  - width: Integer (pixels)
  - height: Integer (pixels)
  
Usage Tracking:
  - usage_count: Integer (incremented when used)
  - last_used_at: DateTime
  
Source:
  - source_type: String (e.g., 'upload')
  - source_url: String (optional)
  
Organization:
  - sort_order: Integer
  - folder_id: Bigint (FK, optional)
  
Relationship:
  - website_id: Bigint (FK, required, tenant scoping)
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Indexes**:
```
- (website_id) - Tenant scoping
- (website_id, content_type) - Filter by type
- (website_id, created_at) - Recent files
- (website_id, folder_id) - Folder browsing
- (tags) USING GIN - Tag search
- (folder_id) - Orphan detection
```

**Associations**:
- `belongs_to :website`
- `belongs_to :folder, class_name: 'Pwb::MediaFolder'` (optional)
- `has_one_attached :file` (ActiveStorage)

**Validations**:
- filename: presence
- file: presence on create, acceptable file type

**Callbacks**:
- `before_validation :set_metadata_from_file` - Extract dimensions
- `after_commit :extract_dimensions` (on create, if image)

**Scopes**:
```ruby
:images  # WHERE content_type LIKE 'image/%'
:documents  # WHERE content_type NOT LIKE 'image/%'
:recent  # ORDER BY created_at DESC
:by_folder(folder)  # WHERE folder_id = folder.id or all
:search(query)  # ILIKE on filename, title, alt_text, description
:with_tag(tag)  # WHERE tag = ANY(tags)
```

**Allowed Content Types**:
```ruby
# Images
'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'

# Documents
'application/pdf',
'application/msword',
'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
'application/vnd.ms-excel',
'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'

# Text
'text/plain', 'text/csv'
```

**Methods**:
```ruby
human_file_size  # Formatted size (e.g., "2.5 MB")
dimensions  # "[width]x[height]" string
url  # Serves file via Rails
variant_url(:thumb)  # Image variant URL
image?  # Check if image
usage_count  # How many times used
```

#### Pwb::MediaFolder
**Table**: `pwb_media_folders`

**Columns**:
```
- name: String
- slug: String
- path: String (full path, e.g., "Branding/Logos")
- parent_id: Bigint (FK, for hierarchy)
- website_id: Bigint (FK, tenant scoping)
```

**Indexes**:
```
- Unique: (website_id, slug)
- (website_id, parent_id) - Hierarchy navigation
- (parent_id) - Orphan detection
```

**Associations**:
- `belongs_to :website`
- `belongs_to :parent, class_name: 'Pwb::MediaFolder'` (optional)
- `has_many :children, class_name: 'Pwb::MediaFolder', foreign_key: :parent_id`
- `has_many :media`

**Methods**:
```ruby
empty?  # No media or children
ordered  # Sort by name
root  # Folders with no parent
```

### Controller Flow

**Index** (Gallery View):
- Lists media in folder (or root)
- Search via query param
- Pagination: 24 per page
- Responds to HTML and JSON

**Pagination Response**:
```json
{
  items: [
    {
      id, filename, title, alt_text, description,
      content_type, byte_size, human_size,
      width, height, dimensions,
      url, thumbnail_url, is_image,
      folder_id, tags, created_at,
      usage_count
    }
  ],
  pagination: {
    current_page, total_pages, total_count
  }
}
```

**Create** (Upload):
- Accepts single or multiple files
- Via `params[:files]` or `params[:file]`
- Sets `source_type: 'upload'`
- Returns results with errors
- Responds to HTML (redirect) and JSON

**Edit**:
- Update: title, alt_text, description, caption, folder_id, tags
- Returns JSON for AJAX

**Destroy**:
- Delete single media
- HTML: redirect, JSON: 204 No Content

**Bulk Operations**:
- `bulk_destroy(ids)` - Delete multiple
- `bulk_move(ids, folder_id)` - Move to folder

**Folder Management**:
- `folders` - List all folders (JSON response)
- `create_folder` - Create new folder
- `update_folder` - Rename/update
- `destroy_folder` - Delete if empty

**Folder Response**:
```json
{
  id, name, slug, path, parent_id,
  media_count,
  children: [...]
}
```

### Statistics
```ruby
@stats = {
  total_files: Media count,
  total_images: Images count,
  total_documents: Documents count,
  total_folders: Folders count,
  storage_used: Sum of byte_size (bytes)
}
```

### Gaps/Areas Needing Work

1. **Storage Limits**: No per-website storage quota enforcement
2. **Batch Processing**: No bulk edit/tag operations
3. **Image Optimization**: No automatic image compression/optimization
4. **Variants**: No built-in image variant management UI
5. **Usage Tracking**: usage_count tracked but not displayed in admin
6. **Smart Folders**: No AI-based organization (by type, date, etc.)
7. **Duplicate Detection**: No ability to find duplicate images
8. **Digital Asset Management**: No DAM workflow (approval, metadata enrichment)
9. **Collaboration**: No comments/notes on media items
10. **Cleanup**: No automated cleanup of unused media

---

## 6. ONBOARDING

### Controllers
- **Onboarding**: `/app/controllers/site_admin/onboarding_controller.rb`

### Routes Structure
```
/site_admin/onboarding          # Show current step
/site_admin/onboarding/:step    # Show specific step
POST /site_admin/onboarding/:step       # Update step
POST /site_admin/onboarding/:step/skip  # Skip step (3 only)
GET /site_admin/onboarding/complete     # Completion view
POST /site_admin/onboarding/restart     # Reset onboarding
```

### Onboarding Steps

**Defined in Controller**:
```ruby
STEPS = {
  1 => { name: 'welcome', title: 'Welcome', description: 'Get started' },
  2 => { name: 'profile', title: 'Your Profile', description: 'Set up agency' },
  3 => { name: 'property', title: 'First Property', description: 'Add listing' },
  4 => { name: 'theme', title: 'Choose Theme', description: 'Customize look' },
  5 => { name: 'complete', title: 'All Done!', description: 'Ready to go' }
}
```

**Step Flow**:

**Step 1: Welcome**
- Static introduction page
- POST advances to step 2

**Step 2: Profile (Agency Setup)**
- Edit agency profile
- Permittable fields:
  ```ruby
  :display_name, :email_primary, :phone_number_primary, :company_name
  ```
- Currency selection (maps to `website.default_currency`)
- Validates: Agency fields required
- POST advances to step 3 on success

**Step 3: Property (Optional)**
- Create first property
- Property form with fields:
  ```ruby
  :reference, :title, :description,
  :price_sale_current_cents, :price_rental_monthly_current_cents,
  :bedrooms, :bathrooms, :plot_size, :constructed_size,
  :street_address, :city, :postal_code, :country,
  :property_type_key
  ```
- Can be skipped (only step 3 is skippable)
- POST advances to step 4 on success or skip

**Step 4: Theme Selection**
- Dropdown of available themes (from `website.accessible_theme_names`)
- Shows current theme selection
- Updates `website.theme_name`
- POST advances to step 5

**Step 5: Complete**
- Summary page with stats:
  ```ruby
  {
    properties: website.realty_assets.count,
    pages: website.pages.count,
    theme: website.theme_name.titleize
  }
  ```
- Marks onboarding complete

### User Progress Tracking

**User Model Fields**:
- `onboarding_step: Integer` - Current step (1-5)
- `site_admin_onboarding_completed_at: DateTime` - Completion timestamp

**Completion Logic**:
```ruby
def onboarding_completed?
  current_user.site_admin_onboarding_completed_at.present?
end

def complete_onboarding!
  current_user.update!(
    site_admin_onboarding_completed_at: Time.current,
    onboarding_step: MAX_STEP
  )
  # Activate user if in onboarding state (may_activate? check)
  current_user.activate! if current_user.respond_to?(:may_activate?) && current_user.may_activate?
end
```

**Auto-Redirect**:
- If onboarding complete and no explicit step param, redirect to dashboard

### Restart
- Reset to step 1
- Clear completion timestamp
- Allows re-running full flow

### Views
- `/app/views/site_admin/onboarding/welcome.html.erb`
- `/app/views/site_admin/onboarding/profile.html.erb`
- `/app/views/site_admin/onboarding/property.html.erb`
- `/app/views/site_admin/onboarding/theme.html.erb`
- `/app/views/site_admin/onboarding/complete.html.erb`

### Gaps/Areas Needing Work

1. **Conditional Steps**: No branching based on user answers
2. **Multi-Language Setup**: Doesn't configure multiple locales
3. **Domain Setup**: Doesn't include domain/CNAME steps
4. **Payment Setup**: No payment method entry during onboarding
5. **Team Invite**: No ability to invite team members
6. **Progress Bar**: No visual progress indicator mentioned
7. **Skip Logic**: All steps required except property
8. **Context Switching**: Can't go back to previous steps
9. **Email Verification**: Doesn't verify agency email
10. **Plan Selection**: Fixed to default plan; no plan choice during onboarding

---

## 7. SUBSCRIPTIONS & PLANS

### Models

#### Pwb::Plan
**Table**: `pwb_plans`

**Columns**:
```
Pricing:
  - price_cents: Integer (default 0)
  - price_currency: String (default 'USD')
  - billing_interval: String (enum: 'month' | 'year')
  
Limits:
  - property_limit: Integer (null = unlimited)
  - user_limit: Integer (null = unlimited)
  - trial_days: Integer (default 14)
  
Features:
  - features: JSONB Array<String> (feature keys)
  
Metadata:
  - name: String (internal, unique)
  - slug: String (unique, URL-friendly)
  - display_name: String (public)
  - description: Text
  
Status:
  - active: Boolean (can be subscribed)
  - public: Boolean (shown in pricing page)
  - position: Integer (sort order)
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Indexes**:
- Unique: `(slug)`
- Composite: `(active, position)` - Displayed plans

**Scopes**:
```ruby
:active              # WHERE active = true
:public_plans        # WHERE public = true
:ordered             # ORDER BY position
:for_display         # active.public_plans.ordered
```

**Feature Keys** (Defined in Code):
```ruby
FEATURES = {
  basic_themes: 'Access to basic themes',
  premium_themes: 'Access to premium themes',
  analytics: 'Website analytics dashboard',
  custom_domain: 'Use your own custom domain',
  api_access: 'API access for integrations',
  white_label: 'Remove PropertyWebBuilder branding',
  priority_support: 'Priority email support',
  dedicated_support: 'Dedicated account manager'
}.freeze
```

**Methods**:
```ruby
has_feature?(feature_key)    # Boolean
enabled_features             # [{ key:, description: }]
unlimited_properties?        # property_limit.nil?
unlimited_users?             # user_limit.nil?
formatted_price              # "$29/month" | "€290/year"
monthly_price_cents          # Normalized for annual plans
self.find_by_slug(slug)      # Lookup helper
self.default_plan            # Fallback (starter or first)
```

#### Pwb::Subscription
**Table**: `pwb_subscriptions`

**Columns**:
```
Status:
  - status: String (enum: trialing|active|past_due|canceled|expired)
  
Trial Management:
  - trial_ends_at: DateTime
  
Billing Period:
  - current_period_starts_at: DateTime
  - current_period_ends_at: DateTime
  
Cancellation:
  - canceled_at: DateTime
  - cancel_at_period_end: Boolean
  
External Integration:
  - external_id: String (Stripe/payment provider ID, unique if not null)
  - external_customer_id: String (Stripe customer)
  - external_provider: String (e.g., 'stripe')
  
Metadata:
  - metadata: JSONB (custom data)
  
Relationships:
  - website_id: Bigint (FK, unique, one per website)
  - plan_id: Bigint (FK)
  
Timestamps:
  - created_at, updated_at: DateTime
```

**Indexes**:
```
- Unique: (website_id) - One subscription per website
- Unique: (external_id) where external_id IS NOT NULL
- (status) - Status queries
- (trial_ends_at) - Trial expiry checks
- (current_period_ends_at) - Billing period queries
```

**Scopes**:
```ruby
:trialing                   # WHERE status = 'trialing'
:active_subscriptions       # WHERE status = 'active'
:past_due                   # WHERE status = 'past_due'
:canceled                   # WHERE status = 'canceled'
:expired                    # WHERE status = 'expired'
:active_or_trialing         # WHERE status IN ('active', 'trialing')
:expiring_soon(days=3)      # WHERE trial_ends_at <= days.days.from_now
:trial_expired              # trialing AND trial_ends_at < now
```

**AASM State Machine**:
```
Initial: :trialing

Transitions:
  trialing -> active (via :activate)
  trialing -> expired (via :expire_trial, if trial_ended?)
  active -> past_due (via :mark_past_due)
  active/trialing/past_due -> canceled (via :cancel)
  canceled/past_due -> expired (via :expire)
  canceled/expired -> active (via :reactivate)
```

**Event Callbacks**:
- `:activate` → log_event('activated'), set_billing_period
- `:expire_trial` → log_event('trial_expired')
- `:mark_past_due` → log_event('past_due')
- `:cancel` → update(canceled_at), log_event('canceled')
- `:expire` → log_event('expired')
- `:reactivate` → update(canceled_at: nil), log_event('reactivated')

**Key Methods**:
```ruby
in_good_standing?           # trialing? || active?
allows_access?              # trialing? || active? || past_due?
trial_ended?                # trial_ends_at < now
trial_days_remaining        # Days left or nil if not trialing
trial_ending_soon?(days: 3) # trial_days_remaining <= days
within_property_limit?(count)  # Check against plan.property_limit
within_user_limit?(count)      # Check against plan.user_limit
remaining_properties        # plan.property_limit - current_count
has_feature?(feature_key)   # Delegates to plan
change_plan(new_plan)       # Switch to different plan + logs
start_trial(days: nil)      # Initialize trial period
```

#### Pwb::SubscriptionEvent
**Table**: `pwb_subscription_events`

**Purpose**: Audit trail for subscription state changes

**Columns**:
```
- subscription_id: FK
- event_type: String (e.g., 'activated', 'canceled', 'trial_expired')
- metadata: JSONB (plan_id, plan_slug, status, old_plan_id, etc.)
- created_at
```

**Logged Events**:
- `activated` - Subscription moved to active
- `trial_started` - Trial initiated
- `trial_expired` - Trial ended without payment
- `past_due` - Payment failed
- `canceled` - User cancelled
- `expired` - Period ended after cancellation
- `reactivated` - Re-subscribed after cancellation
- `plan_changed` - Plan upgraded/downgraded

### Subscription Gating Logic

**Dashboard Display** (SiteAdmin):
```ruby
@subscription = Pwb::Subscription.find_by(website_id: current_website.id)
@subscription_info = {
  status, plan_name, plan_price, trial_days_remaining,
  trial_ending_soon, in_good_standing, current_period_ends_at,
  property_limit, remaining_properties, features
}
```

**Feature Gating** (In Controllers):
```ruby
if subscription.has_feature?('analytics')
  # Show analytics dashboard
end

if subscription.within_property_limit?(count + 1)
  # Allow adding new property
else
  # Show upgrade prompt
end
```

**Access Control**:
```ruby
def allows_access?
  # true for: trialing, active, past_due (grace period)
  # false for: canceled, expired
end
```

### Billing Controller
- Located: `/app/controllers/site_admin/billing_controller.rb`
- Likely handles:
  - Plan upgrade/downgrade
  - Billing history
  - Payment method management
  - Invoice display

### Gaps/Areas Needing Work

1. **Plan Customization**: Can't create custom plans for enterprise
2. **Proration**: No automatic proration for mid-cycle upgrades
3. **Add-Ons**: No ability to add additional features beyond plan
4. **Volume Discounts**: No multi-year or quantity discounts
5. **Free Trial Management**: No admin UI to extend trials
6. **Payment Retry**: No automatic retry logic visible
7. **Churn Prevention**: No "win-back" pricing or incentives
8. **MRR Tracking**: No revenue metrics in admin
9. **Dunning Management**: No payment failure escalation workflow
10. **Seat-Based Pricing**: property_limit and user_limit but no seat management UI

---

## 8. DATABASE SCHEMA OVERVIEW

### Key Tables

**Tenant Scoping**:
- All main tables have `website_id` FK (except shared system tables)
- Multi-tenant queries always include `WHERE website_id = ?`

**View Models**:
- `pwb_properties` (materialized view) - Property search index
- Refreshed after writes to RealtyAsset, SaleListing, RentalListing

**JSON/JSONB Columns**:
- `pwb_websites.configuration` - Site config
- `pwb_websites.admin_config` - Admin settings
- `pwb_websites.social_media` - Social links
- `pwb_websites.style_variables_for_theme` - CSS variables
- `pwb_pages.translations` - Mobility translations
- `pwb_realty_assets.translations` - Mobility translations
- `pwb_sale_listings.translations` - Mobility translations
- `pwb_rental_listings.translations` - Mobility translations
- `pwb_subscriptions.metadata` - Custom sub data
- `pwb_plans.features` - Feature array
- `pwb_media.tags` - String array

**ActiveStorage**:
- Managed through `active_storage_attachments` and `active_storage_blobs`
- Used for: property photos, media library files, logos, etc.

### Connection to Plans/Features

**Plan Enforcement Points**:
1. RealtyAsset#validate - `within_subscription_property_limit`
2. Dashboard display - Show remaining properties
3. Feature gates - Check `has_feature?` in controllers/views

---

## 9. ADMIN AUTHENTICATION & AUTHORIZATION

### Admin Controllers Base
- `SiteAdminController` - Requires admin access to current website
- `TenantAdminController` - Requires platform admin access

### Typical Checks
- `current_user` - Authenticated user
- `current_website` - Scoped to admin's website
- `require_admin!` - (before_action) - User must be admin

### Onboarding Permission
- Skips `require_admin!` for onboarding flow
- Uses `ensure_can_access_onboarding` instead

---

## 10. FRONTEND TECHNOLOGY

### Templates
- **ERB templates** - Server-rendered
- **Tailwind CSS** - All styling
- **Stimulus.js** - JavaScript interactions (drag-drop, modals, forms)
- **No Vue.js** - Deprecated (see app/frontend/DEPRECATED.md)
- **No Bootstrap** - Replaced with Tailwind

### Key Components
- Pagy gem - Pagination (used throughout admin)
- Form helpers - Rails form_with
- Partials - Shared components in `/app/views/site_admin/shared/`

---

## 11. MODELS RELATIONSHIP DIAGRAM

```
Website (tenant root)
  ├── Agency (1:1) - Company details
  ├── Subscription (1:1) - Billing status
  │   └── Plan (1:N)
  ├── RealtyAsset (1:N) - Properties
  │   ├── SaleListing (1:N)
  │   ├── RentalListing (1:N)
  │   └── PropPhoto (1:N)
  ├── Page (1:N) - CMS pages
  │   ├── PagePart (1:N)
  │   └── Content (through PageContent)
  ├── Message (1:N) - Inquiries
  │   └── Contact (optional)
  ├── Contact (1:N) - Prospects
  │   ├── Address (1:2 - primary/secondary)
  │   └── Message (1:N)
  ├── Media (1:N) - Files
  │   └── MediaFolder (1:N)
  │       └── MediaFolder (parent_id - hierarchy)
  ├── User (through UserMembership)
  └── ListedProperty (view) - Property search index

ListedProperty (materialized view)
  ← Joins: RealtyAsset + SaleListing + RentalListing
```

---

## 12. IMPLEMENTATION PATTERNS

### Multi-Tenant Scoping Pattern
```ruby
# In controllers
scope = Model.where(website_id: current_website.id)

# In views
<%= current_website.name %>

# Contexts
Pwb::Current.website = @website
```

### Materialized View Refresh
```ruby
# After write operations
include RefreshesPropertiesView

# Automatically schedules async refresh
after_save :refresh_property_view
```

### Pagination Pattern
```ruby
@pagy, @records = pagy(scope, limit: 25)

# In view
<%= render 'pagy/nav', pagy: @pagy %>
```

### Feature Gating Pattern
```ruby
if subscription.has_feature?(:custom_domain)
  # Show custom domain UI
end
```

### Transaction Safety
```ruby
ActiveRecord::Base.transaction do
  @prop.update!(asset_params)
  @prop.sale_listings.first_or_initialize.update!(params)
end
```

---

## 13. MISSING/GAP ANALYSIS

### Critical Gaps
1. **Bulk Operations**: No bulk edit, move, or delete of properties
2. **Data Import**: No CSV/Excel import UI
3. **Audit Logging**: Limited to auth audit, not content changes
4. **Soft Delete**: No deletion/archival strategy
5. **Change History**: No version control for page/property edits

### Feature Gaps
1. **Workflow**: No approval/review workflows
2. **Automation**: No rules, triggers, or scheduled actions
3. **Analytics**: Limited to dashboard stats; no advanced reporting
4. **Team Collaboration**: No task assignment, comments, or mentions
5. **Integrations**: No webhook or API UI for custom integrations
6. **Content Duplication**: No ability to clone pages or properties
7. **Permissions**: Binary admin/non-admin; no role-based access
8. **Notifications**: Limited to email; no in-app notification system

### UI/UX Gaps
1. **Progress Indicators**: No loading states or progress bars
2. **Empty States**: Assumed but not documented
3. **Confirmation Dialogs**: Standard Rails redirects; no JS confirmations
4. **Accessibility**: Unknown WCAG compliance status
5. **Mobile Admin**: Unknown if mobile-responsive

---

## 14. FILE LOCATIONS SUMMARY

### Key Controllers
```
/app/controllers/site_admin/
  ├── dashboard_controller.rb
  ├── props_controller.rb
  ├── messages_controller.rb
  ├── inbox_controller.rb
  ├── pages_controller.rb
  ├── media_library_controller.rb
  ├── onboarding_controller.rb
  └── [many others]

/app/controllers/tenant_admin/
  ├── dashboard_controller.rb
  ├── subscriptions_controller.rb
  └── [system admin features]
```

### Key Models
```
/app/models/pwb/
  ├── subscription.rb
  ├── plan.rb
  ├── website.rb
  ├── agency.rb
  ├── realty_asset.rb
  ├── sale_listing.rb
  ├── rental_listing.rb
  ├── listed_property.rb (view)
  ├── message.rb
  ├── contact.rb
  ├── page.rb
  ├── page_part.rb
  ├── media.rb
  └── media_folder.rb

/app/models/pwb_tenant/
  ├── [tenant-scoped query versions of main models]
```

### Key Views
```
/app/views/site_admin/
  ├── dashboard/index.html.erb
  ├── props/
  │   ├── index.html.erb (list)
  │   ├── show.html.erb (detail)
  │   ├── edit_general.html.erb
  │   ├── edit_text.html.erb
  │   ├── edit_sale_rental.html.erb
  │   ├── edit_location.html.erb
  │   ├── edit_labels.html.erb
  │   └── edit_photos.html.erb
  ├── messages/show.html.erb
  ├── inbox/
  │   ├── index.html.erb (contact list)
  │   └── show.html.erb (conversation)
  ├── pages/
  │   ├── index.html.erb (list)
  │   ├── edit.html.erb (drag-drop parts)
  │   └── settings.html.erb (metadata)
  ├── media_library/
  │   ├── index.html.erb (gallery)
  │   └── edit.html.erb (metadata)
  └── onboarding/
      ├── welcome.html.erb
      ├── profile.html.erb
      ├── property.html.erb
      ├── theme.html.erb
      └── complete.html.erb
```

### Database
```
/db/schema.rb                    # Full schema
/db/migrate/                     # Migration files (90+ migrations)
```

---

## 15. NOTES FOR IMPLEMENTATION

### When Adding Features, Consider:

1. **Multi-Tenancy**:
   - Always scope by `website_id`
   - Test cross-tenant isolation
   - Use Pwb::Current.website in request context

2. **Performance**:
   - Use materialized views for complex searches
   - Eager load associations to avoid N+1
   - Add database indexes for filtered queries

3. **Internationalization**:
   - Use Mobility for multi-language content
   - Support available locales via website config

4. **Money Handling**:
   - Use Monetize gem for prices
   - Store in cents + currency separately
   - Support website's default_currency

5. **File Uploads**:
   - Use ActiveStorage with Rails conventions
   - Support multiple storage backends (disk, R2)
   - Track file metadata (size, dimensions)

6. **State Management**:
   - Use AASM for complex workflows (see Subscription)
   - Log state changes in audit tables
   - Handle idempotent transitions

7. **Admin Security**:
   - Require authentication (`require_admin!`)
   - Log sensitive actions
   - Use Rails CSRF protection

---

## Conclusion

The PropertyWebBuilder admin system is a comprehensive multi-tenant Rails application with:

- **Well-organized controllers** for each admin section
- **Normalized database schema** with materialized views for performance
- **Strong tenant isolation** via website_id scoping
- **Flexible translation system** via Mobility
- **Subscription-based plan enforcement**
- **Modern frontend** with Tailwind CSS and Stimulus

**Ready for**: Adding new features, improving UX, implementing automation, and expanding admin capabilities without violating tenant isolation or breaking existing functionality.

