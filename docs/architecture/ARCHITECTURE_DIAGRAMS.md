# PropertyWebBuilder Architecture Diagrams

## 1. Property Model Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROPERTY MANAGEMENT SYSTEM                    │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────┐
│  Pwb::RealtyAsset    │  (Physical Property - Source of Truth)
│  UUID Primary Key    │
├──────────────────────┤
│ Location:            │
│  - street_address    │
│  - city, region      │
│  - postal_code       │
│  - country           │
│  - latitude/longitude│
│                      │
│ Dimensions:          │
│  - constructed_area  │
│  - plot_area         │
│  - year_construction │
│                      │
│ Rooms:               │
│  - count_bedrooms    │
│  - count_bathrooms   │
│  - count_toilets     │
│  - count_garages     │
│                      │
│ Energy:              │
│  - energy_rating     │
│  - energy_performance│
│                      │
│ Marketing:           │
│  - title (trans)     │
│  - description (trans)│
│  - reference         │
│  - slug              │
│                      │
│ Identifiers:         │
│  - prop_type_key     │
│  - prop_state_key    │
│  - prop_origin_key   │
└──────────────────────┘
          │
          │ has_many (one property, multiple transactions over time)
          │
    ┌─────┴──────┬──────────────────────┐
    │             │                      │
    ▼             ▼                      ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│   Pwb::SaleListing           │  │  Pwb::RentalListing          │
│   UUID Primary Key           │  │  UUID Primary Key            │
│   (Sale Transaction)         │  │  (Rental Transaction)        │
├──────────────────────────────┤  ├──────────────────────────────┤
│ Marketing:                   │  │ Marketing:                   │
│  - title (trans)             │  │  - title (trans)             │
│  - description (trans)       │  │  - description (trans)       │
│  - seo_title (trans)         │  │  - seo_title (trans)         │
│  - meta_description (trans)  │  │  - meta_description (trans)  │
│                              │  │                              │
│ Pricing:                     │  │ Pricing:                     │
│  - price_sale_current_cents  │  │  - price_rental_monthly_cur  │
│  - price_sale_currency       │  │  - price_rental_low_season   │
│  - commission_cents          │  │  - price_rental_high_season  │
│                              │  │  - currency                  │
│ Status:                      │  │                              │
│  - active (UNIQUE per asset) │  │ Rental Type:                 │
│  - visible                   │  │  - for_rent_short_term       │
│  - reserved                  │  │  - for_rent_long_term        │
│  - furnished                 │  │                              │
│  - highlighted               │  │ Status:                      │
│  - archived                  │  │  - active (UNIQUE per asset) │
│  - noindex (SEO control)     │  │  - visible                   │
└──────────────────────────────┘  │  - reserved                  │
                                   │  - furnished                 │
                                   │  - highlighted               │
                                   │  - archived                  │
                                   │  - noindex                   │
                                   └──────────────────────────────┘

Key Constraints:
┌────────────────────────────────────────────────────────────────┐
│  UNIQUE (realty_asset_id, active) WHERE active = true          │
│  = Only ONE active listing per property per type               │
│  = Allows multiple listings over time (history)                │
└────────────────────────────────────────────────────────────────┘


Associated Models:
┌──────────────────────┐      ┌──────────────────────┐
│  Pwb::PropPhoto      │      │   Pwb::Feature       │
│  (has_one_attached   │      │   (Property Amenity) │
│   image via AS)      │      │                      │
│                      │      │ - feature_key        │
│ - sort_order         │      │ - realty_asset_id    │
│ - description        │      │                      │
│ - external_url       │      │ Examples:            │
│                      │      │  - pool              │
│ Example Sequence:    │      │  - garden            │
│  [Photo 1]           │      │  - garage            │
│  [Photo 2]           │      │  - elevator          │
│  [Photo 3]           │      └──────────────────────┘
└──────────────────────┘


Materialized View (Read-Only, Query-Optimized):
┌────────────────────────────────────────────────────────────────┐
│         Pwb::ListedProperty (pwb_properties view)               │
│         Denormalized combination of:                            │
│         RealtyAsset + Active SaleListing + Active RentalListing│
├────────────────────────────────────────────────────────────────┤
│ Contains ALL realty_asset fields PLUS:                         │
│  - for_sale (computed from listing)                            │
│  - for_rent (computed from listing)                            │
│  - price_sale_current_cents (from SaleListing)                 │
│  - price_rental_monthly_current_cents (from RentalListing)     │
│  - visible (either listing visible)                            │
│  - highlighted, reserved, furnished, currency (computed)       │
│                                                                 │
│ Purpose: Single table query without JOINs                      │
│ Usage: Frontend property search/display                        │
│ Note: READ-ONLY - refresh() after creating/updating properties │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. Content Management System

