# PropertyWebBuilder Multi-Tenancy Architecture - Comprehensive Exploration Summary

**Document Date:** January 7, 2026  
**Exploration Scope:** Complete multi-tenancy implementation analysis  
**Codebase:** PropertyWebBuilder (Pwb)

---

## Executive Summary

PropertyWebBuilder implements a **subdomain-based multi-tenancy architecture** where each tenant (website) is uniquely identified by:
1. A unique subdomain (e.g., `site1.propertywebbuilder.com`)
2. An optional custom domain (e.g., `www.myrealestate.com`)
3. A unique slug for API identification (e.g., `site1`)

All tenant data is stored in a **single shared database** with **website_id-based row-level isolation**. The system uses:
- **Thread-local storage** (Pwb::Current) for request context
- **Manual WHERE clause filtering** for tenant isolation
- **Database sharding capability** (configured but not required for basic operation)
- **Acts-as-tenant gem** configured but not adopted (manual scoping preferred)

---

## 1. TENANT IDENTIFICATION MECHANISM

### A. Primary Identification Method: Subdomain

The core tenant identifier is the **subdomain** extracted from the request host:

**Example URLs:**
- `https://myagency.propertywebbuilder.com` → subdomain = `myagency`
- `https://agents-network.propertywebbuilder.com` → subdomain = `agents-network`
- `https://www.myrealestate.com` → custom domain = `www.myrealestate.com`

