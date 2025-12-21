# Website Provisioning System Overview

## Project Structure

This is a multi-tenant Ruby on Rails application where each website is an independent tenant. The system provides comprehensive provisioning, seeding, and configuration infrastructure.

---

## 1. Website Model - Core Entity

### File Location
`/app/models/pwb/website.rb`

### Database Table
`pwb_websites`

### Key Columns

#### Identification & Routing
- `id` (primary key)
- `subdomain` (string, unique) - For subdomain-based routing (e.g., `tenant1.propertywebbuilder.com`)
- `slug` (string) - URL-friendly identifier
- `custom_domain` (string, unique, nullable) - For custom domain routing (e.g., `example.com`)
- `custom_domain_verified` (boolean) - Verification status of custom domain
- `custom_domain_verified_at` (datetime) - Timestamp of domain verification
- `custom_domain_verification_token` (string) - Token for DNS TXT record verification

#### Company Information
- `company_display_name` (string) - Display name for the company
- `theme_name` (string) - Theme identifier (e.g., 'bristol')
- `email_for_general_contact_form` (string)
- `email_for_property_contact_form` (string)

#### Localization & Currency
- `supported_locales` (text array, default: `["en-UK"]`) - List of supported language locales
- `default_client_locale` (string, default: `"en-UK"`) - Frontend default locale
- `default_admin_locale` (string, default: `"en-UK"`) - Admin interface default locale
- `default_currency` (string, default: `"EUR"`) - Default currency for listings
- `default_area_unit` (integer enum: `0=sqmt`, `1=sqft`) - Default area measurement unit
- `supported_currencies` (text array) - List of supported currencies for conversion

#### Styling & Customization
- `style_variables_for_theme` (json, default: `{}`) - Theme-specific style variables
- `raw_css` (text) - Custom CSS overrides
- `configuration` (json, default: `{}`) - General configuration JSON

#### SEO & Analytics
- `analytics_id` (string) - Google Analytics or similar ID
- `analytics_id_type` (integer) - Type of analytics provider
- `seo_*` fields - SEO metadata fields

#### Pricing Configuration (Arrays)
- `sale_price_options_from` - Options for minimum sale price filter
- `sale_price_options_till` - Options for maximum sale price filter
- `rent_price_options_from` - Options for minimum rental price filter
- `rent_price_options_till` - Options for maximum rental price filter

#### Notifications & Integrations
- `ntfy_*` fields - Ntfy notification settings
- `external_image_mode` - Configuration for external image handling

#### Flags (Using FlagShihTzu)
- `landing_hide_for_rent` - Hide rental listings on landing page
- `landing_hide_for_sale` - Hide sale listings on landing page
- `landing_hide_search_bar` - Hide search bar on landing page

#### Timestamps
- `created_at`
- `updated_at`

### Associations

#### Content & Pages
```ruby
has_many :page_contents, class_name: 'Pwb::PageContent'
has_many :contents, through: :page_contents, class_name: 'Pwb::Content'
has_many :ordered_visible_page_contents, -> { ordered_visible }, class_name: 'Pwb::PageContent'
has_many :pages, class_name: 'Pwb::Page'
has_many :links, class_name: 'Pwb::Link'
```

#### Properties & Listings
```ruby
has_many :listed_properties, class_name: 'Pwb::ListedProperty', foreign_key: 'website_id'
has_many :props, class_name: 'Pwb::Prop', foreign_key: 'website_id'  # Legacy
has_many :realty_assets, class_name: 'Pwb::RealtyAsset', foreign_key: 'website_id'
has_many :sale_listings, through: :realty_assets, class_name: 'Pwb::SaleListing'
has_many :rental_listings, through: :realty_assets, class_name: 'Pwb::RentalListing'
```

#### Users & Memberships
```ruby
has_many :users  # Direct primary website assignment
has_many :user_memberships, dependent: :destroy  # Multi-website support
has_many :members, through: :user_memberships, source: :user
```

#### Configuration
```ruby
has_many :contacts, class_name: 'Pwb::Contact'
has_many :messages, class_name: 'Pwb::Message'
has_many :website_photos
has_many :field_keys, class_name: 'Pwb::FieldKey', foreign_key: :pwb_website_id
has_one :agency, class_name: 'Pwb::Agency'
```

#### Theme Integration
```ruby
belongs_to_active_hash :theme, optional: true, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"
```