```
┌─────────────────────────────────────────────────────────────────┐
│                  CONTENT MANAGEMENT SYSTEM                       │
└─────────────────────────────────────────────────────────────────┘

Website (Tenant)
│
├─ Pages
│  │
│  ├─ About Us
│  ├─ Contact
│  ├─ Services
│  └─ Properties
│
└─ Content Blocks (Reusable)
   │
   ├─ Hero Section
   ├─ Testimonials
   ├─ CTA Buttons
   └─ Feature List


Detailed Data Model:
┌──────────────────────┐
│   Pwb::Page          │
│   (CMS Page)         │
├──────────────────────┤
│ Identifiers:         │
│  - slug (unique)     │
│  - setup_id          │
│                      │
│ Display:             │
│  - visible           │
│  - show_in_top_nav   │
│  - show_in_footer    │
│  - sort_order_*      │
│                      │
│ SEO:                 │
│  - seo_title         │
│  - meta_description  │
│                      │
│ Content (Translatable)
│  - raw_html (LIQUID) │
│  - page_title        │
│  - link_title        │
│                      │
│ Config:              │
│  - details (JSON)    │
│  - flags (bitwise)   │
│                      │
│ Relations:           │
│  - has_many :pages   │
│  - has_many :content │
│  - has_many :links   │
└──────────────────────┘
        │
        │ many-to-many
        │
        ▼
┌──────────────────────────────┐
│  Pwb::PageContent            │
│  (Join Table)                │
├──────────────────────────────┤
│ - page_id                    │
│ - content_id                 │
│ - sort_order                 │
│ - visible_on_page            │
│ - page_part_key              │
│ - label (admin only)         │
│ - is_rails_part              │
└──────────────────────────────┘
        │
        │ belongs_to
        │
        ▼
┌──────────────────────┐
│   Pwb::Content       │
│   (Content Block)    │
├──────────────────────┤
│ - key (unique)       │
│ - page_part_key      │
│ - sort_order         │
│                      │
│ Content (Trans):     │
│  - raw (HTML)        │
│                      │
│ Config:              │
│  - input_type        │
│  - tag               │
│  - section_key       │
│  - target_url        │
│  - status            │
│                      │
│ Relations:           │
│  - has_many :photos  │
│  - has_many :pages   │
└──────────────────────┘
        │
        │ has_many
        │
        ▼
┌──────────────────────┐
│ Pwb::ContentPhoto    │
│ (Block Image)        │
├──────────────────────┤
│ - block_key          │
│ - sort_order         │
│ - description        │
│ - external_url       │
│                      │
│ ActiveStorage:       │
│  has_one_attached    │
│    :image            │
│                      │
│ Methods:             │
│ - optimized_url()    │
│ - variant_url()      │
└──────────────────────┘


Example Page Structure:
┌─────────────────────────────────────────┐
│ Page: "About Us"                        │
│ ├─ Slug: about-us                       │
│ ├─ Visible: true                        │
│ └─ Content Blocks:                      │
│    │                                    │
│    ├─ [1] Hero Block                    │
│    │    ├─ Content: "Company Story"     │
│    │    ├─ Photo: Hero Image            │
│    │    └─ Visible: true                │
│    │                                    │
│    ├─ [2] Team Block                    │
│    │    ├─ Content: "Meet Our Team"     │
│    │    ├─ Photos: [Team1, Team2, ...]  │
│    │    └─ Visible: true                │
│    │                                    │
│    └─ [3] Contact CTA                   │
│         ├─ Content: "Get in Touch"      │
│         ├─ Link: /contact               │
│         └─ Visible: true                │
└─────────────────────────────────────────┘
```

---

## 3. Enquiries & Contacts Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              VISITOR ENQUIRY & CONTACT TRACKING                  │
└─────────────────────────────────────────────────────────────────┘

