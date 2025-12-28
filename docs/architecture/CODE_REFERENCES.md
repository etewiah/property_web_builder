# Code References - PropertyWebBuilder Provisioning

Quick reference to actual code locations with key snippets.

---

## Website Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/website.rb`  
**Lines:** 435 total

### Domain Routing
```ruby
# Find website by any means
def self.find_by_host(host)
  return nil if host.blank?
  host = host.to_s.downcase.strip
  
  unless platform_domain?(host)
    website = find_by_custom_domain(host)
    return website if website
  end
  
  subdomain = extract_subdomain_from_host(host)
  find_by_subdomain(subdomain) if subdomain.present?
end

# Extract subdomain from platform domain
def self.extract_subdomain_from_host(host)
  platform_domains.each do |pd|
    if host.end_with?(pd)
      subdomain_part = host.sub(/\.?#{Regexp.escape(pd)}\z/, '')
      return subdomain_part.split('.').first if subdomain_part.present?
    end
  end
  nil
end

# Get platform domains from ENV
def self.platform_domains
  ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost').split(',').map(&:strip)
end
```

### Subdomain Validation
```ruby
# Lines 38-51: Subdomain validations
validates :subdomain,
          uniqueness: { case_sensitive: false, allow_blank: true },
          format: {
            with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/i,
            message: "can only contain alphanumeric characters and hyphens...",
            allow_blank: true
          },
          length: { minimum: 2, maximum: 63, allow_blank: true }

# Lines 48-51: Reserved subdomains
RESERVED_SUBDOMAINS = %w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo].freeze

validate :subdomain_not_reserved
```

### Custom Domain Verification
```ruby
# Lines 364-395: Domain verification
def generate_domain_verification_token!
  update!(custom_domain_verification_token: SecureRandom.hex(16))
end

def verify_custom_domain!
  return false if custom_domain.blank? || custom_domain_verification_token.blank?
  
  begin
    require 'resolv'
    resolver = Resolv::DNS.new
    verification_host = "_pwb-verification.#{custom_domain.sub(/\Awww\./, '')}"
    txt_records = resolver.getresources(verification_host, Resolv::DNS::Resource::IN::TXT)
    verified = txt_records.any? { |record| record.strings.join == custom_domain_verification_token }
    
    if verified
      update!(
        custom_domain_verified: true,
        custom_domain_verified_at: Time.current
      )
    end
    verified
  rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
    Rails.logger.warn("Domain verification failed for #{custom_domain}: #{e.message}")
    false
  end
end
```

### Multi-Website Support
```ruby
# Lines 22-30: Multi-website relationships
has_many :user_memberships, dependent: :destroy
has_many :members, through: :user_memberships, source: :user

# Lines 34-36: Get admin users
def admins
  members.where(pwb_user_memberships: { role: ['owner', 'admin'], active: true })
end

# Lines 71-73: Feature flags
has_flags 1 => :landing_hide_for_rent,
  2 => :landing_hide_for_sale,
  3 => :landing_hide_search_bar
```

### Association Example
```ruby
# Lines 6-30: Key associations
has_many :page_contents, class_name: 'Pwb::PageContent'
has_many :contents, through: :page_contents, class_name: 'Pwb::Content'
has_many :listed_properties, class_name: 'Pwb::ListedProperty', foreign_key: 'website_id'
has_many :props, class_name: 'Pwb::Prop', foreign_key: 'website_id'
has_many :realty_assets, class_name: 'Pwb::RealtyAsset', foreign_key: 'website_id'
has_many :sale_listings, through: :realty_assets, class_name: 'Pwb::SaleListing'
has_many :rental_listings, through: :realty_assets, class_name: 'Pwb::RentalListing'
has_many :pages, class_name: 'Pwb::Page'
has_many :links, class_name: 'Pwb::Link'
has_many :users
has_many :contacts, class_name: 'Pwb::Contact'
has_many :messages, class_name: 'Pwb::Message'
has_many :website_photos
has_many :field_keys, class_name: 'Pwb::FieldKey', foreign_key: :pwb_website_id
```

---

## User Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user.rb`  
**Lines:** 186 total

### Devise Configuration
```ruby
# Lines 19-22: Devise modules
devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable,
  :validatable, :lockable, :timeoutable,
  :omniauthable, omniauth_providers: [:facebook]
```