### Key Methods

#### Subdomain/Domain Lookup
- `find_by_subdomain(subdomain)` - Case-insensitive subdomain lookup
- `find_by_custom_domain(domain)` - Custom domain lookup with www prefix handling
- `find_by_host(host)` - Primary lookup method (tries custom domain, then subdomain)
- `extract_subdomain_from_host(host)` - Extracts subdomain from platform domain host

#### Domain Handling
- `platform_domain?(host)` - Checks if host is a platform domain
- `platform_domains` - Returns configured platform domains from ENV

#### Validations
- Subdomain uniqueness (case-insensitive), format, and length validation
- Custom domain uniqueness, format validation
- Subdomain cannot be in RESERVED_SUBDOMAINS list (www, api, admin, etc.)
- Custom domain cannot be a platform domain

#### Custom Domain Verification
- `generate_domain_verification_token!` - Creates a verification token
- `verify_custom_domain!` - Verifies domain ownership via DNS TXT record
- `custom_domain_active?` - Checks if domain is verified or allowed in dev/test

#### Configuration & Style
- `style_variables` - Get/set default style variables
- `style_settings` - Bulk setting of styles
- `get_element_class(element_name)` - Get CSS class for an element
- `get_style_var(var_name)` - Get style variable value

#### Users & Access
- `admins` - Get active admin and owner members
- `accessible_websites` - Get websites user has access to

#### Navigation & Content
- `admin_page_links` - Get cached admin page links
- `top_nav_display_links` - Get visible top navigation links
- `footer_display_links` - Get visible footer links

#### Other
- `primary_url` - Get primary URL (custom domain or subdomain)
- `logo_url` - Get logo image URL

---

## 2. User Model - Authentication

### File Location
`/app/models/pwb/user.rb`

### Database Table
`pwb_users`

### Key Columns
- `id` (primary key)
- `email` (string, unique) - User email for authentication
- `encrypted_password` (string) - Devise password encryption
- `website_id` (foreign key, optional) - Primary website assignment
- `admin` (boolean) - Legacy admin flag
- `firebase_uid` (string) - Firebase authentication ID
- `sign_in_count` (integer) - Devise tracking
- `current_sign_in_at` (datetime) - Last sign in timestamp
- `current_sign_in_ip` (string)
- `last_sign_in_at` (datetime)
- `last_sign_in_ip` (string)
- `locked_at` (datetime) - Account lockout timestamp
- `unlock_token` (string) - For account unlock
- Devise columns: reset_password_token, reset_password_sent_at, remember_created_at

### Devise Modules
- `:database_authenticatable` - Email/password authentication
- `:registerable` - User registration
- `:recoverable` - Password reset via email
- `:rememberable` - Remember me cookie
- `:trackable` - Sign in tracking
- `:validatable` - Email/password validation
- `:lockable` - Account lockout after failed attempts
- `:timeoutable` - Session timeout
- `:omniauthable` - OAuth (Facebook)

### Associations
```ruby
belongs_to :website, optional: true  # Primary website
has_many :authorizations  # OAuth authorizations
has_many :auth_audit_logs, dependent: :destroy
has_many :user_memberships, dependent: :destroy  # Multi-website memberships
has_many :websites, through: :user_memberships
```

### Key Methods

#### Multi-Website Access
- `admin_for?(website)` - Check if admin/owner for a website
- `role_for(website)` - Get user's role for a specific website
- `accessible_websites` - Get websites user can access (active memberships)
- `can_access_website?(website)` - Check if user can access a website

#### Authentication & Validation
- `active_for_authentication?` - Devise hook - checks if user can sign in on current website
- `inactive_message` - Custom error message if auth fails

#### OAuth
- `find_for_oauth(auth, website: nil)` - Find or create user from OAuth auth
- `create_authorization(auth)` - Create authorization record

#### Security & Audit
- `recent_auth_activity(limit: 20)` - Get recent authentication attempts
- `suspicious_activity?(threshold: 5, since: 1.hour.ago)` - Check for suspicious activity
- Automatic logging of registrations and lockout events

---

## 3. UserMembership Model - Multi-Tenancy Connection

### File Location
`/app/models/pwb/user_membership.rb`

### Database Table
`pwb_user_memberships`