Website Visitor
│
├─ Fills Contact Form
│  └─ Name, Email, Message
│
▼
┌──────────────────────────────┐
│   Pwb::Message               │
│   (Form Submission)          │
├──────────────────────────────┤
│ From Visitor:                │
│  - title (subject)           │
│  - content (message)         │
│  - origin_email              │
│                              │
│ Visitor Metadata:            │
│  - origin_ip                 │
│  - user_agent                │
│  - host                      │
│  - url (referrer page)       │
│  - locale (visitor language) │
│  - latitude, longitude       │
│                              │
│ Delivery Tracking:           │
│  - delivery_email (to)       │
│  - delivery_success          │
│  - delivered_at              │
│  - delivery_error            │
│                              │
│ Relations:                   │
│  - belongs_to :contact       │
│  - belongs_to :website       │
└──────────────────────────────┘
        │
        │ may link to
        │
        ▼
┌──────────────────────────────┐
│   Pwb::Contact               │
│   (Visitor/Lead Record)      │
├──────────────────────────────┤
│ Personal Info:               │
│  - first_name                │
│  - last_name                 │
│  - title (Mr, Mrs)           │
│  - nationality               │
│                              │
│ Contact Info:                │
│  - primary_email             │
│  - other_email               │
│  - primary_phone_number      │
│  - other_phone_number        │
│  - fax                       │
│                              │
│ Addresses:                   │
│  - primary_address_id (FK)   │
│  - secondary_address_id (FK) │
│                              │
│ Social:                      │
│  - twitter_id                │
│  - facebook_id               │
│  - linkedin_id               │
│  - skype_id                  │
│                              │
│ Identification:              │
│  - documentation_type        │
│  - documentation_id          │
│                              │
│ Meta:                        │
│  - details (JSON)            │
│  - flags (bitwise)           │
│  - user_id (if registered)   │
│                              │
│ Relations:                   │
│  - has_many :messages        │
│  - belongs_to :website       │
│  - belongs_to :primary_addr  │
│  - belongs_to :secondary_addr│
│  - belongs_to :user          │
└──────────────────────────────┘
        │
        │ may reference
        │
        ▼
┌──────────────────────────────┐
│   Pwb::Address               │
│   (Contact Address)          │
├──────────────────────────────┤
│ - street_address             │
│ - street_number              │
│ - city                       │
│ - region                     │
│ - postal_code                │
│ - country                    │
│ - latitude, longitude        │
└──────────────────────────────┘


Notification Flow (Optional):
┌──────────────────┐
│  Message Sent    │
└────────┬─────────┘
         │
         ├─ Email to website admin
         │  (email_for_general_contact_form)
         │
         └─ Ntfy Notification (optional)
            IF ntfy_enabled AND ntfy_notify_inquiries
            └─ Push notification to admin
```

---

## 4. Media Library System

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEDIA LIBRARY SYSTEM                          │
└─────────────────────────────────────────────────────────────────┘

Hierarchical Structure:
┌────────────────────────┐
│   Pwb::MediaFolder     │
│   (Root)               │
├────────────────────────┤
│ - name                 │
│ - slug                 │
│ - parent_id (NULL)     │
│ - sort_order           │
│ - website_id           │
└────────────────────────┘
        │
        │ has_many :children
        │
        ├─ ┌────────────────────┐
        │  │  Marketing         │
        │  ├────────────────────┤
        │  │ - parent_id (ROOT) │
        │  └────────────────────┘
        │         │
        │         ├─ ┌──────────────┐
        │         │  │ Property Ads │
        │         │  └──────────────┘
        │         │
        │         └─ ┌──────────────┐
        │            │ Social Media │
        │            └──────────────┘
        │
        ├─ ┌────────────────────┐
        │  │  Property Images   │
        │  └────────────────────┘
        │
        └─ ┌────────────────────┐
           │  Documents         │
           └────────────────────┘


Each Folder Contains Media Files:
┌──────────────────────────────┐
│      Pwb::Media              │
│      (Individual File)        │
├──────────────────────────────┤
│ File Metadata:               │
│  - filename                  │
│  - content_type              │
│  - byte_size                 │
│  - checksum                  │
│                              │
│ Image Specific:              │
│  - width, height             │
│  - alt_text                  │
│                              │
│ Organizational:              │
│  - title                     │
│  - description               │
│  - caption                   │
│  - tags (array)              │
│  - folder_id                 │
│                              │
│ ActiveStorage:               │
│  - has_one_attached :file    │
│                              │
│ Usage Tracking:              │
│  - usage_count               │
│  - last_used_at              │
│                              │
│ Source:                      │
│  - source_type (upload/etc)  │
│  - source_url (if external)  │
│                              │
│ Relations:                   │
│  - belongs_to :folder        │
│  - belongs_to :website       │
└──────────────────────────────┘


Supported File Types:
┌──────────────────────────────────┐
│ Images:                          │
│  - JPEG, PNG, GIF, WebP, SVG     │
│                                  │
│ Documents:                       │
│  - PDF, Word, Excel, Text, CSV   │
│                                  │
│ Max File Size: 25 MB             │
└──────────────────────────────────┘


URL Generation:
┌────────────────────────────────────────────┐
│ Original File:                             │
│  media.url                                 │
│  => /rails/active_storage/blobs/...        │
│                                            │
│ Image Variants (on-demand):                │
│  media.variant_url(:thumb)   # 150x150     │
│  media.variant_url(:small)   # 300x300     │
│  media.variant_url(:medium)  # 600x600     │
│  media.variant_url(:large)   # 1200x1200   │
│                                            │
│ External URLs (if external_image_mode):    │
│  media.external_url                        │
└────────────────────────────────────────────┘
```