**Resolution Priority** (in SubdomainTenant concern, `/app/controllers/concerns/subdomain_tenant.rb`):
1. **X-Website-Slug header** - Used by API/GraphQL clients to specify tenant
2. **Custom domain match** - Non-platform domains (tenant's own domain)
3. **Subdomain match** - Platform domains (propertywebbuilder.com)
4. **Fallback** - First website in database (rarely used)

**Code Reference:**
```ruby
# SubdomainTenant concern handles resolution
def set_current_website_from_request
  # 1. Check header
  slug = request.headers["X-Website-Slug"]
  Pwb::Current.website = Pwb::Website.find_by(slug: slug) if slug.present?
  
  # 2. Use unified find_by_host (handles both custom domain & subdomain)
  host = request.host.to_s.downcase
  Pwb::Current.website = Pwb::Website.find_by_host(host)
  
  # 3. Fallback
  Pwb::Current.website ||= Pwb::Website.first
  
  # Set acts_as_tenant context
  ActsAsTenant.current_tenant = Pwb::Current.website
end
```

### B. Website Model: The Tenant Root

**Location:** `/app/models/pwb/website.rb`

The `Pwb::Website` model is the **single source of truth for tenant configuration**:

**Key Identifying Columns:**
- `id` (integer, primary key)
- `subdomain` (string, UNIQUE, case-insensitive)
- `slug` (string, for API header identification)
- `custom_domain` (string, UNIQUE, optional)

**Key Configuration Columns:**
- `company_display_name` - Display name for tenant
- `theme_name` - Theme selected for this website
- `shard_name` - Database shard assignment (default: "default")
- `site_type` - Type of site (residential, commercial, vacation_rental)
- `supported_locales` - Array of languages (e.g., ["en-UK", "nl", "es"])
- `default_client_locale` - Default language
- `default_currency` - Default currency (EUR, USD, etc.)
- `search_config` - JSONB configuration for property search UI
- `provisioning_state` - Website creation status (live, provisioning, provisioned, failed)

**Database Indexes:**
```sql
INDEX index_pwb_websites_on_subdomain (subdomain) UNIQUE
INDEX index_pwb_websites_on_custom_domain (custom_domain) UNIQUE WHERE custom_domain IS NOT NULL
INDEX index_pwb_websites_on_slug (slug)
INDEX index_pwb_websites_on_provisioning_state (provisioning_state)
INDEX index_pwb_websites_on_shard_name (shard_name)
```

### C. Domain Resolution Method

**File:** `/app/models/concerns/pwb/website_domain_configurable.rb`

Two lookup methods:

**1. find_by_subdomain(subdomain)**
- Case-insensitive exact match
- Used for platform domains (e.g., site1.propertywebbuilder.com)
- Fast due to UNIQUE index

**2. find_by_custom_domain(domain)**
- Normalizes domain (removes www, protocol, port)
- Case-insensitive matching
- Handles both `example.com` and `www.example.com`

**3. find_by_host(host)** - Unified method
```ruby
def self.find_by_host(host)
  # First try custom domain (non-platform)
  return find_by_custom_domain(host) unless platform_domain?(host)
  
  # Fall back to subdomain lookup
  subdomain = extract_subdomain_from_host(host)
  find_by_subdomain(subdomain) if subdomain.present?
end
```

**Platform Domain Detection:**
```ruby
def self.platform_domains
  ENV.fetch('PLATFORM_DOMAINS', 
    'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost')
    .split(',').map(&:strip)
end
```

**Configuration:** Environment variable `PLATFORM_DOMAINS`
- Default: `propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost`
- Can be customized per deployment

### D. Reserved Subdomains

These subdomains cannot be used by tenants:

```ruby
RESERVED_SUBDOMAINS = %w[
  www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test
]
```

Validation prevents:
- Case-insensitive uniqueness
- Reserved subdomain usage
- Profanity detection via Obscenity gem
- Only alphanumeric and hyphens allowed
- Length: 2-63 characters
- Cannot start or end with hyphen

---

## 2. DATABASE CONFIGURATION & CONNECTION PATTERNS

### A. Database Configuration

**File:** `/config/database.yml`

The application supports **multiple database connections** for sharding:

```yaml
development:
  primary:
    adapter: postgresql
    database: pwb_development
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  
  tenant_shard_1:
    adapter: postgresql
    database: pwb_development_shard_1
    migrations_paths: db/tenant_shard_1_migrate

test:
  primary:
    database: pwb_test
  tenant_shard_1:
    database: pwb_test_shard_1
    migrations_paths: db/tenant_shard_1_migrate

e2e:
  primary:
    database: pwb_e2e
  tenant_shard_1:
    database: pwb_e2e_shard_1
    migrations_paths: db/tenant_shard_1_migrate

production:
  primary:
    database: pwb_production
    url: <%= ENV['PWB_DATABASE_URL'] %>
    password: <%= ENV['PWB_DATABASE_PASSWORD'] %>
    prepared_statements: false
  
  tenant_shard_1:
    database: pwb_production_shard_1
    url: <%= ENV['PWB_TENANT_SHARD_1_DATABASE_URL'] %>
    password: <%= ENV['PWB_DATABASE_PASSWORD'] %>
    prepared_statements: false
```

**Two-Database Setup:**
- **primary**: Global data (Website, User, UserMembership) + tenant data
- **tenant_shard_1**: Optional for sharding tenant data at scale
- Both databases share the same schema (via migrations)

### B. Sharding Configuration

**File:** `/app/models/pwb_tenant/application_record.rb`

```ruby
connects_to shards: {
  default: { writing: :primary, reading: :primary },
  shard_1: { writing: :tenant_shard_1, reading: :tenant_shard_1 }
}
```

**How It Works:**
- `Pwb::Website.shard_name` (string) stores which shard owns this tenant's data
- `ActsAsTenant` automatically routes queries to the correct shard based on current tenant
- Each tenant-scoped model (PwbTenant::*) inherits this sharding behavior

**Current Usage:**
- Default: All tenants use `primary` database
- Future: Can assign tenants to `shard_1` or additional shards for load balancing

**Migrations:**
- `/db/migrate/` - Migrations for primary (global + baseline)
- `/db/tenant_shard_1_migrate/` - Migrations for shard_1 (must be kept in sync)

### C. Two Model Namespaces

The codebase uses **strict namespace separation** for scoping:

#### Pwb:: Namespace (Non-Scoped)
These models are NOT tenant-scoped and query globally:
```ruby
module Pwb
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "pwb_"
    # No acts_as_tenant - can access all data
  end
end
```

**Non-Scoped Models:**
- `Pwb::Website` - The tenant root
- `Pwb::User` - Can belong to multiple websites
- `Pwb::UserMembership` - Links users to websites
- `Pwb::Agency` - One per website
- `Pwb::Address` - Addresses for agencies
- Global models not tied to a specific tenant

**Usage Pattern:**
```ruby
# Must manually filter by website_id
Pwb::Page.where(website_id: current_website.id)
Pwb::Message.where(website_id: current_website&.id).find(params[:id])
```

#### PwbTenant:: Namespace (Auto-Scoped)
These models are automatically scoped to the current tenant:
```ruby
module PwbTenant
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = 'pwb_'
    
    # Automatic tenant scoping - all queries filtered by website_id
    acts_as_tenant :website, class_name: 'Pwb::Website'
    
    # Sharding support
    connects_to shards: {
      default: { writing: :primary, reading: :primary },
      shard_1: { writing: :tenant_shard_1, reading: :tenant_shard_1 }
    }
    
    # Enforce website presence
    validates :website, presence: true
  end
end
```

**Note:** Currently, PwbTenant:: namespace exists but is NOT actively used. Models remain in Pwb:: namespace with manual scoping. This was a planned migration that wasn't fully adopted.

---

## 3. SUBDOMAIN HANDLING FOR TENANT IDENTIFICATION

### A. Request Flow for Subdomain Routing

```
┌─────────────────────────────────────────────────────────┐
│  INCOMING REQUEST                                       │
│  https://myagency.propertywebbuilder.com/admin/pages    │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │ Rails extracts subdomain       │
        │ request.subdomain = "myagency" │
        └────────────────┬───────────────┘
                         │
                         ▼
        ┌────────────────────────────────────────┐
        │ SubdomainTenant concern (BEFORE ACTION)│
        │ included in SiteAdminController        │
        │ included in Pwb::ApplicationController │
        └────────────────┬───────────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
  ┌──────────────┐          ┌──────────────────────┐
  │X-Website-Slug│          │ Platform domain?     │
  │   header?    │          │ (check config)       │
  │              │          │                      │
  │ Find by slug │          │ If yes: extract      │
  └──────────────┘          │ subdomain from host  │
        │                   │ If no: use custom    │
        │                   │ domain lookup        │
        │                   └──────────────┬───────┘
        │                                  │
        └──────────────┬───────────────────┘
                       │
                       ▼
        ┌─────────────────────────────────┐
        │ Pwb::Website.find_by_host(host) │
        │ or                              │
        │ Pwb::Website.find_by(slug: ...) │
        │                                 │
        │ Result: Website#42 (myagency)   │
        └────────────────┬────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │ Set Pwb::Current.website        │
        │ Set ActsAsTenant.current_tenant │
        │ (thread-local storage)          │
        └────────────────┬────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │ Controller action executes      │
        │ current_website available       │
        │ All queries auto-scoped         │
        └─────────────────────────────────┘
```

### B. Subdomain Extraction Logic

**File:** `/app/models/concerns/pwb/website_domain_configurable.rb`

```ruby
def self.extract_subdomain_from_host(host)
  platform_domains.each do |pd|
    if host.end_with?(pd)
      # Remove platform domain suffix
      subdomain_part = host.sub(/\.?#{Regexp.escape(pd)}\z/, '')
      # Return first part (handles multi-level subdomains)
      return subdomain_part.split('.').first if subdomain_part.present?
    end
  end
  nil
end
```

**Examples:**
```
Host: myagency.propertywebbuilder.com
Platform domain: propertywebbuilder.com
Extracted subdomain: myagency ✓

Host: sub.myagency.propertywebbuilder.com
Extracted subdomain: sub ✓ (takes first part)

Host: www.example.com
Platform domain: propertywebbuilder.com
Not a platform domain: proceed to custom domain lookup ✓

Host: api.propertywebbuilder.com
Reserved subdomain: REJECTED ✗
```

### C. Custom Domain Support

**Custom Domain Feature:**
- Tenants can use their own domain (e.g., `www.myrealestate.com`)
- Optional - subdomain is always available
- Requires DNS configuration (CNAME or A record pointing to platform)
- Optional verification via DNS TXT record for security

**Configuration:**
```ruby
# Website columns
custom_domain              # string: "www.myrealestate.com"
custom_domain_verified    # boolean: true/false
custom_domain_verification_token # string: for DNS TXT record
custom_domain_verified_at  # datetime: when verified

# Validation
validates :custom_domain,
  uniqueness: { case_sensitive: false, allow_blank: true },
  format: { with: /\A([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,}\z/i },
  length: { maximum: 253, allow_blank: true }
```

**Lookup Priority:**
1. Try custom domain first (if not a platform domain)
2. Try subdomain lookup
3. Fallback to first website

**Helper Methods:**
```ruby
current_website.custom_domain_active?    # Is verified or in dev/test
current_website.custom_domain_request?   # Is current request via custom domain?
current_website.platform_subdomain_request? # Is current request via platform subdomain?
current_website.primary_url              # Returns custom domain URL or subdomain URL
```

---

## 4. WEBSITE/TENANT CREATION & CONFIGURATION

### A. Website Creation Process

**Models Involved:**
- `Pwb::Website` - Main tenant record
- `Pwb::Subdomain` - Optional reserved subdomain allocation
- `Pwb::UserMembership` - Links creator to website as owner
- `Pwb::Subscription` - Optional subscription for tier management

**Creation Attributes:**
```ruby
website = Pwb::Website.create!(
  subdomain: 'myagency',           # Unique, validated
  slug: 'my-agency',               # For API identification
  company_display_name: 'My Agency',
  theme_name: 'default',           # default, brisbane, bologna
  shard_name: 'default',           # Which database shard
  site_type: 'residential',        # residential, commercial, vacation_rental
  
  # Localization
  supported_locales: ['en-UK', 'nl'],
  default_client_locale: 'en-UK',
  default_admin_locale: 'en-UK',
  
  # Preferences
  default_currency: 'EUR',
  default_area_unit: 'sqm',        # sqm or sqft
  
  # SEO
  default_seo_title: 'My Agency',
  default_meta_description: 'Real estate agency',
  
  # Provisioning
  provisioning_state: 'live',      # live, provisioning, provisioned, failed
  provisioning_started_at: Time.current,
  provisioning_completed_at: Time.current,
  
  # Configuration objects
  search_config: {                 # JSONB for search UI
    display: { show_results_map: true },
    filters: { price: { sale: { presets: [100_000, 200_000] } } }
  },
  configuration: {},               # JSON for misc config
  admin_config: {},                # JSON for admin preferences
  styles_config: {}                # JSON for styling
)
```

### B. Website Configuration Models/Concerns

**Website model includes these concerns:**
- `Pwb::WebsiteProvisionable` - Website creation workflow
- `Pwb::WebsiteDomainConfigurable` - Domain & subdomain management
- `Pwb::WebsiteStyleable` - Theme & CSS customization
- `Pwb::WebsiteSubscribable` - Subscription tier integration
- `Pwb::WebsiteSocialLinkable` - Social media links
- `Pwb::WebsiteLocalizable` - Multi-language configuration
- `Pwb::WebsiteThemeable` - Theme selection & configuration

**Key Relationships:**
```ruby
website.agency                     # Has one agency
website.users                      # Has many (can belong to multiple websites)
website.members                    # Through user_memberships
website.user_memberships          # Association link model
website.subscription              # Has one subscription
website.pages                      # Has many pages
website.contents                   # Has many content pieces
website.messages                   # Has many contact form messages
website.contacts                   # Has many contacts
website.props                      # Legacy property model
website.realty_assets              # New property model
website.listed_properties          # Materialized view
website.field_keys                 # Custom field definitions
website.links                      # Navigation links
website.media                      # Media library
website.widget_configs             # Embeddable widgets
```

### C. Seed Packs System

**Location:** `/lib/pwb/seed_pack.rb`

Seed packs are pre-configured bundles for quickly seeding a new website:

**Available Packs:**
- `base` - Minimal base configuration
- `netherlands_urban` - Urban Netherlands properties & content
- `spain_luxury` - Luxury Spain properties & content
- Additional packs can be added in `/db/seeds/packs/`

**Pack Structure:**
```
db/seeds/packs/
├── base/
│   ├── pack.yml                    # Pack metadata
│   ├── field_keys.yml              # Custom field definitions
│   ├── links.yml                   # Navigation links
│   └── ...
├── netherlands_urban/
│   ├── pack.yml
│   ├── properties/
│   │   ├── amsterdam_loft.yml
│   │   ├── grachtenpand_amsterdam.yml
│   │   └── ...
│   ├── content/
│   │   ├── home.yml
│   │   ├── about-us.yml
│   │   └── ...
│   ├── images/
│   │   ├── amsterdam_loft.jpg
│   │   ├── amsterdam_loft.webp
│   │   └── ...
│   └── ...
└── spain_luxury/
    └── ...
```

**Pack Configuration (pack.yml):**
```yaml
display_name: Netherlands Urban
description: Urban properties in the Netherlands
version: 1.0
inherits_from: base              # Can extend another pack

website:
  theme_name: default
  supported_locales: [en-UK, nl]
  default_client_locale: en-UK
  currency: EUR
  area_unit: sqm
  search_config:
    display:
      show_results_map: true

agency:
  display_name: My Agency
  email: info@agency.nl
  phone: +31201234567
  address:
    street_address: Main St 1
    city: Amsterdam
    region: Amsterdam
    country: Netherlands
    postal_code: 1012

users:
  - email: admin@agency.nl
    password: password123
    role: admin
  - email: agent@agency.nl
    role: agent
```

**Applying a Pack:**
```ruby
pack = Pwb::SeedPack.find('netherlands_urban')
pack.apply!(website: website)

# Or with options
pack.apply!(
  website: website,
  options: {
    dry_run: true,                    # Preview only
    skip_properties: false,
    skip_content: true,
    verbose: true
  }
)
```

**Seeding Layers (applied in order):**
1. `seed_website` - Configure theme, locale, currency
2. `seed_agency` - Create agency and address
3. `seed_field_keys` - Custom property field definitions
4. `seed_links` - Navigation menu links
5. `seed_pages` - Pages (home, about, etc.)
6. `seed_page_parts` - Page template components
7. `seed_properties` - Property listings
8. `seed_content` - Page content translations
9. `seed_users` - Admin users
10. `seed_translations` - i18n strings

---

## 5. SEEDING SYSTEM & SEED PACKS STRUCTURE

### A. Overall Seeding Flow

**Main Entry:** `/db/seeds.rb`

```ruby
# 1. Load subscription plans (required in all environments)
Pwb::PlansSeeder.seed!

# 2. Configure default themes
tenant_settings = Pwb::TenantSettings.instance
tenant_settings.update!(default_available_themes: %w[default brisbane bologna])

# 3. Environment-specific seeding
case Rails.env
when 'e2e'
  load Rails.root.join('db', 'seeds', 'e2e_seeds.rb')
when 'development'
  Pwb::Seeder.seed!
  Pwb::PagesSeeder.seed_page_basics!
  Pwb::PagesSeeder.seed_page_parts!
when 'test'
  puts "Test environment - skipping seeds (use fixtures instead)"
else
  Pwb::Seeder.seed!
  Pwb::PagesSeeder.seed_page_basics!
  Pwb::PagesSeeder.seed_page_parts!
end
```

### B. Seed Runner System

**File:** `/lib/pwb/seed_runner.rb`

Enhanced orchestrator with safety features:

**Modes:**
- `:interactive` (default) - Prompts before updating existing data
- `:create_only` - Only creates new records, skips existing
- `:force_update` - Updates without prompting
- `:upsert` - Creates or updates all records

**Usage:**
```ruby
# Interactive with prompts
Pwb::SeedRunner.run(website: website)

# Force creation only
Pwb::SeedRunner.run(website: website, mode: :create_only)

# Dry run (preview)
Pwb::SeedRunner.run(website: website, dry_run: true)

# Skip certain steps
Pwb::SeedRunner.run(
  website: website,
  skip_properties: true,
  skip_translations: true
)
```

**Features:**
- Validates seed files exist before running
- Warns about existing data
- Interactive prompts for update decisions
- Dry-run mode
- Detailed progress logging
- Statistics (created, updated, skipped, errors)

### C. Seed Pack Structure

**Key Classes:**
- `Pwb::SeedPack` - Pack manager and applier
- `Pwb::SeedRunner` - Enhanced seeding orchestrator
- `Pwb::Seeder` - Default seeder for initial setup
- `Pwb::PagesSeeder` - Page and page parts seeding
- `Pwb::ContentsSeeder` - Content translations
- `Pwb::SeedImages` - Image handling

**Seed Pack Directories:**
```
db/seeds/
├── packs/
│   ├── base/
│   ├── netherlands_urban/
│   ├── spain_luxury/
│   └── ...
├── site_import_packs/          # For import features
├── images/                      # Shared seed images
├── yml_seeds/                   # Legacy seed YAML files
├── seeds.rb                     # Main entry point
├── e2e_seeds.rb                 # E2E test seeding
└── plans_seeds.rb               # Subscription plans
```

### D. Seed Data Loading

**YAML-based configuration:**
```yaml
# properties/apartment_amsterdam.yml
reference: APT001
prop_type: types.apartment
prop_state: states.good
address: Canal Street 42
city: Amsterdam
region: Amsterdam
country: Netherlands
postal_code: 1012
bedrooms: 2
bathrooms: 1
garages: 1
constructed_area: 75
plot_area: 100
year_built: 1850
latitude: 52.3676
longitude: 4.9041

sale:
  price_cents: 50000000      # 500,000 EUR
  highlighted: true
  title:
    en-UK: "Beautiful Canal House"
    nl: "Prachtig Grachtenpand"

rental:
  monthly_price_cents: 200000  # 2,000 EUR
  long_term: true
  short_term: false
  furnished: true

features:
  - features.garden
  - features.parquet_floor
  - features.high_ceilings

image: amsterdam_canal_house.jpg
```

---

## 6. DATABASE SCHEMA & MULTI-TENANCY COLUMNS

### A. Critical Columns in Key Tables

**pwb_websites table:**
```sql
id              bigint primary key
subdomain       string unique
slug            string unique
custom_domain   string unique (where custom_domain IS NOT NULL)
company_display_name string
theme_name      string
shard_name      string default 'default'
provisioning_state string
-- and many configuration columns
created_at      timestamp
updated_at      timestamp
```

**Tenant-Scoped Tables (core pattern):**
```sql
-- All tenant-scoped tables have:
id              bigint primary key
website_id      bigint NOT NULL (indexed)
                FOREIGN KEY references pwb_websites(id)
-- other columns...
created_at      timestamp
updated_at      timestamp

-- Unique indexes per website:
INDEX UNIQUE (website_id, slug)   -- For entity uniqueness within website
INDEX UNIQUE (website_id, reference) -- For property uniqueness
```

**Example: pwb_pages table**
```sql
id              bigint primary key
website_id      bigint NOT NULL (indexed)
slug            string NOT NULL
visible         boolean default true
page_type       string
-- content columns...
created_at      timestamp
updated_at      timestamp

-- Indexes
INDEX index_pwb_pages_on_website_id (website_id)
INDEX UNIQUE index_pwb_pages_on_website_id_and_slug (website_id, slug)
```

**Example: pwb_messages table (Contact Form)**
```sql
id              bigint primary key
website_id      bigint NOT NULL (indexed)
origin_email    string
subject         string
content         text
read             boolean
read_at         timestamp
-- and more...
created_at      timestamp
updated_at      timestamp

INDEX index_pwb_messages_on_website_id (website_id)
INDEX index_pwb_messages_on_website_id_and_read (website_id, read)
```

### B. Schema Pattern

All tenant-scoped models follow this pattern:

1. **Has website_id foreign key (indexed)**
   - Not nullable (required relationship)
   - Indexed for fast filtering
   - Foreign key constraint for referential integrity

2. **Unique constraints per website**
   - `UNIQUE (website_id, slug)` - Entity slug unique per website
   - `UNIQUE (website_id, reference)` - Property reference unique per website

3. **Query scoping**
   - Every query on tenant model must include `WHERE website_id = ?`
   - Use materialized views when query patterns are heavy

4. **No cross-tenant operations**
   - Cannot join across website_ids
   - Cannot use subqueries without explicit website_id filtering

---

## 7. CONTROLLER ARCHITECTURE & TENANCY

### A. Three Controller Types

**1. Pwb::ApplicationController (Public Site)**
- **Location:** `/app/controllers/pwb/application_controller.rb`
- **Includes:** SubdomainTenant concern
- **Auth:** None required (public access)
- **Scope:** Single website (set by subdomain)
- **Usage:** Public website pages, property listings, contact forms
- **Example:** `Pwb::PagesController`, `Pwb::PropertiesController`

```ruby
class Pwb::ApplicationController < ActionController::Base
  include SubdomainTenant
  
  def index
    # current_website is available
    @pages = Pwb::Page.where(website_id: current_website.id)
  end
end
```

**2. SiteAdminController (Single-Tenant Admin)**
- **Location:** `/app/controllers/site_admin_controller.rb`
- **Includes:** SubdomainTenant concern
- **Auth:** Devise (requires login) + admin authorization
- **Scope:** Single website (set by subdomain)
- **Usage:** Admin dashboard, property management, content editing
- **Example:** `SiteAdmin::PropertiesController`, `SiteAdmin::MessagesController`

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  include AdminAuthBypass
  
  before_action :require_admin!  # Authentication + Authorization
  before_action :check_subscription_access
  
  def index
    # current_website is available
    @unread_count = Pwb::Message.where(website_id: current_website.id, read: false).count
  end
end
```

**Authorization in SiteAdminController:**
```ruby
def require_admin!
  unless current_user && user_is_admin_for_subdomain?
    render 'pwb/errors/admin_required', status: :forbidden
  end
end

def user_is_admin_for_subdomain?
  return false unless current_user && current_website
  current_user.admin_for?(current_website)  # Checks UserMembership
end
```

**3. TenantAdminController (Cross-Tenant Admin)**
- **Location:** `/app/controllers/tenant_admin_controller.rb`
- **Includes:** NO SubdomainTenant concern (intentional!)
- **Auth:** Devise (requires login) + email whitelist
- **Scope:** All websites (no automatic scoping)
- **Usage:** Super-admin features (manage all websites, users, billing)
- **Example:** `TenantAdmin::WebsitesController`, `TenantAdmin::UsersController`

```ruby
class TenantAdminController < ActionController::Base
  # DOES NOT include SubdomainTenant!
  # This is intentional - we need cross-tenant access
  
  before_action :authenticate_user!
  before_action :require_tenant_admin!  # Email whitelist
  
  def index
    # Deliberately use .unscoped() to see all websites
    @websites = Pwb::Website.unscoped.order(created_at: :desc)
  end
end

def require_tenant_admin!
  allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip)
  unless allowed_emails.include?(current_user.email.downcase)
    render 'pwb/errors/tenant_admin_required', status: :forbidden
  end