### Key Columns
- `id` (primary key)
- `user_id` (foreign key) - Reference to Pwb::User
- `website_id` (foreign key) - Reference to Pwb::Website
- `role` (string, default: 'member') - User's role for this website
- `active` (boolean, default: true) - Membership status
- `created_at`
- `updated_at`

### Unique Constraint
- Composite unique index on `(user_id, website_id)` - Each user can only have one membership per website

### Roles (Hierarchical)
```ruby
ROLES = %w[owner admin member viewer].freeze
```

- `owner` - Full control, can manage other users
- `admin` - Administrative access
- `member` - Standard member access
- `viewer` - Read-only access

### Associations
```ruby
belongs_to :user, class_name: 'Pwb::User'
belongs_to :website, class_name: 'Pwb::Website'
```

### Key Methods

#### Role Management
- `role_hierarchy` - Returns hash mapping roles to their level (0-3)
- `role_level` - Get numeric level of this membership's role
- `admin?` - Check if owner or admin
- `owner?` - Check if owner role
- `active?` - Check if membership is active

#### Permissions
- `can_manage?(other_membership)` - Check if this user can manage another membership (based on role hierarchy)

### Scopes
```ruby
scope :active, -> { where(active: true) }
scope :inactive, -> { where(active: false) }
scope :admins, -> { where(role: ['owner', 'admin']) }
scope :owners, -> { where(role: 'owner') }
scope :for_website, ->(website) { where(website: website) }
scope :for_user, ->(user) { where(user: user) }
```

---

## 4. Subdomain & Domain Handling

### Platform Domains Configuration
- Configured via `PLATFORM_DOMAINS` environment variable
- Default: `propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost`
- Each platform domain supports subdomains for multi-tenancy

### Subdomain Resolution
1. Format: `{subdomain}.{platform_domain}` (e.g., `tenant1.propertywebbuilder.com`)
2. Case-insensitive lookup
3. Format validation: alphanumeric and hyphens only, 2-63 characters
4. Reserved subdomains: www, api, admin, app, mail, ftp, smtp, etc.

### Custom Domain Handling
1. Format: Standard domain (e.g., `example.com` or `www.example.com`)
2. Supports www prefix normalization
3. Verification via DNS TXT record: `_pwb-verification.{domain}` containing verification token
4. Unique constraint per domain (allows www variants to be treated as one)
5. Custom domain cannot be a platform domain

### Routing Precedence
1. If host is NOT a platform domain, try custom domain lookup first
2. If platform domain, extract subdomain and lookup by subdomain

---

## 5. Current Website Context (Multi-Tenancy)

### File Location
`/app/models/pwb/current.rb`

### Implementation
Uses Rails `ActiveSupport::CurrentAttributes` to store request-scoped context:
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :website
end
```

### Usage
```ruby
Pwb::Current.website = website_instance
current_website = Pwb::Current.website
```

### Purpose
- Maintains website context throughout request lifecycle
- Used by seeding operations, authentication, and data isolation
- Thread-safe and request-scoped

---

## 6. Seeding System

### Overview
PropertyWebBuilder provides a comprehensive, flexible seeding system with multiple approaches:

1. **Basic Seeder** (`Pwb::Seeder`) - Simple one-time seed
2. **Seed Packs** (`Pwb::SeedPack`) - Scenario-based pre-configured bundles
3. **Seed Runner** (`Pwb::SeedRunner`) - Enhanced seeder with safety features

### 6.1 Basic Seeder

#### File Location
`/lib/pwb/seeder.rb`

#### Usage
```ruby
# Seed default website
Pwb::Seeder.seed!

# Seed specific website
website = Pwb::Website.find_by(subdomain: 'tenant1')
Pwb::Seeder.seed!(website: website)