---

## 5. Translation & Localization

```
┌─────────────────────────────────────────────────────────────────┐
│              TRANSLATION & LOCALIZATION SYSTEM                   │
└─────────────────────────────────────────────────────────────────┘

Mobility Configuration:
┌────────────────────────────────────────────────────┐
│ Backend: Container (JSONB single column)           │
│ Column: translations                               │
│                                                    │
│ Supported Locales:                                 │
│  - en (English)                                    │
│  - es (Spanish)                                    │
│  - de (German)                                     │
│  - fr (French)                                     │
│  - nl (Dutch)                                      │
│  - pt (Portuguese)                                 │
│  - it (Italian)                                    │
│                                                    │
│ Fallback Chain:                                    │
│  es -> en, de -> en, fr -> en, ... (all to EN)   │
└────────────────────────────────────────────────────┘


Example Model with Translations:

Pwb::SaleListing
├─ Database Column: translations (JSONB)
│  Example:
│  {
│    "en": { "title": "Beautiful Apartment" },
│    "es": { "title": "Apartamento Hermoso" },
│    "de": { "title": "Wunderschöne Wohnung" }
│  }
│
└─ Translatable Attributes:
   - title
   - description
   - seo_title
   - meta_description


Accessing Translations:
┌────────────────────────────────────────────────┐
│ # Current locale                               │
│ listing.title              # => "Beautiful..." │
│ listing.title = "New Title"                    │
│                                                │
│ # Locale-specific accessors (auto-generated)  │
│ listing.title_en           # English           │
│ listing.title_es           # Spanish           │
│ listing.title_de           # German            │
│ ...                                            │
│                                                │
│ # Get all translations                        │
│ listing.translations       # => Full JSONB    │
│                                                │
│ # In views (ERB)                              │
│ <%= I18n.with_locale(:es) do %>              │
│   <%= listing.title %>                        │
│ <% end %>                                      │
│                                                │
│ # In controllers                              │
│ I18n.locale = :es                             │
│ listing.title                                  │
└────────────────────────────────────────────────┘


Models Using Translations:
┌─────────────────────────────────────────┐
│ Pwb::RealtyAsset                        │
│  - title, description                   │
│                                         │
│ Pwb::SaleListing                        │
│  - title, description, seo_title,       │
│    meta_description                     │
│                                         │
│ Pwb::RentalListing                      │
│  - title, description, seo_title,       │
│    meta_description                     │
│                                         │
│ Pwb::Content                            │
│  - raw (HTML content)                   │
│                                         │
│ Pwb::Page                               │
│  - raw_html, page_title, link_title     │
│                                         │
│ Pwb::FieldKey                           │
│  - label (property type name, etc)      │
│                                         │
│ Pwb::Link                               │
│  - link_title                           │
└─────────────────────────────────────────┘


FieldKey System (Dynamic Translation Keys):

┌──────────────────────────────────────────────────┐
│  Pwb::FieldKey                                   │
│  (Translation Keys for Dynamic Fields)           │
├──────────────────────────────────────────────────┤
│ - global_key (e.g., "property.types.apartment")  │
│ - tag (category: "property-types", etc)          │
│ - label (translatable display name)              │
│ - sort_order, visible, show_in_search_form       │
│                                                  │
│ UNIQUE Constraint:                               │
│   (pwb_website_id, global_key)                   │
│   => Can customize per tenant                    │
│                                                  │
│ Usage Example:                                   │
│                                                  │
│  # Get dropdown options for property type search │
│  options = Pwb::FieldKey.get_options_by_tag(    │
│    "property-types"                             │
│  )                                              │
│  # Returns [                                    │
│  #   OpenStruct.new(                           │
│  #     value: "property.types.apartment",       │
│  #     label: "Apartment"                      │
│  #   ),                                        │
│  #   OpenStruct.new(                           │
│  #     value: "property.types.house",          │
│  #     label: "House"                          │
│  #   ),                                        │
│  #   ...                                       │
│  # ]                                           │
│                                                  │
│  # Access label for a key                      │
│  field_key.display_label # => Translated label  │
└──────────────────────────────────────────────────┘
```

