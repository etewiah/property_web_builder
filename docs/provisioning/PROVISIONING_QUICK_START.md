# Website Provisioning Quick Start Guide

## Quick Reference Commands

### Create a New Website (Complete Setup)
```bash
# Create website with all data including sample properties
rake pwb:db:create_tenant[my-agency]

# Create website without sample properties (faster)
SKIP_PROPERTIES=true rake pwb:db:create_tenant[bare-site]

# Create with custom slug and name
rake pwb:db:create_tenant[luxury-homes,luxury-homes-es,Luxury Homes Spain]
```

Result:
- New `Pwb::Website` record created
- All seed data loaded (agency, links, field keys, users, contacts, properties)
- Admin user created: `admin@{subdomain}.com` / `password`
- Accessible at: `http://{subdomain}.lvh.me:3000` (development)

### Seed an Existing Website
```bash
# Seed a specific website
rake pwb:db:seed_tenant[subdomain]

# List all websites
rake pwb:db:list_tenants

# Seed all websites
rake pwb:db:seed_all_tenants
```

### Apply a Seed Pack
```ruby
# In Rails console
website = Pwb::Website.find_by(subdomain: 'my-site')
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```

### Preview Changes (Dry Run)
```bash
rake pwb:db:seed_dry_run
DRY_RUN=true rake pwb:db:seed_enhanced
```

---

## Step-by-Step: Create a Real Estate Website

### 1. Create the Website Record
```ruby
website = Pwb::Website.create!(
  subdomain: 'golden-homes',
  slug: 'golden-homes',
  company_display_name: 'Golden Homes Real Estate',
  theme_name: 'bristol',
  default_currency: 'EUR',
  default_client_locale: 'en-UK',
  supported_locales: ['en', 'de']
)
```

### 2. Option A: Use Basic Seeder
```ruby
Pwb::Seeder.seed!(website: website)
Pwb::PagesSeeder.seed_page_parts!
Pwb::PagesSeeder.seed_page_basics!(website: website)
```

### 3. Option B: Use a Seed Pack (Recommended)
```ruby
pack = Pwb::SeedPack.find('base')
pack.apply!(website: website)
```

### 4. Create Admin User
```ruby
user = Pwb::User.create!(
  email: 'admin@golden-homes.com',
  password: 'secure-password-123',
  password_confirmation: 'secure-password-123',
  website_id: website.id,
  admin: true
)

# Create membership for multi-website support
Pwb::UserMembership.create!(
  user: user,
  website: website,
  role: 'owner',
  active: true
)
```

### 5. Access the Website
- URL: `http://golden-homes.lvh.me:3000`
- Admin: `admin@golden-homes.com` / `secure-password-123`

---

## Configuring Website Properties

### Add Custom Branding
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Set company colors
website.update!(
  style_variables_for_theme: {
    "default" => {
      "primary_color" => "#ff6b35",      # Orange
      "secondary_color" => "#004e89",    # Dark blue
      "action_color" => "#f77f00",       # Accent orange
      "body_style" => "siteLayout.wide",
      "theme" => "light",
      "font_primary" => "Open Sans",
      "font_secondary" => "Merriweather",
      "border_radius" => "0.5rem",
      "container_padding" => "1rem"
    }
  }
)
```

### Configure Agency Information
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Create or update agency
agency = website.agency || website.build_agency
agency.update!(
  display_name: 'Golden Homes Realty',
  email_primary: 'info@goldenhomes.com',
  phone_number_primary: '+1 555 123 4567'
)

# Add address
address = Pwb::Address.create!(
  street_address: '123 Main Street',
  city: 'San Francisco',
  region: 'California',
  country: 'USA',
  postal_code: '94105'
)

agency.update!(primary_address: address)
```

### Setup Localization
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Support multiple languages
website.update!(
  supported_locales: ['en-US', 'es-ES', 'fr-FR'],
  default_client_locale: 'en-US',
  default_currency: 'USD',
  default_area_unit: :sqft  # or :sqmt
)
```

### Add Custom Domain
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Set custom domain
website.update!(custom_domain: 'golden-homes.com')

# Generate verification token for DNS setup
website.generate_domain_verification_token!
token = website.custom_domain_verification_token

# Verify domain (after DNS TXT record is set)
website.verify_custom_domain!
```

---

## User Management

### Create Users
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Create user
user = Pwb::User.create!(
  email: 'agent@golden-homes.com',
  password: 'secure-password',
  password_confirmation: 'secure-password',
  website_id: website.id
)

# Create membership with role
Pwb::UserMembership.create!(
  user: user,
  website: website,
  role: 'member',  # owner, admin, member, viewer
  active: true
)
```

### Update User Roles
```ruby
membership = Pwb::UserMembership.find_by(
  user_id: user.id,
  website_id: website.id
)

# Change role
membership.update!(role: 'admin')

# Or deactivate
membership.update!(active: false)
```

### Add User to Multiple Websites
```ruby
user = Pwb::User.find_by(email: 'agent@golden-homes.com')

