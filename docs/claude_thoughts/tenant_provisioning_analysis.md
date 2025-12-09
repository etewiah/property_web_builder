# PropertyWebBuilder Multi-Tenant Provisioning Analysis

## Executive Summary

PropertyWebBuilder is a Rails multi-tenant SaaS application that supports multiple real estate websites (tenants) within a single application instance. The provisioning process is well-structured with recent enhancements for domain management and seed packs, but there are some areas where the flow could be more streamlined, particularly around user onboarding and automated provisioning workflows.

---

## Current Provisioning Flow

### 1. Website Creation

**Entry Points:**
- **Admin UI**: `TenantAdmin::WebsitesController#create` (lines 38-52)
- **Rails Console**: Direct `Pwb::Website.create!`
- **Not Yet Implemented**: User-facing signup flow

**Website Model** (`Pwb::Website`)
- Core tenant identifier
- Supports both **subdomain-based** routing and **custom domain** routing
- Latest additions (Dec 2024):
  - `subdomain` - unique, alphanumeric with hyphens (2-63 chars)
  - `custom_domain` - full domain with DNS verification support
  - `custom_domain_verification_token` - for ownership verification
  - `custom_domain_verified` and `custom_domain_verified_at` - verification tracking

**Key Website Attributes:**
```ruby
{
  subdomain: string              # e.g., "costa-luxury"
  company_display_name: string   # Display name for the agency
  theme_name: string             # e.g., "bristol"
  default_client_locale: string  # e.g., "en-UK"
  supported_locales: array       # ["en", "es", "de"]
  default_currency: string       # e.g., "EUR"
  default_area_unit: integer     # sqm or sqft
  custom_domain: string          # e.g., "costaluxury.es"
  custom_domain_verified: boolean
  raw_css: text                  # Custom CSS
  configuration: json            # Flexible config storage
  style_variables_for_theme: json # Theme styling
}
```

**Tenant Resolution:**
- Priority order:
  1. Custom domain (if verified) via `Website.find_by_custom_domain(host)`
  2. Subdomain extraction via `Website.find_by_subdomain(subdomain)`
  3. Falls back to first website if no match
- Platform domains configured via `PLATFORM_DOMAINS` env var (default: "propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost")
- Reserved subdomains: www, api, admin, app, mail, ftp, smtp, pop, imap, ns1, ns2, localhost, staging, test, demo

---

## 2. User and Access Management

### User Model (`Pwb::User`)
- Uses Devise for authentication (email/password, OAuth with Facebook)
- **Belongs to** a website (optional, for backwards compatibility)
- **Has many** `user_memberships` for multi-website access

### UserMembership Model (`Pwb::UserMembership`)
- Junction table for multi-website user access
- Created: December 1, 2024 (very recent)
- **Attributes:**
  ```ruby
  {
    user_id: foreign_key      # Pwb::User
    website_id: foreign_key   # Pwb::Website
    role: string              # owner, admin, member, viewer (hierarchical)
    active: boolean           # For soft-deactivation
  }
  ```
- **Roles (hierarchical):**
  - `owner` - Full control, can manage other admins
  - `admin` - Admin access to the website
  - `member` - Standard user access
  - `viewer` - Read-only access

- **Key Methods:**
  - `active?` - Check if membership is active
  - `admin?` - Check if owner or admin
  - `owner?` - Check if owner
  - `can_manage?(other_membership)` - Hierarchical permission check

**Current Gap:** The `UserMembership` model was just added (Dec 1, 2024) to support multi-website users. The system is transitioning from a single-website-per-user model to true multi-website support.

### User Creation Flow

**Via Admin UI** (`TenantAdmin::UsersController#create`):
1. Admin creates user in the admin panel
2. User gets assigned to the current website via `UserMembership`
3. Invitation email sent if configured (not shown in controller yet)