end
```

**Configuration:**
- Tenant admin access via environment variable `TENANT_ADMIN_EMAILS`
- Example: `TENANT_ADMIN_EMAILS=admin@example.com,super@example.com`

### B. Current Website Helper

Available in all controllers and views:

```ruby
current_website              # From SubdomainTenant concern
Pwb::Current.website        # Direct thread-local access
@website = current_website  # Instance variable
```

In views:
```erb
<%= current_website.company_display_name %>
<% if current_website.custom_domain_active? %>
  <%= link_to current_website.custom_domain %>
<% end %>
```

### C. Authorization System

**Two Levels:**

**1. Site Admin Authorization**
- User must be authenticated (Devise)
- User must be admin/owner for the current website
- Check via `Pwb::UserMembership`:
  - `role: 'owner'` or `role: 'admin'`
  - `active: true`

```ruby
# In user model
def admin_for?(website)
  memberships.active.where(website: website, role: ['owner', 'admin']).exists?
end
```

**2. Tenant Admin Authorization**
- User must be authenticated
- User's email must be in `TENANT_ADMIN_EMAILS` environment variable
- Only these users can access cross-tenant admin features

**Bypass for Development:**
- Set `BYPASS_ADMIN_AUTH=true` to skip all auth checks
- Set `DEV_SUBSCRIPTION_PLAN` to override subscription tier

---

## 8. ACTS_AS_TENANT CONFIGURATION

### A. Current Status

**Location:** `/config/initializers/acts_as_tenant.rb`

```ruby
ActsAsTenant.configure do |config|
  config.require_tenant = false  # Permissive - allows Pwb:: models without tenant