### Multi-Website Associations
```ruby
# Lines 38-44: Website associations
belongs_to :website, optional: true
has_many :authorizations
has_many :auth_audit_logs, class_name: 'Pwb::AuthAuditLog', dependent: :destroy
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships
```

### Authentication Validation
```ruby
# Lines 68-85: Devise authentication hook
def active_for_authentication?
  return false unless super
  return true if current_website.blank?
  return true if website_id == current_website.id
  return true if user_memberships.active.exists?(website: current_website)
  return true if firebase_uid.present?
  false
end

# Lines 99-102: Website access check
def can_access_website?(website)
  return false unless website
  website_id == website.id || user_memberships.active.exists?(website: website)
end
```

### OAuth Handling
```ruby
# Lines 118-146: OAuth user creation/lookup
def self.find_for_oauth(auth, website: nil)
  authorization = Authorization.where(provider: auth.provider, uid: auth.uid.to_s).first
  return authorization.user if authorization
  
  email = auth.info[:email]
  unless email.present?
    email = "#{SecureRandom.urlsafe_base64}@example.com"
  end
  
  user = User.where(email: email).first
  if user
    user.create_authorization(auth)
  else
    password = ::Devise.friendly_token[0, 20]
    current_website = website || Pwb::Current.website || Pwb::Website.first
    user = User.create!(
      email: email, 
      password: password, 
      password_confirmation: password,
      website: current_website
    )
    user.create_authorization(auth)
  end
  user
end
```

---

## UserMembership Model

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/user_membership.rb`  
**Lines:** 57 total

### Complete Model
```ruby
module Pwb
  class UserMembership < ApplicationRecord
    # Available roles in hierarchical order
    ROLES = %w[owner admin member viewer].freeze
    
    # Associations
    belongs_to :user, class_name: 'Pwb::User'
    belongs_to :website, class_name: 'Pwb::Website'
    
    # Validations
    validates :role, presence: true, inclusion: { in: ROLES }
    validates :user_id, uniqueness: { scope: :website_id, message: "already has a membership for this website" }
    validates :active, inclusion: { in: [true, false] }
    
    # Scopes
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :admins, -> { where(role: ['owner', 'admin']) }
    scope :owners, -> { where(role: 'owner') }
    scope :for_website, ->(website) { where(website: website) }
    scope :for_user, ->(user) { where(user: user) }
    
    # Role hierarchy
    def self.role_hierarchy
      ROLES.each_with_index.to_h
    end
    
    def admin?
      role.in?(['owner', 'admin'])
    end
    
    def owner?
      role == 'owner'
    end
    
    def role_level
      self.class.role_hierarchy[role] || -1
    end
    
    def can_manage?(other_membership)
      return false unless active?
      role_level > other_membership.role_level
    end
  end
end
```

---

## Current Model (Request Context)

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/app/models/pwb/current.rb`  
**Lines:** 5 total

```ruby
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end
```

---

## Seeder Class

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seeder.rb`  
**Lines:** 476 total

### Main Entry Point
```ruby
# Lines 38-91: Main seed method
def self.seed!(website: nil, skip_properties: false)
  @current_website = website || Pwb::Website.first || Pwb::Website.create!(theme_name: 'bristol')
  @skip_properties = skip_properties
  
  I18n.locale = :en
  
  # Load translations if needed
  should_load_translations = ENV["RAILS_ENV"] == "test" || I18n::Backend::ActiveRecord::Translation.all.length <= 600
  if should_load_translations
    load File.join(Rails.root, "db", "seeds", "translations_ca.rb")
    load File.join(Rails.root, "db", "seeds", "translations_en.rb")
    # ... other translations
  end
  
  seed_agency "agency.yml"
  seed_website "website.yml"
  seed_properties unless @skip_properties
  seed_field_keys "field_keys.yml"
  seed_users "users.yml"
  seed_contacts "contacts.yml"
  seed_links "links.yml"
end
```

### Property Seeding
```ruby
# Lines 100-116: Seed properties
def seed_properties
  unless @current_website.realty_assets.count > 3
    puts "   🏠 Seeding sample properties..."
    seed_prop "villa_for_sale.yml"
    seed_prop "villa_for_rent.yml"
    seed_prop "flat_for_sale.yml"
    seed_prop "flat_for_rent.yml"
    seed_prop "flat_for_sale_2.yml"
    seed_prop "flat_for_rent_2.yml"
  end

  puts "   🔄 Refreshing properties materialized view..."
  Pwb::ListedProperty.refresh