---

## 6. Multi-Tenancy Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│            MULTI-TENANT ARCHITECTURE (acts-as-tenant)            │
└─────────────────────────────────────────────────────────────────┘

Platform (Single Database, Multiple Websites)
│
├─ Website A (Tenant 1)
│  ├─ Properties
│  ├─ Users
│  ├─ Pages
│  └─ Contacts
│
├─ Website B (Tenant 2)
│  ├─ Properties
│  ├─ Users
│  ├─ Pages
│  └─ Contacts
│
└─ Website C (Tenant 3)
   ├─ Properties
   ├─ Users
   ├─ Pages
   └─ Contacts


Two Parallel Model Stacks:

┌─────────────────────────────┐    ┌──────────────────────────────┐
│  Pwb::* (Global Models)     │    │  PwbTenant::* (Scoped Models)│
├─────────────────────────────┤    ├──────────────────────────────┤
│ Not automatically scoped     │    │ Automatically scoped to      │
│ Have website_id column       │    │ current_website (via acTA)   │
│                             │    │                              │
│ Usage:                      │    │ Usage:                       │
│ - Console work              │    │ - Web requests               │
│ - Cross-tenant operations   │    │ - Controllers/views          │
│ - Background jobs           │    │ - Must scope manually        │
│                             │    │   in bg jobs                 │
│                             │    │                              │
│ Example:                    │    │ Example:                     │
│ Pwb::RealtyAsset.all        │    │ PwbTenant::RealtyAsset.all   │
│ => ALL properties           │    │ => Only current_website's    │
│                             │    │    properties                │
│ Pwb::RealtyAsset.where(     │    │                              │
│   website_id: website.id    │    │ PwbTenant::Contact.all       │
│ )                           │    │ => Only current_website's    │
│ => This website's props     │    │    contacts                  │
└─────────────────────────────┘    └──────────────────────────────┘


Tenancy Context Setting:

┌──────────────────────────────────────┐
│ In Web Request:                      │
│                                      │
│ Middleware sets:                     │
│ ActsAsTenant.current_tenant =        │
│   current_website                    │
│                                      │
│ Result: Automatic scoping in models  │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ In Background Job:                   │
│                                      │
│ Must explicitly scope:               │
│ ActsAsTenant.with_tenant(website) do │
│   RealtyAsset.all                    │
│   # => Only this website's assets    │
│ end                                  │
│                                      │
│ Or scope manually:                   │
│ Pwb::RealtyAsset.where(              │
│   website_id: website.id             │
│ )                                    │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│ In Rails Console:                    │
│                                      │
│ No automatic scoping!                │
│ Always scope manually:               │
│                                      │
│ website = Pwb::Website.first         │
│ website.realty_assets                │
│ # or                                 │
│ ActsAsTenant.with_tenant(website) do │
│   RealtyAsset.all                    │
│ end                                  │
└──────────────────────────────────────┘
```

---

## 7. Website Structure & Navigation

```
┌──────────────────────────────────────────────────────────────────┐
│         WEBSITE STRUCTURE & CONFIGURATION                        │
└──────────────────────────────────────────────────────────────────┘