end
```

**Status:** Configured but not actively used in most models

**Reason:** Original plan was to adopt acts-as-tenant for automatic scoping, but manual scoping was chosen instead for explicit control during development.

### B. Usage in Codebase

**Actively Used:**
- `PwbTenant::ApplicationRecord` includes `acts_as_tenant :website`
- Tenant context set in controllers via `ActsAsTenant.current_tenant = website`

**Not Adopted:**
- Pwb:: models do not use acts_as_tenant
- Manual WHERE clauses preferred for clarity
- Each query explicitly filters by `website_id`

### C. Why Manual Scoping Was Chosen

**Benefits of Manual Scoping:**
- Explicit and visible in code (no "magic" scoping)
- Easier to debug tenant isolation issues
- Clearer when querying across tenants
- Less risky during transition period

**Trade-off:**
- More lines of code
- More opportunity for mistakes if developer forgets WHERE clause
- Testing automation needed to catch leaks

### D. Sharding Integration

```ruby
# In PwbTenant::ApplicationRecord
connects_to shards: {
  default: { writing: :primary, reading: :primary },
  shard_1: { writing: :tenant_shard_1, reading: :tenant_shard_1 }
}
```

When `ActsAsTenant.current_tenant` is set:
- Queries automatically route to the website's shard
- Based on `website.shard_name` value
- Transparent to developers using PwbTenant:: models

---

## 9. ROUTING CONFIGURATION

### A. Routes Structure

**File:** `/config/routes.rb`

Public routes (platform subdomains + custom domains):
```ruby
constraints(SubdomainRequired) do
  # Matches: site1.propertywebbuilder.com, www.example.com, etc.
  scope module: :pwb do
    get '/pages/:slug', to: 'pages#show'
    resources :properties, only: [:index, :show]
    post '/contact', to: 'contact#create'
  end