**Via Seed Packs:**
```ruby
# From seed pack config (seed_pack.rb:474-513)
users:
  - email: admin@costaluxury.es
    role: admin
    password: demo123
  - email: agent@costaluxury.es
    role: agent
    password: demo123
```

**Access Control:**
```ruby
# User can access website if:
1. website_id matches their primary website, OR
2. They have an active UserMembership for that website, OR
3. They have a firebase_uid (Firebase auth integration)
```

---

## 3. Seeding and Data Population

### Three-Tier Seeding System

#### Tier 1: Seed Packs (Recommended for New Tenants)

**Path:** `db/seeds/packs/`
**Available Packs:**
1. **base** - Foundation pack (inherited by all others)
   - Common field keys, navigation links, page structure
   - Default website config: Bristol theme, English, EUR currency

2. **spain_luxury** - Premium Spanish estate agent
   - Inherits from: base
   - Locales: Spanish, English, German
   - 7 sample properties (villas, penthouses, apartments)
   - Costa del Sol theme

3. **netherlands_urban** - Dutch urban real estate
   - Inherits from: base
   - Locales: Dutch, English
   - 8 sample properties
   - Amsterdam/Rotterdam focus

**Pack Structure:**
```
pack_name/
├── pack.yml           # Metadata & configuration
├── field_keys.yml     # Property taxonomy
├── links.yml          # Navigation
├── pages/             # Page definitions (optional)
├── page_parts/        # Page components (optional)
├── properties/        # Property YAML files
├── content/           # Page content by page
├── translations/      # Locale-specific translations
└── images/            # Property photos
```

**Pack Configuration Example (spain_luxury/pack.yml):**
```yaml
name: spain_luxury
display_name: "Spanish Luxury Real Estate"
description: "Estate agent specializing in luxury properties on the Costa del Sol"
version: "1.0"
inherits_from: base

website:
  theme_name: bristol
  default_client_locale: es
  supported_locales: [es, en, de]
  country: Spain
  currency: EUR
  area_unit: sqm

agency:
  display_name: "Costa Luxury Properties"
  email: "info@costaluxury.es"
  phone: "+34 952 123 456"
  address:
    street_address: "Avenida del Mar 45"
    city: Marbella
    region: Málaga
    country: Spain
    postal_code: "29600"

page_parts:
  home:
    - key: heroes/hero_centered
      order: 1
    - key: features/feature_grid_3col
      order: 2
    # ... more page parts

users:
  - email: admin@costaluxury.es
    role: admin
    password: demo123
  - email: agent@costaluxury.es
    role: agent
    password: demo123
```

**Applying a Seed Pack:**
```ruby
# Via rake task
rails pwb:seed_packs:apply[spain_luxury,website_id]

# Via controller (TenantAdmin::WebsitesController#create)
if params[:website][:seed_data] == "1"
  seed_website_content(@website, params[:website][:skip_properties] == "1")
end

# Programmatically
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```

**Available Rake Tasks:**
- `rails pwb:seed_packs:list` - List all available packs
- `rails pwb:seed_packs:preview[pack_name]` - Preview what will be created (dry run)
- `rails pwb:seed_packs:apply[pack_name,website_id]` - Apply pack to a website
- `rails pwb:seed_packs:apply_with_options[pack_name,'skip_users,skip_properties']` - Apply with options
- `rails pwb:seed_packs:reset_and_apply[pack_name]` - WARNING: Destructive

#### Tier 2: Legacy Seeder (`Pwb::Seeder`)

**Path:** `lib/pwb/seeder.rb`
**Used for:** Default seeds when no pack is specified
**Data sources:** `db/seeds/` and `db/yml_seeds/`

**Seeding includes:**
- Translations (13 languages)
- Agency information
- Website configuration
- Sample properties (6 properties)
- Field keys
- Users
- Contacts
- Navigation links

**Called by:**
```ruby
Pwb::Seeder.seed!(website: website, skip_properties: false)
```

#### Tier 3: Page Parts and Content Seeders