Pwb::Website (Tenant Root)
│
├─ Identity
│  ├─ subdomain (e.g., "mybrokerage")
│  ├─ custom_domain (e.g., "mybrokerage.com")
│  └─ slug (internal identifier)
│
├─ Display & Theme
│  ├─ company_display_name
│  ├─ main_logo_url
│  ├─ favicon_url
│  ├─ theme_name (Tailwind theme)
│  ├─ selected_palette (color scheme)
│  ├─ style_variables_for_theme (CSS vars)
│  ├─ raw_css (custom CSS)
│  └─ dark_mode_setting (light_only/dark_only/auto)
│
├─ Localization
│  ├─ supported_locales (["en-UK", "es", ...])
│  ├─ default_client_locale
│  ├─ default_admin_locale
│  ├─ default_currency
│  ├─ supported_currencies
│  └─ default_area_unit (sqmt/sqft)
│
├─ Navigation & Content
│  ├─ has_many :pages (CMS pages)
│  ├─ has_many :links (navigation links)
│  │  ├─ Links.ordered_top_nav (header nav)
│  │  └─ Links.ordered_footer (footer nav)
│  ├─ has_many :contents (reusable blocks)
│  ├─ has_many :page_parts (page sections)
│  └─ has_many :page_contents (page+content joins)
│
├─ Property Data
│  ├─ has_many :realty_assets (physical properties)
│  ├─ has_many :sale_listings (through assets)
│  ├─ has_many :rental_listings (through assets)
│  ├─ has_many :listed_properties (materialized view)
│  └─ has_many :field_keys (dropdown values)
│
├─ Users & Access
│  ├─ has_many :users (admins)
│  ├─ has_many :members (through memberships)
│  └─ has_many :user_memberships
│
├─ Contact & Messages
│  ├─ has_many :contacts (leads/visitors)
│  ├─ has_many :messages (enquiries)
│  ├─ email_for_general_contact_form
│  ├─ email_for_property_contact_form
│  └─ contact_address_id (agency address)
│
├─ Media
│  ├─ has_many :media (files)
│  └─ has_many :media_folders (hierarchical)
│
├─ Integration
│  ├─ maps_api_key (Google Maps)
│  ├─ recaptcha_key
│  ├─ analytics_id & analytics_id_type
│  └─ ntfy_* (push notifications)
│
├─ Configuration (JSON)
│  ├─ admin_config (admin UI settings)
│  ├─ configuration (general settings)
│  ├─ styles_config (styling config)
│  ├─ search_config_buy/rent/landing (search filters)
│  └─ whitelabel_config
│
└─ Subscription
   ├─ has_one :subscription (billing)
   ├─ provisioning_state (live/provisioning/failed)
   └─ provisioning_completed_at