end
```

Admin routes (site1.propertywebbuilder.com/admin):
```ruby
namespace :site_admin do
  resources :properties
  resources :messages
  resources :pages
end
```

Cross-tenant admin (admin.propertywebbuilder.com, tenant-admin.example.com):
```ruby
namespace :tenant_admin do
  resources :websites
  resources :users
  resources :subscriptions
end
```

### B. Route Constraints

**Constraint Logic:**
```ruby
class SubdomainRequired
  def matches?(request)
    request.subdomain.present? && request.subdomain != 'www'
  end
end
```

---

## 10. ENVIRONMENT VARIABLES & CONFIGURATION

### A. Key Environment Variables

**Tenant Domain Configuration:**
```bash
# Platform domains for subdomain-based routing (comma-separated)
PLATFORM_DOMAINS=propertywebbuilder.com,pwb.localhost,e2e.localhost

# Allow unverified custom domains (dev/test only)
ALLOW_UNVERIFIED_DOMAINS=true  # Default: true in dev/test, false in production

# Platform IP for A record DNS configuration (apex domains)
PLATFORM_IP=123.45.67.89
```

**Admin Access:**
```bash
# Email addresses allowed to access tenant admin panel (comma-separated)
TENANT_ADMIN_EMAILS=admin@example.com,super@example.com