**PagePartManager** and **PagesSeeder** handle:
- Page structure creation
- Page part templates and layouts
- Content translations for pages

---

## 4. Sample Content (Properties)

### Property Models

**Pwb::RealtyAsset** - Physical property data (normalized)
- Address, size, amenities, descriptions
- Scoped to website_id

**Pwb::SaleListing / Pwb::RentalListing** - Listing data
- Price, availability, translated details
- Can have multiple listings per asset

**Pwb::ListedProperty** - Read-only materialized view
- Optimized query performance
- Automatically refreshed when assets/listings change
- **Important:** Cannot be created directly - raises `ActiveRecord::ReadOnlyRecord`

### Sample Properties in Seed Packs

**spain_luxury pack includes:**
- villa_marbella.yml - Luxury villa for sale
- villa_benahavis.yml - Premium villa
- penthouse_puerto_banus.yml - Luxury penthouse
- apartment_marbella.yml - Premium apartment
- apartment_fuengirola_rental.yml - Rental apartment
- townhouse_estepona.yml - Townhouse
- villa_rental_mijas.yml - Rental villa

**netherlands_urban pack includes:**
- 8 properties across Amsterdam, Rotterdam, Utrecht, Den Haag
- Mix of for-sale and rental listings

---

## 5. Domain/Subdomain Configuration

### Subdomain-Based Routing

**How it works:**
1. Request arrives at `costa-luxury.propertywebbuilder.com`
2. Host is compared against `PLATFORM_DOMAINS`
3. Subdomain `costa-luxury` is extracted
4. `Website.find_by_subdomain('costa-luxury')` locates the tenant

**Validation:**
- Unique within the database
- Case-insensitive matching
- Reserved subdomains prevented
- Format: alphanumeric + hyphens, 2-63 chars, no leading/trailing hyphens

### Custom Domain Configuration (NEW - Dec 2024)

**Features:**
- Full custom domain support (e.g., costaluxury.es)
- DNS verification via TXT record
- Fallback to unverified domains in development/test environments
- Automatic HTTPS URL generation

**Verification Flow:**
1. Website owner adds custom domain
2. System generates verification token: `custom_domain_verification_token`
3. Owner adds DNS TXT record: `_pwb-verification.costaluxury.es` = token
4. System verifies via `Website#verify_custom_domain!`
5. Once verified, custom domain routes to website

**Methods:**
```ruby
website.generate_domain_verification_token!      # Create token
website.verify_custom_domain!                    # Verify via DNS
website.custom_domain_active?                    # Check if usable
website.primary_url                              # Get primary URL
```

**Dev/Test Bypass:**
- Unverified custom domains work in development/test environments
- Production requires verification

---

## 6. Configuration Options for Websites

### Theme System
```ruby
theme_name: string              # e.g., 'bristol'
style_variables_for_theme: json # Per-theme styling
raw_css: text                   # Custom CSS overrides
```

### Localization
```ruby
supported_locales: array         # ["en", "es", "de"]
default_client_locale: string    # "es"
default_admin_locale: string     # "en"
```

### Currency & Units
```ruby
default_currency: string         # "EUR", "GBP", "USD"
supported_currencies: array      # For conversion features
default_area_unit: integer       # 0=sqm, 1=sqft (via enum)
```

### Price Options
```ruby
sale_price_options_from: array   # Price filter ranges
sale_price_options_till: array
rent_price_options_from: array
rent_price_options_till: array
```

### Display Settings
```ruby
landing_hide_for_rent: boolean   # Hide rental listings
landing_hide_for_sale: boolean   # Hide sale listings
landing_hide_search_bar: boolean # Hide property search
```

### Analytics & SEO
```ruby
analytics_id: string             # e.g., GA tracking ID
analytics_id_type: integer       # Type of analytics (GA4, etc.)
```

### Other Configs
```ruby
company_display_name: string     # Display name
email_for_general_contact_form: string
email_for_property_contact_form: string
configuration: json              # Flexible config storage
```