Navigation Structure Example:
┌──────────────────────────────────┐
│ Website Navigation               │
├──────────────────────────────────┤
│                                  │
│  TOP NAVIGATION:                 │
│  ├─ Home (parent: website)       │
│  ├─ Properties                   │
│  │  ├─ Buy (child link)          │
│  │  └─ Rent (child link)         │
│  ├─ About                        │
│  ├─ Contact                      │
│  └─ Blog (external link)         │
│                                  │
│  FOOTER NAVIGATION:              │
│  ├─ Privacy Policy               │
│  ├─ Terms of Service             │
│  ├─ FAQ                          │
│  └─ Contact (duplicate)          │
│                                  │
│  HIDDEN PAGES:                   │
│  ├─ Search Results (no nav)      │
│  └─ Property Detail (no nav)     │
│                                  │
└──────────────────────────────────┘
```

---

## 8. Admin Interface Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│               ADMIN INTERFACE ARCHITECTURE                        │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                   SITE ADMIN (Platform Level)                    │
│                   Path: /site_admin/*                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Controllers:                                                     │
│ ├─ websites_controller          - Create/manage websites         │
│ ├─ users_controller             - Platform users               │
│ ├─ plans_controller             - Subscription plans            │
│ ├─ subscriptions_controller     - Active subscriptions          │
│ ├─ subdomains_controller        - Subdomain allocation          │
│ ├─ billing_controller           - Billing & invoicing           │
│ ├─ analytics_controller         - Platform analytics            │
│ ├─ activity_logs_controller     - Audit trails                  │
│ └─ agency_controller            - Multi-agency support          │
│                                                                  │
│ Scope: All websites on platform                                 │
│ Auth: Platform admin account                                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ Manages
                            │
┌──────────────────────────────────────────────────────────────────┐
│              TENANT ADMIN (Website Level)                        │
│              Path: /tenant_admin/*                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│ Controllers:                                                     │
│ ├─ dashboard_controller         - Overview & stats              │
│ ├─ media_library_controller     - Media/image management        │
│ ├─ pages_controller             - CMS pages                     │
│ │  └─ pages/settings_controller - Page-specific config          │
│ ├─ contents_controller          - Content blocks                │
│ ├─ onboarding_controller        - Setup wizard                  │
│ ├─ email_templates_controller   - Email configuration           │
│ ├─ domains_controller           - Custom domain setup           │
│ ├─ plan/settings_controller     - Subscription management       │
│ ├─ contacts_controller          - Lead/contact list             │
│ ├─ messages_controller          - Enquiry inbox                 │
│ ├─ page_parts_controller        - Page building blocks          │
│ └─ analytics_controller         - Website analytics             │
│                                                                  │
│ Scope: Single website (current_website)                        │
│ Auth: Website admin account                                     │
│ Tenancy: Automatic via ActsAsTenant middleware                  │
│                                                                  │
│ Example Flow:                                                    │
│ Request /tenant_admin/media_library                            │
│   ↓                                                              │
│ Middleware: ActsAsTenant.current_tenant = website              │
│   ↓                                                              │
│ Controller: PwbTenant::Media.all                               │
│   ↓                                                              │
│ Query: Automatically scoped to website_id                       │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                            │
                            │ Manages
                            │
┌──────────────────────────────────────────────────────────────────┐
│            TENANT DATA (Website's Private Data)                 │
│                                                                  │
│ ├─ Properties (RealtyAsset, SaleListing, RentalListing)         │
│ ├─ Pages & Content (Page, Content, PageContent)                │
│ ├─ Images (PropPhoto, ContentPhoto, Media)                     │
│ ├─ Contacts & Enquiries (Contact, Message)                    │
│ ├─ Users & Permissions (UserMembership)                       │
│ ├─ Email Templates                                              │
│ ├─ Field Keys & Customizations                                │
│ └─ Configuration & Settings                                    │
│                                                                  │
│ Isolation: website_id column ensures data separation            │
│ Safety: Each tenant can only see their own data               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 9. Data Storage Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                  DATA STORAGE & LOCATIONS                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  RELATIONAL DATA (PostgreSQL)           │
│  Structured tables, relationships       │
├─────────────────────────────────────────┤
│                                         │
│  Entities:                              │
│  ├─ RealtyAssets                        │
│  ├─ SaleListings / RentalListings       │
│  ├─ Pages, Content, PageParts           │
│  ├─ Contacts, Messages                  │
│  ├─ Users, Websites, Subscriptions      │
│  ├─ Features, FieldKeys                 │
│  └─ Media Library (metadata only)       │
│                                         │
│  Constraints:                           │
│  ├─ Foreign keys for referential integrity
│  ├─ Unique indexes for key fields       │
│  ├─ GIN indexes for JSONB columns       │
│  └─ Partial indexes for conditional data│
│                                         │
│  Materialized View:                     │
│  └─ pwb_properties (denormalized)       │
│     (RealtyAsset + active listing combo)│
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  JSON/JSONB COLUMNS (Flexible Data)    │
├─────────────────────────────────────────┤
│                                         │
│  Translations (JSONB):                  │
│  ├─ RealtyAsset.translations            │
│  ├─ SaleListing.translations            │
│  ├─ RentalListing.translations          │
│  ├─ Content.translations                │
│  ├─ Page.translations                   │
│  ├─ FieldKey.translations               │
│  └─ Link.translations                   │
│                                         │
│  Configuration (JSON):                  │
│  ├─ Website.configuration               │
│  ├─ Website.admin_config                │
│  ├─ Website.styles_config               │
│  ├─ Website.search_config_*             │
│  ├─ Website.whitelabel_config           │
│  ├─ PagePart.block_contents             │
│  ├─ PagePart.editor_setup               │
│  └─ Contact.details                     │
│                                         │
│  GIN indexes on JSONB for query speed   │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  ACTIVE STORAGE (File Storage)          │
│  Images, documents, media               │
├─────────────────────────────────────────┤
│                                         │
│  Development Environment:               │
│  └─ Local disk: /storage directory      │
│                                         │
│  Production Environment:                │
│  └─ Cloudflare R2 (S3-compatible)       │
│                                         │
│  Attachments:                           │
│  ├─ PropPhoto.image                     │
│  ├─ ContentPhoto.image                  │
│  └─ Media.file                          │
│                                         │
│  Database Metadata:                     │
│  └─ active_storage_blobs                │
│     (filename, content_type, size, etc) │
│  └─ active_storage_attachments          │
│     (record_type, record_id references) │
│                                         │
│  URL Generation:                        │
│  ├─ Rails blob paths: /rails/...        │
│  ├─ Variants (on-demand): .../variants/ │
│  └─ CDN: Direct R2 URLs (if enabled)    │
│                                         │
│  File Limits:                           │
│  └─ Max 25 MB per file                  │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  CACHE LAYER (Optional)                 │
├─────────────────────────────────────────┤
│                                         │
│  Used for:                              │
│  ├─ Materialized view data              │
│  ├─ Frequently accessed translations    │
│  ├─ FieldKey options (dropdowns)        │
│  └─ Website configuration               │
│                                         │
│  Backend:                               │
│  └─ Rails cache (configurable per env)  │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  EXTERNAL INTEGRATIONS (Optional)       │
├─────────────────────────────────────────┤
│                                         │
│  Ntfy.sh:                               │
│  └─ Push notifications to admins        │
│                                         │
│  Google Maps API:                       │
│  └─ Geocoding & map display             │
│                                         │
│  reCAPTCHA:                             │
│  └─ Form spam protection                │
│                                         │
│  Analytics (GA, Ahoy):                  │
│  └─ Visitor tracking                    │
│                                         │
└─────────────────────────────────────────┘
```