end

# Lines 245-328: Create normalized property records
def create_normalized_property_records(prop_data, photos = [])
  asset_attrs = {
    website: current_website,
    reference: prop_data["reference"],
    year_construction: prop_data["year_construction"],
    # ... other attributes
  }.compact

  return if Pwb::RealtyAsset.exists?(website: current_website, reference: prop_data["reference"])

  asset = Pwb::RealtyAsset.create!(asset_attrs)

  # Create sale listing
  if prop_data["for_sale"]
    sale_listing = Pwb::SaleListing.create!(
      realty_asset: asset,
      visible: prop_data["visible"] || false,
      price_sale_current_cents: prop_data["price_sale_current_cents"] || 0,
      price_sale_current_currency: prop_data["currency"] || "EUR"
    )
    set_listing_translations(sale_listing, prop_data)
  end

  # Create rental listing
  if prop_data["for_rent_long_term"] || prop_data["for_rent_short_term"]
    rental_listing = Pwb::RentalListing.create!(
      realty_asset: asset,
      for_rent_long_term: prop_data["for_rent_long_term"] || false,
      price_rental_monthly_current_cents: prop_data["price_rental_monthly_current_cents"] || 0
    )
    set_listing_translations(rental_listing, prop_data)
  end

  asset
end
```

---

## SeedPack Class

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/lib/pwb/seed_pack.rb`  
**Lines:** 693 total

### Core Methods
```ruby
# Lines 57-92: Apply pack to website
def apply!(website:, options: {})
  @website = website
  @options = default_options.merge(options)
  @verbose = @options.fetch(:verbose, true)

  validate!

  log "Applying seed pack '#{name}' to website '#{website.subdomain}'...", :info

  if @options[:dry_run]
    log "DRY RUN MODE - No changes will be made", :warning
    return preview
  end

  # Apply inherited pack first
  apply_parent_pack! if config[:inherits_from]

  # Apply this pack's data in order
  seed_website unless @options[:skip_website]
  seed_agency unless @options[:skip_agency]
  seed_field_keys unless @options[:skip_field_keys]
  seed_links unless @options[:skip_links]
  seed_pages unless @options[:skip_pages]
  seed_page_parts unless @options[:skip_page_parts]
  seed_properties unless @options[:skip_properties]
  seed_content unless @options[:skip_content]
  seed_users unless @options[:skip_users]
  seed_translations unless @options[:skip_translations]

  Pwb::ListedProperty.refresh rescue nil

  log "Seed pack '#{name}' applied successfully!", :success
  true
end

# Lines 108-127: List available packs
def self.available
  return [] unless PACKS_PATH.exist?

  PACKS_PATH.children.select(&:directory?).filter_map do |dir|
    pack_file = dir.join('pack.yml')
    next unless pack_file.exist?

    begin
      new(dir.basename.to_s)
    rescue StandardError
      nil
    end
  end
end
```

### Property Seeding from Pack
```ruby
# Lines 573-648: Create property from pack data
def create_property(data)
  asset = Pwb::RealtyAsset.create!(
    website_id: @website.id,
    reference: data[:reference],
    prop_type_key: data[:prop_type],
    street_address: data[:address],
    city: data[:city],
    # ... other attributes
  )

  # Create sale listing if configured
  if data[:sale]
    listing = Pwb::SaleListing.create!(
      realty_asset: asset,
      visible: true,
      active: true,
      highlighted: data[:sale][:highlighted] || false,
      price_sale_current_cents: data[:sale][:price_cents],
      price_sale_current_currency: config.dig(:website, :currency) || 'EUR'
    )
    # Set translations
    (config.dig(:website, :supported_locales) || ['en']).each do |locale|
      title = data[:sale].dig(:title, locale.to_sym) || data[:sale][:title]
      desc = data[:sale].dig(:description, locale.to_sym) || data[:sale][:description]
      listing.send("title_#{locale}=", title) if title && listing.respond_to?("title_#{locale}=")
      listing.send("description_#{locale}=", desc) if desc && listing.respond_to?("description_#{locale}=")
    end
    listing.save!
  end

  asset
end
```

---