---

## 7. Agency Model

**Pwb::Agency** - Real estate agency/brokerage information
- One per website (via `has_one :agency`)
- **Attributes:**
  - display_name, company_name
  - phone_number_primary, phone_number_mobile, phone_number_other
  - email_primary, email_for_property_contact_form, email_for_general_contact_form
  - primary_address_id, secondary_address_id (foreign keys to Pwb::Address)

**Created during seed pack application:**
```ruby
# seed_pack.rb:211-241
agency_config = config[:agency]
agency = @website.agency || @website.build_agency
agency.update!(display_name, email_primary, phone_number_primary)
# Address seeding included
```

---

## 8. Navigation and Links

**Pwb::Link Model:**
- Represents navigation items and social media links
- Scoped to website_id
- **Types:** top_nav, footer, social_media
- **Attributes:** slug, title, link_url, placement, visible, order

**Seeded via:**
- `db/seeds/packs/{pack_name}/links.yml`
- Includes: Home, About Us, Buy, Rent, Sell, Contact pages
- Social media links: Facebook, Twitter, LinkedIn, YouTube, Pinterest

---

## 9. Field Keys (Property Taxonomy)

**Pwb::FieldKey** - Property attributes, types, states, features
- Scoped to website_id (each tenant can customize)
- **Tags:** property-types, property-states, property-features, property-amenities
- Used for property filtering and search

**Example from field_keys.yml:**
```yaml
types:
  villa: { en: "Villa", es: "Villa", de: "Villa" }
  apartment: { en: "Apartment", es: "Apartamento", de: "Wohnung" }
  townhouse: { en: "Townhouse", es: "Casa adosada" }

features:
  swimming_pool: { en: "Swimming Pool", es: "Piscina" }
  garden: { en: "Garden", es: "Jardín" }
```

---

## 10. Pages and Content

**Pwb::Page** - CMS pages for the website
- Scoped to website_id
- Has slug, title, translations
- Has many page_parts (components) in order
- Pages: home, about-us, buy, rent, sell, contact-us, privacy-policy, legal-notice

**Pwb::Content** - Static/dynamic content snippets
- Translated via Mobility gem
- Examples: logo, footer content, home page sections

**Pwb::PagePart** - Reusable page components
- Template-based (heroes, features, testimonials, CTAs, etc.)
- Has editor_setup (configuration for admin UI)
- Can be ordered on pages

---

## Current Provisioning Workflow

### Happy Path: Admin Creates New Tenant

```
1. Admin navigates to Tenant Admin → Websites → New
2. Fills form:
   - subdomain: "costa-luxury"
   - company_display_name: "Costa Luxury Properties"
   - theme_name: "bristol"
   - supported_locales: ["es", "en", "de"]
   - default_currency: "EUR"
   - Checkbox: "Seed with data"
   - Checkbox: "Skip properties" (optional)
3. Submits → WebsitesController#create
4. Website record created
5. If seed_data == "1":
   - Pwb::Seeder.seed!(website: website)
   - Pwb::PagesSeeder.seed_page_parts!
   - Pwb::ContentsSeeder.seed_page_content_translations!
6. Redirect to show page
```

### Alternative: Apply Seed Pack to Existing Website

```
rails pwb:seed_packs:apply[spain_luxury,website_id]
```

### Current Gaps

1. **No User Self-Service Signup**
   - No public signup flow for new agencies
   - Only admin-driven tenant creation
   - No automated provisioning on signup

2. **No Automated Onboarding**
   - No setup wizard after website creation
   - No prompt to add agency details
   - No domain configuration wizard

3. **Limited Provisioning Customization**
   - Seed packs are fixed - can't customize on creation
   - No way to choose which pack at creation time
   - Users must pick theme separately after creation

4. **No Usage Limits or Quotas**
   - No tenant tier/plan system visible
   - No billing integration
   - No property/user limits