# Add to second website
website2 = Pwb::Website.find_by(subdomain: 'silver-homes')
Pwb::UserMembership.create!(
  user: user,
  website: website2,
  role: 'member',
  active: true
)

# User can now access both websites
user.websites  # => [website1, website2]
```

### Check User Permissions
```ruby
user = Pwb::User.find_by(email: 'admin@golden-homes.com')
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Check role
user.role_for(website)  # => 'owner'

# Check if admin
user.admin_for?(website)  # => true

# Check access
user.can_access_website?(website)  # => true
```

---

## Property Management

### Add Sample Properties
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Create property asset
asset = Pwb::RealtyAsset.create!(
  website: website,
  reference: 'PROP-001',
  prop_type_key: 'types.villa',
  prop_state_key: 'states.good',
  street_address: '456 Oak Lane',
  city: 'Palo Alto',
  region: 'California',
  country: 'USA',
  postal_code: '94301',
  count_bedrooms: 4,
  count_bathrooms: 3,
  count_garages: 2,
  constructed_area: 3500,
  plot_area: 7000,
  year_construction: 2015,
  latitude: 37.4419,
  longitude: -122.1430
)

# Create sale listing (with translations)
sale = Pwb::SaleListing.create!(
  realty_asset: asset,
  visible: true,
  price_sale_current_cents: 2_500_000_00,  # $2.5M
  price_sale_current_currency: 'USD'
)

# Set multilingual content
sale.update!(
  title_en: 'Beautiful Modern Villa in Palo Alto',
  title_es: 'Villa Moderna Hermosa en Palo Alto',
  description_en: 'Stunning 4-bedroom villa with pool and views...',
  description_es: 'Hermosa villa de 4 dormitorios con piscina y vistas...'
)
```

### List Properties
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# All properties
properties = website.realty_assets

# For-sale properties
sales = website.sale_listings

# For-rent properties
rentals = website.rental_listings

# Listed properties (optimized view)
listed = website.listed_properties
```

---

## Content Management

### Add Navigation Links
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Create link
link = website.links.create!(
  slug: 'properties',
  link_url: '/search?type=properties',
  link_title: 'Properties',
  link_title_es: 'Propiedades',
  page_slug: 'properties',
  visible: true,
  position_in_footer: 1
)
```

### Create Pages
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Create page
page = website.pages.create!(
  slug: 'about-us',
  title: 'About Our Agency',
  visible: true
)

# Add page parts (sections)
page_part = Pwb::PagePart.create!(
  website: website,
  page_slug: 'about-us',
  page_part_key: 'content_html',
  block_contents: {
    content: '<h2>Our Story</h2><p>We have been helping families...'
  },
  show_in_editor: true
)
```

---

## Validation & Debugging

### Check Website Status
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Basic info
puts "Website: #{website.company_display_name}"
puts "Subdomain: #{website.subdomain}"
puts "Custom Domain: #{website.custom_domain}"
puts "Theme: #{website.theme_name}"
puts "Locales: #{website.supported_locales.join(', ')}"

# Associated data
puts "Properties: #{website.realty_assets.count}"
puts "Users: #{website.users.count}"
puts "Admin Users: #{website.admins.count}"
puts "Memberships: #{website.user_memberships.count}"
puts "Links: #{website.links.count}"
```

### Validate Seeds
```bash
rake pwb:db:validate_seeds
```

### Seed in Preview Mode
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

Pwb::SeedRunner.run(
  website: website,
  dry_run: true,        # Don't make changes
  verbose: true         # Show details
)
```

---

## Common Issues & Solutions

### Issue: "Subdomain is reserved"
**Cause:** Subdomain is in reserved list (www, api, admin, etc.)
**Solution:** Choose a different subdomain
```ruby
Pwb::Website::RESERVED_SUBDOMAINS  # List of reserved
```

### Issue: "Custom domain validation failed"
**Cause:** Domain format invalid or is a platform domain
**Solution:** Ensure domain is properly formatted and not `*.propertywebbuilder.com`

### Issue: User can't sign in
**Cause:** User not in website or membership inactive
**Solution:** Check memberships
```ruby
user.websites  # Should include the website
user.user_memberships.where(website: website)  # Should exist and be active
```

### Issue: Properties not appearing
**Cause:** Materialized view not refreshed
**Solution:** Refresh the view
```ruby
Pwb::ListedProperty.refresh
```

### Issue: Subdomain not routing to website
**Cause:** Platform domain not in environment or website not created
**Solution:** Check configuration
```ruby
# In Rails console
Pwb::Website.platform_domains  # Should include subdomain's domain
Pwb::Website.find_by_subdomain('my-site')  # Should return website
```

---

## Environment Setup

### Development Configuration
```bash
# In .env or config/database.yml
PLATFORM_DOMAINS=localhost,lvh.me

# Access websites at:
# http://localhost:3000
# http://site1.lvh.me:3000
# http://site2.lvh.me:3000
```

### Production Configuration
```bash
# In production environment
PLATFORM_DOMAINS=propertywebbuilder.com,yourcompany.com