# Skip properties for production
Pwb::Seeder.seed!(website: website, skip_properties: true)
```

#### What Gets Seeded
1. **Translations** - I18n data (13 languages)
2. **Agency** - Company information and address
3. **Website Settings** - Configuration and styling
4. **Field Keys** - Property field definitions
5. **Links** - Navigation links with multi-language titles
6. **Properties** - Sample properties (6 samples if under 4 exist)
7. **Users** - Admin and default users
8. **Contacts** - Sample contact records
9. **Page Parts** - Page section templates (via PagesSeeder)

#### Seed Files Location
`/db/yml_seeds/`
- `agency.yml` - Agency configuration
- `agency_address.yml` - Agency address
- `website.yml` - Website defaults
- `field_keys.yml` - Property field keys
- `links.yml` - Navigation links
- `users.yml` - User accounts
- `contacts.yml` - Contact records
- `prop/` - Sample property YAML files
  - `villa_for_sale.yml`
  - `villa_for_rent.yml`
  - `flat_for_sale.yml`
  - `flat_for_rent.yml`
  - `flat_for_sale_2.yml`
  - `flat_for_rent_2.yml`

#### Property Seeding
- Creates normalized property records:
  - `Pwb::RealtyAsset` - Physical property data
  - `Pwb::SaleListing` - For-sale listing with translations
  - `Pwb::RentalListing` - For-rent listing with translations
- Automatically refreshes `Pwb::ListedProperty` materialized view
- Supports photo attachment from URLs or files
- Uses Mobility gem for multi-language translations

### 6.2 Seed Packs

#### File Location
`/lib/pwb/seed_pack.rb`

#### Pack Directory Structure
`/db/seeds/packs/{pack_name}/`
```
pack.yml                  # Configuration file
agency.yml                # Agency data
website.yml              # Website configuration
field_keys.yml           # Field key definitions
links.yml                # Navigation links
pages/                   # Page definitions
  home.yml
  about-us.yml
page_parts/              # Custom page parts (optional)
  home__hero_centered.yml
content/                 # Content translations
  logo.yml
  footer_text.yml
properties/              # Property definitions
  villa_01.yml
  apartment_01.yml
images/                  # Property images
  villa_01.jpg
translations/            # Locale-specific translations
  es.yml
  de.yml
users:
  - email: admin@example.com
    role: admin
```

#### Pack Configuration (pack.yml)
```yaml
name: spain_luxury
display_name: "Spanish Luxury Real Estate"
description: "Estate agent specializing in luxury properties"
version: "1.0"
inherits_from: base  # Optional parent pack

website:
  theme_name: bristol
  default_client_locale: es
  supported_locales: [es, en, de]
  currency: EUR
  area_unit: sqm

agency:
  display_name: "Costa Luxury Properties"
  email: "info@costaluxury.es"
  phone: "+34 952 123 456"
  address:
    street_address: "Avenida del Mar 45"
    city: Marbella
    country: Spain

users:
  - email: admin@costaluxury.es
    role: admin
    password: demo123
  - email: agent@costaluxury.es
    role: agent
    password: demo123

page_parts:
  home:
    - key: heroes/hero_centered
      order: 1
    - key: features/feature_grid_3col
      order: 2
```

#### Available Packs
Located in `/db/seeds/packs/`:
1. **base** - Foundation pack with common data
2. **spain_luxury** - Spanish luxury real estate scenario
3. **netherlands_urban** - Dutch urban properties

#### Usage
```ruby
# List available packs
packs = Pwb::SeedPack.available

# Find specific pack
pack = Pwb::SeedPack.find('spain_luxury')

# Apply to website
pack.apply!(website: website)

# Dry-run preview
pack.apply!(website: website, options: { dry_run: true })

# Skip specific sections
pack.apply!(
  website: website,
  options: {
    skip_properties: true,
    skip_users: true,
    skip_translations: true
  }
)

# Get preview without applying
preview = pack.preview
# Returns: {
#   pack_name: 'spain_luxury',
#   display_name: 'Spanish Luxury Real Estate',
#   properties: 8,
#   locales: ['es', 'en', 'de'],
#   users: 2
# }
```

#### Pack Inheritance
Packs can inherit from parent packs:
```yaml
inherits_from: base  # Child pack applies parent first
```

This allows:
- Reusable base configurations
- Override-capable child packs
- Reduced duplication

### 6.3 Seed Runner (Enhanced Seeding)

#### File Location
`/lib/pwb/seed_runner.rb`

#### Features
- Interactive mode with prompts for existing data
- Dry-run preview mode
- Multiple operation modes (create, update, upsert)
- Safety warnings and validations
- Detailed progress logging

#### Usage
```ruby
# Interactive mode (default) - prompts for updates
Pwb::SeedRunner.run(website: website)

# Create-only mode - skip existing records
Pwb::SeedRunner.run(website: website, mode: :create_only)

# Force update mode - update without prompting
Pwb::SeedRunner.run(website: website, mode: :force_update)