5. **Manual Domain Setup**
   - Custom domain verification is manual
   - No wizard for DNS configuration
   - No status dashboard for domain verification

6. **Partial Multi-Website Support**
   - UserMembership is brand new (Dec 1, 2024)
   - System is transitioning but not fully complete
   - Some code still assumes single website per user

7. **No Tenant Deletion/Deactivation**
   - Can delete via Rails console
   - No soft-deletion
   - No data export before deletion

---

## Key Models Overview

```
Pwb::Website (tenant)
├── has_many :users
├── has_many :user_memberships
├── has_many :members (through memberships)
├── has_many :pages
├── has_many :links
├── has_many :contents
├── has_many :realty_assets (properties)
├── has_many :field_keys
├── has_one :agency
└── has_many :listed_properties (materialized view)

Pwb::User
├── belongs_to :website (optional)
├── has_many :user_memberships
├── has_many :websites (through memberships)
├── has_many :authorizations (OAuth)
└── has_many :auth_audit_logs

Pwb::UserMembership (NEW - Dec 2024)
├── belongs_to :user
├── belongs_to :website
└── Roles: owner, admin, member, viewer

Pwb::Agency
├── belongs_to :website
├── belongs_to :primary_address
└── belongs_to :secondary_address

Pwb::RealtyAsset (property physical data)
├── has_many :sale_listings
├── has_many :rental_listings
└── belongs_to :website

Pwb::SaleListing / Pwb::RentalListing
├── belongs_to :realty_asset
└── Translations (price, description, etc.)

Pwb::Page
├── belongs_to :website
├── has_many :page_parts
└── Mobility translations (title, content)

Pwb::Link
├── belongs_to :website
└── Mobility translations (title)

Pwb::Content
├── belongs_to :website
└── Mobility translations (raw_*)

Pwb::FieldKey
├── belongs_to :website
└── Property taxonomy (types, features, amenities)
```

---

## Data Isolation

**Tenant Scoping Strategy:**
- `website_id` foreign key on all tenant-scoped tables
- Scoped unique indexes: `[website_id, slug]` or `[website_id, key]`
- Two websites CAN have duplicate slugs/keys - they're scoped
- Enforced at application level in controllers/services
- GraphQL queries start with `Pwb::Current.website`

**Key Scoped Tables:**
- pwb_pages (website_id, slug unique together)
- pwb_contents (website_id, key unique together)
- pwb_links (website_id, slug unique together)
- pwb_realty_assets (website_id)
- pwb_field_keys (website_id)
- pwb_user_memberships (user_id, website_id unique together)

**Not Scoped (Shared):**
- pwb_users (cross-website, membership driven)
- i18n_backend_active_record_translations (shared translations)
- Devise tables (shared authentication)

---

## Technical Constraints & Considerations

### 1. Multi-Website User Support (In Transition)

**Status:** UserMembership model added Dec 1, 2024 - but full migration incomplete
- Users can now belong to multiple websites
- However, `Pwb::User#website_id` still exists as legacy field
- Validation requires: `website OR at least one membership`
- System transitioning from single-website to multi-website model

**Implication:** Some code may still assume single website per user. Code review needed.

### 2. Subdomain vs Custom Domain Routing

**Design Decision:**
- Subdomains are primary, custom domains are secondary
- Routing priority: custom domain → subdomain → error
- Custom domains require DNS verification (except dev/test)

**For Provisioning:**
- Minimum viable: Just set subdomain, subdomain is auto-routed
- Optional: Add custom domain, provide verification token to user

### 3. Seed Pack Inheritance

**How it works:**
- Packs can inherit from parent packs via `inherits_from: base`
- Parent pack applied first, child pack applied after
- Child can skip inherited sections with options

**Implication:** Good for consistency, but order matters.

### 4. Materialized View for Properties

**Important:** `Pwb::ListedProperty` is read-only
- Cannot use `.create!` or `.build`
- Automatically refreshed when assets/listings change
- SQL view, not updatable