## Rake Tasks

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/lib/tasks/pwb_tasks.rake`  
**Lines:** 389 total

### Create Tenant Task
```ruby
# Lines 135-183: Create new website
desc 'Creates a new tenant website with optional seeding...'
task :create_tenant, [:subdomain, :slug, :name] => [:environment] do |t, args|
  subdomain = args[:subdomain]
  slug = args[:slug] || subdomain
  name = args[:name] || subdomain&.titleize
  skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
  
  if subdomain.blank?
    puts "❌ Error: Please provide a subdomain"
    exit 1
  end
  
  if Pwb::Website.exists?(subdomain: subdomain)
    puts "❌ Error: A website with subdomain '#{subdomain}' already exists"
    exit 1
  end
  
  puts "🏗️  Creating new tenant website..."
  website = Pwb::Website.create!(
    subdomain: subdomain,
    slug: slug,
    company_display_name: name,
    theme_name: 'bristol'
  )
  
  puts "✅ Website created with ID: #{website.id}"
  
  Pwb::Current.website = website
  
  Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
  Pwb::PagesSeeder.seed_page_parts!
  Pwb::PagesSeeder.seed_page_basics!(website: website)
  Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
  
  puts "✅ Tenant '#{subdomain}' created and seeded successfully!"
end
```

### List Tenants Task
```ruby
# Lines 185-199: List all websites
desc 'Lists all tenant websites.'
task list_tenants: [:environment] do
  websites = Pwb::Website.all
  
  if websites.empty?
    puts "No websites found."
  else
    puts "Found #{websites.count} website(s):\n\n"
    puts "  #{'ID'.ljust(6)} #{'Subdomain'.ljust(20)} #{'Slug'.ljust(20)} #{'Name'.ljust(30)}"
    puts "  #{'-' * 76}"
    websites.each do |w|
      puts "  #{w.id.to_s.ljust(6)} #{(w.subdomain || '-').ljust(20)} #{(w.slug || '-').ljust(20)} #{(w.company_display_name || '-').ljust(30)}"
    end
  end
end
```

---

## Migration: UserMemberships

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251201140925_create_pwb_user_memberships.rb`

```ruby
class CreatePwbUserMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_user_memberships do |t|
      t.references :user, null: false, foreign_key: { to_table: :pwb_users }
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :role, null: false, default: 'member'
      t.boolean :active, default: true, null: false

      t.timestamps
      
      # Ensure user can only have one membership per website
      t.index [:user_id, :website_id], unique: true, name: 'index_user_memberships_on_user_and_website'
    end
  end
end
```

---

## Migration: Custom Domain

**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/migrate/20251208111819_add_custom_domain_to_websites.rb`

```ruby
class AddCustomDomainToWebsites < ActiveRecord::Migration[8.0]
  def change
    add_column :pwb_websites, :custom_domain, :string
    add_column :pwb_websites, :custom_domain_verified, :boolean, default: false
    add_column :pwb_websites, :custom_domain_verified_at, :datetime
    add_column :pwb_websites, :custom_domain_verification_token, :string

    # Unique index on custom_domain, but only for non-null values
    add_index :pwb_websites, :custom_domain, unique: true, where: "custom_domain IS NOT NULL AND custom_domain != ''"
  end
end
```

---

## Seed Pack Configuration Examples

### Base Pack
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/base/pack.yml`

```yaml
name: base
display_name: "Base Pack"
description: "Foundation pack with common field keys, pages, and navigation structure"
version: "1.0"

inherits_from: null

website:
  theme_name: bristol
  default_client_locale: en
  supported_locales:
    - en
  currency: EUR
  area_unit: sqmt
```

### Spain Luxury Pack
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/seeds/packs/spain_luxury/pack.yml`

```yaml
name: spain_luxury
display_name: "Spanish Luxury Real Estate"
description: "Estate agent specializing in luxury properties on the Costa del Sol"
version: "1.0"

inherits_from: base

website:
  theme_name: bristol
  default_client_locale: es
  supported_locales:
    - es
    - en
    - de
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
    - key: stats/stats_counter
      order: 3
    - key: testimonials/testimonial_carousel
      order: 4
    - key: cta/cta_banner
      order: 5

users:
  - email: admin@costaluxury.es
    role: admin
    password: demo123
  - email: agent@costaluxury.es
    role: agent
    password: demo123