# Bypass all auth checks (development only!)
BYPASS_ADMIN_AUTH=true

# Override subscription tier for development
DEV_SUBSCRIPTION_PLAN=enterprise  # starter, professional, enterprise
```

**Database Configuration:**
```bash
# Primary database connection
PWB_DATABASE_URL=postgresql://user:pass@localhost/pwb_production
PWB_DATABASE_PASSWORD=password123

# Shard 1 database connection
PWB_TENANT_SHARD_1_DATABASE_URL=postgresql://user:pass@localhost/pwb_shard_1

# Staging environment
PWB_STAGING_DATABASE_URL=postgresql://...
PWB_STAGING_TENANT_SHARD_1_DATABASE_URL=postgresql://...
```

### B. Tenant Domains Initializer

**File:** `/config/initializers/tenant_domains.rb`

```ruby
Rails.application.config.tenant_domains = {
  platform_domains: ENV.fetch('PLATFORM_DOMAINS', 
    'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost').split(',').map(&:strip),
  
  allow_unverified_domains: ENV.fetch('ALLOW_UNVERIFIED_DOMAINS', 'false') == 'true' ||
                            Rails.env.development? || Rails.env.test?,
  
  verification_prefix: '_pwb-verification',
  
  platform_ip: ENV.fetch('PLATFORM_IP', nil)
}
```

---

## 11. SECURITY & DATA ISOLATION

### A. Tenant Isolation Mechanisms

1. **Subdomain Resolution:**
   - Each subdomain maps to exactly one website
   - Case-insensitive, URL-encoded subdomain validation
   - Reserved subdomains prevent collision

2. **Row-Level Filtering:**
   - Every query must include `WHERE website_id = ?`
   - Foreign key constraints prevent orphaned records
   - Unique indexes prevent cross-tenant conflicts

3. **Thread-Local Storage:**
   - `Pwb::Current.website` cleared between requests
   - Request context isolated per thread
   - No global state leakage

4. **Database Constraints:**
   - Foreign keys enforce referential integrity
   - Unique indexes per website prevent collisions
   - Non-nullable website_id on scoped tables

### B. Common Vulnerabilities & Protections

**Vulnerability: Unauthorized website access**
- Protection: SubdomainTenant concern enforces subdomain routing
- Each controller only sees current_website

**Vulnerability: SQL injection with website_id**
- Protection: Use parameterized queries (Rails default)
- Never build WHERE clauses with string interpolation

**Vulnerability: Forgetting WHERE clause**
- Protection: Code review, tests, monitoring
- Recommendations:
  - Automated tests for tenant isolation
  - Query logging to detect cross-tenant queries
  - Linting rules to enforce website_id filtering

**Vulnerability: Cross-tenant API access**
- Protection: X-Website-Slug header validation
- Only accessible website from request context

### C. Recommended Security Practices

1. **In Controllers:**
   - Always start queries with `current_website.records` or `Model.where(website_id: ...)`
   - Return 404 if record not found for website
   - Never use `.unscoped()` except in TenantAdminController

2. **In Models:**
   - Add `belongs_to :website` to ensure association
   - Default scope with website_id (optional, not adopted here)
   - Validate website_id presence

3. **In Tests:**
   - Create fixtures with multiple websites
   - Verify queries filter by website
   - Test authorization boundaries
   - Test cross-tenant isolation

4. **In Monitoring:**
   - Log all unscoped queries
   - Alert on unexpected website_id patterns
   - Audit tenant admin access
   - Monitor provisioning failures

---

## 12. DATA MODEL RELATIONSHIPS

### A. Website-Centric Model Graph

```
┌─────────────────────────────────────────────────────────────────┐
│                    Pwb::Website (TENANT)                        │
│  - id, subdomain, slug, custom_domain                           │
│  - company_display_name, theme_name, shard_name                 │
│  - Configuration (search_config, styles_config, etc.)           │
└────┬────────────────────────────────────────────────────────────┘
     │
     ├─ has_one :agency
     ├─ has_one :subscription
     │
     ├─ has_many :pages              (scoped)
     ├─ has_many :contents           (scoped)
     ├─ has_many :messages           (scoped)
     ├─ has_many :contacts           (scoped)
     ├─ has_many :props              (scoped, legacy)
     ├─ has_many :realty_assets      (scoped)
     ├─ has_many :listed_properties  (scoped, materialized view)
     ├─ has_many :field_keys         (scoped)
     ├─ has_many :links              (scoped)
     ├─ has_many :media              (scoped)
     │
     ├─ has_many :users             (can belong to multiple)
     ├─ has_many :members           (through user_memberships)
     └─ has_many :user_memberships  (join table)