# Configure DNS:
# *.propertywebbuilder.com -> Your app server
# Or point custom domains to app server
```

---

## Testing Website Setup

### Create Test Website
```ruby
# In Rails console
website = Pwb::Website.create!(
  subdomain: 'test-site',
  company_display_name: 'Test Site',
  theme_name: 'bristol'
)

Pwb::Seeder.seed!(website: website, skip_properties: true)

# Create test user
user = Pwb::User.create!(
  email: 'test@test.com',
  password: 'test123',
  password_confirmation: 'test123',
  website_id: website.id
)

puts "Website created at: http://test-site.lvh.me:3000"
puts "Login: test@test.com / test123"
```

### Verify Setup
```ruby
website = Pwb::Website.find_by(subdomain: 'test-site')

# Check data
puts "✓ Website" if website.present?
puts "✓ Agency" if website.agency.present?
puts "✓ Links" if website.links.count > 0
puts "✓ Field Keys" if website.field_keys.count > 0
puts "✓ Users" if website.users.count > 0

# Try to find by subdomain
found = Pwb::Website.find_by_subdomain('test-site')
puts "✓ Subdomain routing" if found.present?

# Try to find by host
found = Pwb::Website.find_by_host('test-site.lvh.me')
puts "✓ Host routing" if found.present?
```

---

## Seed Pack Reference

### Available Packs
```ruby
Pwb::SeedPack.available  # List all packs
```

#### Base Pack
- **Name:** base
- **Description:** Foundation pack with common navigation and field keys
- **Includes:** Basic website config, common links, field key definitions
- **Use for:** Parent pack inheritance, basic setup

#### Spain Luxury Pack
- **Name:** spain_luxury
- **Description:** Luxury real estate on Costa del Sol
- **Includes:** Spanish agency info, luxury properties, multilingual content
- **Locales:** Spanish, English, German
- **Currency:** EUR

#### Netherlands Urban Pack
- **Name:** netherlands_urban
- **Description:** Urban property rental market
- **Includes:** Dutch agency info, apartment rentals, city properties
- **Locales:** Dutch, English
- **Currency:** EUR

### Create Custom Pack
1. Create directory: `/db/seeds/packs/my-pack/`
2. Create `pack.yml` with configuration
3. Add subdirectories as needed:
   - `properties/` - Property YAML files
   - `images/` - Property images
   - `content/` - Content translations
   - `translations/` - i18n files
4. Use in code:
   ```ruby
   pack = Pwb::SeedPack.find('my-pack')
   pack.apply!(website: website)
   ```

---

## Performance Considerations

### Large Property Datasets
When seeding many properties:
```ruby
# Disable validations for speed
website.realty_assets.create_without_validating!(attrs)

# Bulk create listings
Pwb::SaleListing.insert_all(listings_data)

# Refresh materialized view once at end
Pwb::ListedProperty.refresh
```

### Translation Loading
- Translations loaded once (cached)
- Set in Seeder: `should_load_translations` logic
- Test environment: Always load
- Production: Only load if < 600 translations

### Database Indexes
Key indexes for performance:
- `website_id` - All tenant-scoped queries
- `subdomain` - Website routing
- `custom_domain` - Custom domain routing
- `user_id + website_id` - Membership lookups

---

## Backup & Recovery

### Backup Website Data
```ruby
website = Pwb::Website.find_by(subdomain: 'golden-homes')

backup = {
  website: website.attributes,
  agency: website.agency&.attributes,
  properties: website.realty_assets.map(&:attributes),
  users: website.user_memberships.map(&:attributes),
  links: website.links.map(&:attributes)
}

File.write('backup.json', backup.to_json)
```

### Export for Seed Pack
```ruby
# Create YAML seed files from live website
website = Pwb::Website.find_by(subdomain: 'golden-homes')

# Export properties
properties = website.realty_assets.map { |p| p.attributes.symbolize_keys }
File.write('properties.yml', properties.to_yaml)

# Export users (passwords needed from another source)
users = website.user_memberships.map { |m| m.attributes.symbolize_keys }
File.write('users.yml', users.to_yaml)
```

---

## Summary

Key files to understand:
- `/app/models/pwb/website.rb` - Website model
- `/app/models/pwb/user.rb` - User model
- `/app/models/pwb/user_membership.rb` - Multi-website relationship
- `/lib/pwb/seeder.rb` - Basic seeding
- `/lib/pwb/seed_pack.rb` - Scenario seeding
- `/lib/tasks/pwb_tasks.rake` - Rake tasks
- `/db/yml_seeds/` - Seed data templates
- `/db/seeds/packs/` - Seed pack scenarios

Most common tasks:
```bash
# Create new website
rake pwb:db:create_tenant[subdomain]

# List websites
rake pwb:db:list_tenants

# Seed website
rake pwb:db:seed_tenant[subdomain]

# Apply seed pack
Pwb::SeedPack.find('pack_name').apply!(website: website)
```