---

## 10. Content Translation Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│           HOW TRANSLATIONS FLOW THROUGH THE SYSTEM                │
└──────────────────────────────────────────────────────────────────┘

Admin Edits Property in Spanish (ES):

Step 1: Admin selects language
┌──────────────────┐
│ Select ES        │
│ (Switch I18n)    │
└──────┬───────────┘
       │

Step 2: Admin edits title
┌─────────────────────────────────────────────┐
│ Title:  "Apartamento Hermoso"               │
│ Description: "Hermosa vista al mar..."      │
└─────────────────┬───────────────────────────┘
                  │

Step 3: Submit form
┌─────────────────────────────────────────────┐
│ Controller (ActsAsTenant context):          │
│ @listing.title = "Apartamento Hermoso"     │
│ @listing.save!                              │
└─────────────────┬───────────────────────────┘
                  │

Step 4: Mobility saves to JSONB
┌─────────────────────────────────────────────┐
│ Database Update:                            │
│                                             │
│ UPDATE pwb_sale_listings                    │
│ SET translations = {                        │
│   "en": {                                   │
│     "title": "Beautiful Apartment"          │
│   },                                        │
│   "es": {                                   │
│     "title": "Apartamento Hermoso"         │
│   }                                         │
│ }                                           │
│ WHERE id = uuid                             │
└─────────────────┬───────────────────────────┘
                  │

Step 5: Frontend displays in user's locale
┌─────────────────────────────────────────────┐
│ Visitor language: Spanish (ES)              │
│ I18n.locale = :es                           │
│                                             │
│ <%= listing.title %>                        │
│ => "Apartamento Hermoso"                    │
│                                             │
│ Fallback if missing translation:            │
│ If ES missing: falls back to EN             │
│ "Beautiful Apartment"                       │
└─────────────────────────────────────────────┘


Translation Structure in Database:

┌────────────────────────────────────────────┐
│ Table: pwb_sale_listings                   │
│                                            │
│ id       | translations      | price_...  │
│ uuid-123 | {                 | 50000      │
│          |   "en": {         |            │
│          |     "title": "...",│            │
│          |     "description":|            │
│          |       "..."       │            │
│          |   },              │            │
│          |   "es": {         │            │
│          |     "title": "...",│            │
│          |     "description":|            │
│          |       "..."       │            │
│          |   },              │            │
│          |   "de": {         │            │
│          |     "title": "...",│            │
│          |     "description":|            │
│          |       "..."       │            │
│          |   }               │            │
│          | }                 │            │
│                                            │
│ Notes:                                     │
│ - Single JSONB column for all languages   │
│ - GIN index for fast lookups               │
│ - Fallback chain: xx -> en                │
│ - Empty values treated as nil              │
└────────────────────────────────────────────┘
```

This document provides comprehensive visual understanding of PropertyWebBuilder's architecture.