```

### B. User Multi-Website Relationships

```
Pwb::User (Global)
├─ email (unique)
├─ has_many :user_memberships
├─ has_many :websites (through user_memberships)
│
└─ Pwb::UserMembership (Join Table)
   ├─ user_id (FK to users)
   ├─ website_id (FK to websites)
   ├─ role (owner/admin/member)
   ├─ active (boolean)
   │
   └─ Can create:
      - User 'alice@example.com' owns website 'site1'
      - User 'alice@example.com' is admin on website 'site2'
      - User 'alice@example.com' is member on website 'site3'
```

---

## 13. DOCUMENTATION FILES

The project includes comprehensive multi-tenancy documentation:

**Location:** `/docs/multi_tenancy/`

**Key Files:**
1. **README.md** - Navigation and quick reference
2. **MULTI_TENANCY_ARCHITECTURE.md** - Diagrams and flow (THIS FILE)
3. **routing_implementation.md** - Technical reference with line numbers
4. **routing_architecture.md** - Visual diagrams and relationships
5. **multi_tenancy_guide.md** - Developer guide with examples
6. **MULTI_TENANCY_QUICK_REFERENCE.md** - Patterns and common mistakes
7. **DEVELOPER_GUIDE.md** - Best practices
8. **MULTI_TENANCY_SECURITY_AUDIT.md** - Security analysis
9. **SUBSCRIPTION_PLAN_SYSTEM.md** - Tier management
10. **PREMIUM_ENTERPRISE_SHARDING_PLAN.md** - Sharding strategy

---

## 14. SUMMARY & QUICK REFERENCE

### Current Tenancy Implementation

| Aspect | Implementation |
|--------|-----------------|
| **Tenant Identification** | Subdomain + custom domain + slug |
| **Database Strategy** | Single shared database with optional sharding |
| **Scoping Mechanism** | Manual WHERE clauses + optional acts_as_tenant |
| **Thread-Local Context** | Pwb::Current.website (cleared per request) |
| **Multi-Database Support** | Yes (primary + tenant_shard_1) |
| **Model Namespace** | Pwb:: (non-scoped), PwbTenant:: (scoped, not adopted) |
| **Controller Tiers** | 3 tiers (Public, SiteAdmin, TenantAdmin) |
| **Authorization** | Pwb::UserMembership + TENANT_ADMIN_EMAILS env var |
| **Seed Packs** | YAML-based pre-configured bundles |
| **Domain Types** | Platform subdomains + custom domains |
| **Reserved Subdomains** | www, api, admin, app, mail, ftp, etc. |

### For New Developers

**Essential Files to Understand:**
1. `/app/models/pwb/website.rb` - The tenant model
2. `/app/controllers/concerns/subdomain_tenant.rb` - How subdomains map to tenants
3. `/app/models/concerns/pwb/website_domain_configurable.rb` - Domain resolution
4. `/config/initializers/acts_as_tenant.rb` - Tenant configuration
5. `/config/initializers/tenant_domains.rb` - Domain routing config

**Essential Patterns:**
```ruby
# Always scope to current website
@data = Pwb::Model.where(website_id: current_website.id)

# Or use association
@data = current_website.model_name

# Never do this:
@data = Pwb::Model.all  # ❌ Returns all data from all websites!

# Custom domains work transparently
# If current_website.custom_domain is set and verified,
# requests to that domain will still route to the correct website
```

**When to Use TenantAdmin vs SiteAdmin:**
- **SiteAdmin** - Managing one website's data (properties, pages, etc.)
- **TenantAdmin** - Managing multiple websites (billing, users, platform admin)

---

## Conclusion

PropertyWebBuilder implements a well-architected multi-tenant system that:
- Uses subdomains as the primary tenant identifier
- Supports custom domains for white-labeling
- Stores all data in a single database with row-level isolation
- Supports optional database sharding for scale
- Provides seed packs for quick website provisioning
- Has clear separation of concerns (Public, SiteAdmin, TenantAdmin)

The system is production-ready with comprehensive documentation and security considerations built in.