# Dry-run mode - preview without changes
Pwb::SeedRunner.run(website: website, dry_run: true)

# Full options
Pwb::SeedRunner.run(
  website: website,
  mode: :force_update,
  dry_run: false,
  skip_properties: false,
  skip_translations: false,
  verbose: true
)
```

#### Modes
- `:interactive` - Prompts user before updating existing records
- `:create_only` - Only creates new records, skips existing
- `:force_update` - Updates existing records without prompting
- `:upsert` - Creates or updates all records

---

## 7. Rake Tasks for Website Provisioning

### File Location
`/lib/tasks/pwb_tasks.rake`

### Database Seeding Tasks

#### Create Tenant
```bash
# Create new website with seeding
rake pwb:db:create_tenant[subdomain,slug,name]

# Examples
rake pwb:db:create_tenant[my-agency]
rake pwb:db:create_tenant[luxury-homes,luxury,Luxury Homes Inc]
SKIP_PROPERTIES=true rake pwb:db:create_tenant[bare-site]
```

Creates a new website and runs full seed setup with optional properties.

#### Seed Default Website
```bash
rake pwb:db:seed
SKIP_PROPERTIES=true rake pwb:db:seed
```

Seeds the first (or default) website with all data.

#### Seed Specific Tenant
```bash
rake pwb:db:seed_tenant[subdomain]
rake pwb:db:seed_tenant[luxury-homes]
SKIP_PROPERTIES=true rake pwb:db:seed_tenant[bare-site]
```

Seeds a specific tenant website.

#### Seed All Tenants
```bash
rake pwb:db:seed_all_tenants
SKIP_PROPERTIES=true rake pwb:db:seed_all_tenants
```

Seeds all existing websites in the database.

#### Enhanced Seeding
```bash
rake pwb:db:seed_enhanced
SEED_MODE=create_only rake pwb:db:seed_enhanced
DRY_RUN=true rake pwb:db:seed_enhanced
rake pwb:db:seed_tenant_enhanced[subdomain]
```

Uses SeedRunner for interactive, safe seeding with preview mode.

#### List Tenants
```bash
rake pwb:db:list_tenants
```

Shows all existing websites with their IDs, subdomains, and slugs.

#### Validate Seeds
```bash
rake pwb:db:validate_seeds
```

Validates all seed files without running them.

### Environment Variables
- `SKIP_PROPERTIES=true` - Skip sample property seeding
- `SEED_MODE=create_only|force_update|upsert|interactive` - Control how existing records are handled
- `DRY_RUN=true` - Preview changes without applying
- `VERBOSE=false` - Reduce output verbosity

---

## 8. Theme Configuration System

### Theme Selection
- Themes managed as ActiveHash records
- Website references theme by name (e.g., 'bristol')
- Default theme: 'bristol'

### Theme-Specific Styling
Stored in `style_variables_for_theme` JSON column:
```json
{
  "default": {
    "primary_color": "#e91b23",
    "secondary_color": "#3498db",
    "action_color": "green",
    "body_style": "siteLayout.wide",
    "theme": "light",
    "font_primary": "Open Sans",
    "font_secondary": "Vollkorn",
    "border_radius": "0.5rem",
    "container_padding": "1rem"
  }
}
```

### Preset Styles
- `Pwb::PresetStyle` provides pre-configured style sets
- Websites can be configured with preset style themes

---

## 9. Field Keys System

### Purpose
Define custom property field definitions (types, states, features, amenities)

### File Location
- Model: `/app/models/pwb/field_key.rb`
- Seeding: Via `field_keys.yml`

### Structure
Each field key has:
- `global_key` - Unique identifier (e.g., 'types.villa')
- `tag` - Category tag (e.g., 'property-types')
- `pwb_website_id` - Website association
- `visible` - Whether to show in UI

### Seed Format
```yaml
- global_key: 'types.villa'
  tag: 'property-types'
  visible: true
- global_key: 'states.good'
  tag: 'property-states'
  visible: true
- global_key: 'features.pool'
  tag: 'property-features'
  visible: true