```

---

## Seed YAML Examples

### Website Configuration
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/website.yml`

```yaml
analytics_id:
analytics_id_type:
company_display_name: Example Real Estate
email_for_general_contact_form:
email_for_property_contact_form:
flags: 0
configuration: {}
style_variables_for_theme: {      
  default: {
    primary_color: "#008000",
    secondary_color: "#8ec449", 
    action_color: "#563d7c",
    body_style: "siteLayout.wide"
  }
}
theme_name: 
supported_locales: ["en-US","es-MX"]
default_client_locale: "en-US"
default_currency: "USD"
default_area_unit: 0
```

### Field Keys
**File:** `/Users/etewiah/dev/sites-older/property_web_builder/db/yml_seeds/field_keys.yml`

```yaml
- global_key: 'types.villa'
  tag: 'property-types'
  visible: true
- global_key: 'types.apartment'
  tag: 'property-types'
  visible: true
- global_key: 'states.good'
  tag: 'property-states'
  visible: true
- global_key: 'features.pool'
  tag: 'property-features'
  visible: true
- global_key: 'features.garden'
  tag: 'property-features'
  visible: true
```

---

## Database Schema (Migrations)

### Website Table
```sql
CREATE TABLE pwb_websites (
  id BIGSERIAL PRIMARY KEY,
  subdomain VARCHAR UNIQUE,
  slug VARCHAR,
  custom_domain VARCHAR UNIQUE,
  custom_domain_verified BOOLEAN DEFAULT false,
  custom_domain_verified_at TIMESTAMP,
  custom_domain_verification_token VARCHAR,
  company_display_name VARCHAR,
  theme_name VARCHAR,
  default_currency VARCHAR DEFAULT 'EUR',
  default_client_locale VARCHAR DEFAULT 'en-UK',
  supported_locales TEXT[],
  default_area_unit INTEGER DEFAULT 0,
  style_variables_for_theme JSONB,
  configuration JSONB,
  flags INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

### UserMembership Table
```sql
CREATE TABLE pwb_user_memberships (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES pwb_users(id),
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  role VARCHAR DEFAULT 'member',
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  UNIQUE(user_id, website_id)
);
```

---

## Key File Locations Summary

| Purpose | File Path |
|---------|-----------|
| Website model | `/app/models/pwb/website.rb` |
| User model | `/app/models/pwb/user.rb` |
| Membership model | `/app/models/pwb/user_membership.rb` |
| Request context | `/app/models/pwb/current.rb` |
| Basic seeder | `/lib/pwb/seeder.rb` |
| Seed packs | `/lib/pwb/seed_pack.rb` |
| Enhanced seeding | `/lib/pwb/seed_runner.rb` |
| Rake tasks | `/lib/tasks/pwb_tasks.rake` |
| Seed data | `/db/yml_seeds/` |
| Pack scenarios | `/db/seeds/packs/` |
| Migrations | `/db/migrate/` |
| Documentation | `/docs/` |

---

## Environment Variables

```bash
# Platform domains for multi-tenancy
PLATFORM_DOMAINS=propertywebbuilder.com,pwb.localhost,localhost

# Rails environment
RAILS_ENV=production

# Database connection
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Mail configuration
MAIL_FROM_ADDRESS=noreply@example.com
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=SG.xxxxx

# Firebase (if using Firebase auth)
FIREBASE_PROJECT_ID=your-project
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----...
FIREBASE_CLIENT_EMAIL=firebase-adminsdk@yourproject.iam.gserviceaccount.com
```

---

## Testing Quick Commands

```ruby
# Create website
website = Pwb::Website.create!(
  subdomain: 'test',
  company_display_name: 'Test Company',
  theme_name: 'bristol'
)

# Seed website
Pwb::Seeder.seed!(website: website)

# Create user
user = Pwb::User.create!(
  email: 'test@test.com',
  password: 'password',
  website_id: website.id
)

# Create membership
Pwb::UserMembership.create!(
  user: user,
  website: website,
  role: 'owner',
  active: true
)

# Verify routing
Pwb::Website.find_by_host('test.lvh.me')  # => website
Pwb::Website.find_by_subdomain('test')     # => website

# Check user access
user.can_access_website?(website)  # => true
user.admin_for?(website)           # => true
```

---

**End of Code References**