**For Seeding:** Create `RealtyAsset` and `Listing` records, not `ListedProperty`

### 5. Tenant Context via Pwb::Current

**How routing works:**
```ruby
# In routes concern or middleware:
Pwb::Current.website = Website.find_by_host(request.host)
```

**Implication:** Every request has a website context. Some operations may fail if `Pwb::Current.website` is nil.

### 6. Devise Integration

**Authentication:**
- Users authenticate against `email` and `password`
- Devise checks `active_for_authentication?` which now includes:
  - Primary website_id matches, OR
  - Active membership exists, OR
  - Firebase UID present

**Implication:** Users can sign in on any website where they have access.

### 7. No Built-in Rate Limiting or Quotas

**Current System:**
- No visible tenant tier/plan system
- No API rate limiting per tenant
- No property/user limits
- No feature flags per tenant

**For Provisioning:** Would need to be added separately.

---

## Recommendations for Improvements

### 1. User Self-Service Signup (High Priority)

Add a public signup flow:
```
1. User registers via public signup form
2. Creates first website as part of signup
3. Option to use seed pack template
4. Redirects to post-signup onboarding
```

### 2. Provisioning Wizard (High Priority)

After website creation:
```
1. Confirm agency details
2. Choose/customize seed pack
3. Set up custom domain (optional)
4. Invite team members
5. Configure notifications
```

### 3. Multi-Website User Management (High Priority)

Complete the transition to full multi-website support:
- Deprecate/remove `Pwb::User#website_id` if possible
- Update all authentication code to use memberships
- Add "switch website" UI for multi-website users

### 4. Tenant Tier System (Medium Priority)

Add configurable tiers:
```ruby
Pwb::Website
  tier: string        # 'free', 'pro', 'enterprise'
  property_limit: integer
  user_limit: integer
  custom_domain_allowed: boolean
  features: json      # Feature flags per tier
```

### 5. Domain Management Dashboard (Medium Priority)

```
For each custom domain:
- Status indicator (pending, verified, failed)
- Verification token display
- DNS record helper
- Auto-verify button
- Troubleshooting guide
```

### 6. Seed Pack Customization at Creation (Low Priority)

Allow choosing seed pack during website creation:
```ruby
# In WebsitesController#create
if params[:website][:seed_pack].present?
  pack = Pwb::SeedPack.find(params[:website][:seed_pack])
  pack.apply!(website: @website)
end
```

### 7. Soft Delete for Tenants (Low Priority)

```ruby
# Add columns:
add_column :pwb_websites, :deleted_at, :datetime
add_index :pwb_websites, :deleted_at

# Implement paranoia or similar
```

### 8. Tenant Usage Analytics (Low Priority)

Track per-website:
- Property count over time
- User count
- API usage
- Feature usage
- Storage used

---

## Database Schema Highlights

**Recent Additions (Dec 2024):**
- `add_subdomain_to_websites` - Unique subdomain for routing
- `add_custom_domain_to_websites` - Custom domain support with verification
- `create_pwb_user_memberships` - Multi-website user support
- `add_website_id_to_pwb_users` - Legacy field (being phased out?)
- `add_website_id_to_page_parts` - Page parts scoping
- `add_website_id_to_tables` - Bulk scoping addition
- `add_ntfy_settings_to_websites` - Notification settings
- `add_seo_fields_to_websites` - SEO configuration

**Key Indexes:**
```sql
-- Unique constraints
UNIQUE INDEX on pwb_websites(subdomain)
UNIQUE INDEX on pwb_websites(custom_domain) WHERE custom_domain IS NOT NULL
UNIQUE INDEX on pwb_user_memberships(user_id, website_id)

-- Scoped unique indexes
UNIQUE INDEX on pwb_pages(slug, website_id)
UNIQUE INDEX on pwb_links(website_id, slug)
UNIQUE INDEX on pwb_contents(website_id, key)
```