```

---

## 10. Onboarding & Setup Flows

### Current Implementation
No dedicated onboarding flow. Setup happens via:

1. **Administrative Creation** - Admins use rake tasks
   ```bash
   rake pwb:db:create_tenant[my-domain]
   ```

2. **Seed Pack Application** - Pre-configured scenarios
   ```ruby
   pack = Pwb::SeedPack.find('spain_luxury')
   pack.apply!(website: website)
   ```

3. **Signup Flow** - Users can register (via Devise)
   - Registration creates user with primary website
   - Multi-website membership created automatically if needed

4. **Firebase Authentication** - Alternative to email/password
   - `firebase_uid` stored on user
   - OAuth integration via Authorization model

### User Signup Process
1. User registers via email/password (Devise)
2. User assigned to current website or default website
3. UserMembership created with 'member' role
4. User redirected to website admin/dashboard

---

## 11. Multi-Tenancy Design Pattern

### Architecture Decisions

#### Shared Database, Separate Schemas
- Single PostgreSQL database
- All tenants' data in same tables
- Tenant isolation via `website_id` foreign keys

#### Routing
- Subdomain routing: `tenant.propertywebbuilder.com`
- Custom domain routing: `tenant.customdomain.com`
- Both route to same application instance
- Website identified via `Pwb::Website.find_by_host(request.host)`

#### User Association
- Users belong to at least one website (primary)
- Users can belong to multiple websites via UserMemberships
- Access control per website via membership role

#### Data Scoping
Tenant-scoped models available in two variants:
- `Pwb::*` - Application records (not tenant-scoped)
- `PwbTenant::*` - Tenant-scoped variants for web requests

### Multi-Tenancy Enforcement
1. **At Route Level** - Tenant identified from host
2. **At Model Level** - Associations use website_id foreign keys
3. **At Query Level** - Queries scoped to `current_website`
4. **At User Level** - Authentication checks website access

---

## 12. Database Schema Summary

### Key Tables
| Table | Purpose | Key Columns |
|-------|---------|------------|
| `pwb_websites` | Tenant websites | id, subdomain, custom_domain, theme_name, default_currency |
| `pwb_users` | User accounts | id, email, website_id, firebase_uid, admin |
| `pwb_user_memberships` | Multi-website access | user_id, website_id, role, active |
| `pwb_realty_assets` | Physical properties | id, website_id, reference, city, postal_code |
| `pwb_sale_listings` | For-sale listings | id, realty_asset_id, price_cents, visible |
| `pwb_rental_listings` | For-rent listings | id, realty_asset_id, price_cents, visible |
| `pwb_prop_photos` | Property images | id, realty_asset_id, image (ActiveStorage) |
| `pwb_pages` | CMS pages | id, website_id, slug, title |
| `pwb_page_parts` | Page sections | id, website_id, page_slug, page_part_key |
| `pwb_links` | Navigation links | id, website_id, slug, link_url |
| `pwb_field_keys` | Property field definitions | id, global_key, tag, pwb_website_id |
| `pwb_contacts` | Contact records | id, website_id, primary_email, name |
| `pwb_messages` | Contact messages | id, website_id, sender_email, message |
| `pwb_agencies` | Agency information | id, website_id, display_name, email_primary |
| `pwb_auth_audit_logs` | Auth activity | id, user_id, action, success, ip_address |

### Materialized Views
- `pwb_properties` - Read-only optimized view of RealtyAsset + Listings
  - Automatically refreshed when properties change
  - Used for faster queries on frontend

---

## 13. Example Workflows

### Create and Provision a New Website
```bash
# Step 1: Create website with seeding
rake pwb:db:create_tenant[my-luxury-agency]

# Step 2: Access the new site
# Browse to: http://my-luxury-agency.lvh.me:3000 (development)

# Step 3: Login with default admin
# Email: admin@my-luxury-agency.com
# Password: password
```

### Provision with Specific Scenario
```ruby
# Create bare website (no properties)
website = Pwb::Website.create!(
  subdomain: 'spain-luxury',
  company_display_name: 'Costa Luxury Properties',
  theme_name: 'bristol'
)

# Apply Spain luxury scenario
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```

### Add User to Existing Website
```ruby
# Create user
user = Pwb::User.create!(
  email: 'agent@example.com',
  password: 'secure_password',
  password_confirmation: 'secure_password',
  website_id: website.id
)

# Create membership with specific role
Pwb::UserMembership.create!(
  user: user,
  website: website,
  role: 'member',  # owner, admin, member, viewer
  active: true
)
```

### Give User Access to Multiple Websites
```ruby
# User already has membership to website1
# Add membership to website2
Pwb::UserMembership.create!(
  user: user,
  website: website2,
  role: 'member',
  active: true
)