---

## File Locations Summary

### Core Models
- Website: `/app/models/pwb/website.rb`
- User: `/app/models/pwb/user.rb`
- UserMembership: `/app/models/pwb/user_membership.rb`
- Agency: `/app/models/pwb/agency.rb`
- Page/Content/Links: `/app/models/pwb/{page,content,link}.rb`

### Controllers
- Website Management: `/app/controllers/tenant_admin/websites_controller.rb`
- User Management: `/app/controllers/tenant_admin/users_controller.rb`
- Admin Panel: `/app/controllers/pwb/admin_panel_controller.rb`

### Seeding
- Seed Packs: `/lib/pwb/seed_pack.rb`
- Legacy Seeder: `/lib/pwb/seeder.rb`
- Page Seeder: `/lib/pwb/pages_seeder.rb`
- Content Seeder: `/lib/pwb/contents_seeder.rb`
- Rake Tasks: `/lib/tasks/seed_packs.rake`

### Seed Data
- Packs: `/db/seeds/packs/{base,spain_luxury,netherlands_urban}`
- Legacy Seeds: `/db/yml_seeds/`
- Images: `/db/seeds/images/` and pack-specific images

### Migrations
- Website creation: `20170131190507_create_pwb_websites.rb`
- Subdomain: `20251126181412_add_subdomain_to_websites.rb`
- Custom domain: `20251208111819_add_custom_domain_to_websites.rb`
- UserMembership: `20251201140925_create_pwb_user_memberships.rb`

### Documentation
- Multi-tenancy: `/docs/06_Multi_Tenancy.md`
- Seeding architecture: `/docs/seeding/SEEDING_ARCHITECTURE.md`
- Seed packs plan: `/docs/seeding/seed_packs_plan.md`

---

## Summary Table

| Component | Status | Notes |
|-----------|--------|-------|
| Multi-tenancy | Mature | Shared database, website_id scoping |
| Website creation | Implemented | Via admin UI or console, no public signup |
| Subdomain routing | Implemented | Primary routing method |
| Custom domain routing | NEW (Dec 2024) | DNS verification required |
| Domain verification | Implemented | DNS TXT record based |
| User authentication | Mature | Devise with OAuth support |
| Multi-website users | NEW (Dec 2024) | UserMembership model added but transition incomplete |
| Seed packs | Implemented | 3 packs available (base, spain_luxury, netherlands_urban) |
| Seed pack inheritance | Implemented | Packs can inherit from parent packs |
| Sample content | Implemented | Properties, pages, content in seed packs |
| Agency configuration | Implemented | Can be seeded with pack or set manually |
| Navigation setup | Implemented | Links seeded via pack.yml or YAML files |
| Field keys | Implemented | Tenant-scoped property taxonomy |
| Theme system | Implemented | Per-website theme configuration |
| Onboarding wizard | Not implemented | Opportunity for improvement |
| Tenant tier system | Not implemented | Would need to be added |
| Domain management UI | Partial | Manual verification only |
| Soft delete for tenants | Not implemented | Hard delete only |
| Usage analytics | Not implemented | Would need to be added |
| Public signup | Not implemented | Only admin-driven tenant creation |
| Automated provisioning | Partial | Works for seeding, not for overall flow |

---

## Conclusion

PropertyWebBuilder has a solid foundation for multi-tenant provisioning with recent enhancements for domain management and multi-website user support. The seed pack system provides an excellent template-based approach to spinning up new tenants.

However, the provisioning flow is currently **admin-driven** rather than **self-service**. There are significant opportunities to:

1. Enable public user signup with automatic tenant creation
2. Implement guided onboarding workflows
3. Complete the transition to full multi-website user support
4. Add tenant management features (tiers, quotas, analytics)
5. Improve domain setup experience with visual workflows

The codebase is well-structured and appears to be actively maintained (frequent recent commits), making it a good foundation for these enhancements.