# Now user can access both websites
user.websites  # => [website1, website2]
```

### Seed Specific Content for a Website
```ruby
# Use enhanced seed runner with options
Pwb::SeedRunner.run(
  website: website,
  mode: :create_only,  # Don't overwrite existing
  skip_properties: false,  # Include properties
  skip_translations: true,  # Skip i18n (already loaded)
  verbose: true
)
```

### Preview What Would Be Seeded
```ruby
# Dry-run mode
Pwb::SeedRunner.run(
  website: website,
  dry_run: true,
  verbose: true
)

# Or with seed pack
pack = Pwb::SeedPack.find('base')
preview = pack.preview
# => {
#   pack_name: 'base',
#   display_name: 'Base Pack',
#   properties: 0,
#   locales: ['en'],
#   users: 0
# }
```

---

## 14. Key Constraints & Validations

### Website Validations
- Subdomain: unique, 2-63 chars, alphanumeric + hyphens, can't be reserved
- Custom domain: unique, valid domain format, can't be platform domain
- Theme name: must reference existing Pwb::Theme

### User Validations
- Email: unique, valid email format (Devise)
- Password: minimum length, complexity (Devise)
- Must have primary website OR at least one membership

### UserMembership Validations
- Role: must be in ROLES list (owner, admin, member, viewer)
- Active: boolean (true/false only)
- User-Website pair: unique (one membership per combination)

### Property Validations
- Reference: unique per website
- Coordinates: valid lat/long if provided
- Listing prices: positive integers

---

## 15. Important Files Summary

| File | Purpose |
|------|---------|
| `/app/models/pwb/website.rb` | Website model with routing & validation |
| `/app/models/pwb/user.rb` | User authentication & multi-website |
| `/app/models/pwb/user_membership.rb` | User-Website relationship with roles |
| `/lib/pwb/seeder.rb` | Basic seeding for a website |
| `/lib/pwb/seed_pack.rb` | Scenario-based seed packs |
| `/lib/pwb/seed_runner.rb` | Enhanced seeding with safety |
| `/lib/tasks/pwb_tasks.rake` | Rake tasks for provisioning |
| `/db/yml_seeds/` | Seed data YAML files |
| `/db/seeds/packs/` | Seed pack configurations |
| `/config/initializers/devise.rb` | Devise configuration |

---

## 16. Configuration Files

### Environment Variables
```bash
# Routing configuration
PLATFORM_DOMAINS=propertywebbuilder.com,pwb.localhost,localhost

# Rails environment
RAILS_ENV=production

# Database
DATABASE_URL=postgresql://user:pass@host/db

# Email (for password resets, etc.)
MAIL_FROM_ADDRESS=noreply@example.com
SMTP_ADDRESS=smtp.sendgrid.net
```

### Seed Pack Rake Tasks
```bash
# See available seed packs
rake pwb:db:seed_packs:list

# Create website from seed pack
rake pwb:db:seed_packs:apply[website_id,pack_name]
```

---

## 17. Future Considerations

### Not Yet Implemented
1. **Signup Flow** - No self-service website creation yet
2. **Payment/Billing** - No subscription or payment processing
3. **Tenant Isolation** - Database-level row-level security
4. **API Quotas** - No rate limiting or usage tracking
5. **Automated Cleanup** - No scheduled cleanup of old data

### Potential Enhancements
1. **Website Creation UI** - Self-service dashboard for new tenants
2. **One-Click Setup** - Simplified onboarding process
3. **Template Library** - More scenario templates
4. **White-Label** - Custom branding per tenant
5. **Multi-Database** - Separate schema per tenant option

---

## Summary

This multi-tenant Rails application provides:

1. **Website Models** - Flexible tenant definition with subdomain and custom domain support
2. **User Management** - Devise authentication with multi-website memberships and role-based access
3. **Seeding Infrastructure** - Multiple seeding approaches from basic to scenario-based
4. **Provisioning Tasks** - Rake tasks for creating and managing websites
5. **Configuration System** - Themes, field keys, and styling per website
6. **Multi-Tenancy Pattern** - Request-scoped isolation with database scoping

The system is production-ready for hosting multiple independent real estate agency websites on a single application instance.
