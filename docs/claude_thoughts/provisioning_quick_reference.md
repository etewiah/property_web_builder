# PropertyWebBuilder Provisioning Quick Reference

## Creating a New Website/Tenant

### Option 1: Admin UI
```
1. Navigate to: Tenant Admin → Websites → New
2. Fill form:
   - subdomain: lowercase, alphanumeric + hyphens, 2-63 chars
   - company_display_name: Display name for agency
   - theme_name: Select from available themes (e.g., 'bristol')
   - supported_locales: Multi-select locales
   - default_currency: Currency for property prices
   - default_area_unit: sqm or sqft
   - default_client_locale: Default locale for frontend
   - Checkbox: "Seed with data" (optional)
   - Checkbox: "Skip properties" (optional, for production)
3. Submit
4. Website created, optionally seeded with sample data
```

### Option 2: Rails Console
```ruby
website = Pwb::Website.create!(
  subdomain: 'costa-luxury',
  company_display_name: 'Costa Luxury Properties',
  theme_name: 'bristol',
  default_currency: 'EUR',
  supported_locales: ['es', 'en', 'de'],
  default_client_locale: 'es'
)

# Then seed if needed
Pwb::Seeder.seed!(website: website, skip_properties: false)
```

### Option 3: Apply Seed Pack
```bash
# List available packs
rails pwb:seed_packs:list

# Apply a pack to a website (assumes website already exists)
rails pwb:seed_packs:apply[spain_luxury,website_id]

# Or apply to first website (if only one)
rails pwb:seed_packs:apply[spain_luxury]

# Preview what will be created (dry run)
rails pwb:seed_packs:preview[spain_luxury]
```

## Key Models

### Website (Tenant)
```ruby
# Location: app/models/pwb/website.rb
Pwb::Website
  .subdomain          # Unique, for routing subdomain.domain.com
  .custom_domain      # Optional, for routing via custom domain
  .company_display_name
  .theme_name
  .default_currency
  .supported_locales  # Array of locale strings
  .default_client_locale
```

### User
```ruby
# Location: app/models/pwb/user.rb
Pwb::User
  .email
  .website_id         # Legacy field (primary website)
  .user_memberships   # Multi-website access
  
# Current context in requests:
Pwb::Current.website  # Set by routing concern
```

### UserMembership (NEW - Dec 2024)
```ruby
# Location: app/models/pwb/user_membership.rb
Pwb::UserMembership
  .user_id
  .website_id
  .role              # 'owner', 'admin', 'member', 'viewer'
  .active            # true/false

# Create/find membership:
Pwb::UserMembership.find_or_create_by!(
  user: user,
  website: website
) do |m|
  m.role = 'admin'
  m.active = true
end
```

### Agency
```ruby
# Location: app/models/pwb/agency.rb
Pwb::Agency
  .website
  .display_name
  .email_primary
  .phone_number_primary
  .primary_address    # Pwb::Address
```

### Property Models
```ruby
Pwb::RealtyAsset         # Physical property data (create this)
Pwb::SaleListing         # Sale listing + price/translations
Pwb::RentalListing       # Rental listing + price/translations
Pwb::ListedProperty      # Read-only materialized view (DO NOT create)
```

## Routing & Domain Resolution

### Subdomain-Based (Primary)
```
Request: costa-luxury.propertywebbuilder.com
→ Extract subdomain: "costa-luxury"
→ Website.find_by_subdomain('costa-luxury')
→ Load website with that subdomain
```

### Custom Domain (Secondary)
```
Request: costaluxury.es
→ Website.find_by_custom_domain('costaluxury.es')
→ Load website with that custom domain (if verified)
```

### Platform Domains Config
```ruby
# In environment or .env:
PLATFORM_DOMAINS=propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost

# Reserved subdomains (cannot be used):
www, api, admin, app, mail, ftp, smtp, pop, imap, 
ns1, ns2, localhost, staging, test, demo
```

## Seed Packs

### Available Packs
1. **base** - Foundation (field keys, navigation, pages)
2. **spain_luxury** - Spanish luxury estate agent (7 properties)
3. **netherlands_urban** - Dutch urban real estate (8 properties)

### Pack Structure
```
db/seeds/packs/pack_name/
├── pack.yml           # Metadata & configuration
├── field_keys.yml     # Property taxonomy
├── links.yml          # Navigation items
├── properties/        # Property YAML files
├── content/           # Page content
├── translations/      # Locale-specific translations
└── images/            # Property photos
```

### Create New Pack
1. Create directory: `db/seeds/packs/your_pack_name/`
2. Create `pack.yml` with metadata
3. Create subdirectories for field_keys, links, properties, etc.
4. Add YAML files for each section
5. Use `rails pwb:seed_packs:list` to verify

## Multi-Tenancy Scoping

### Scoped Models
Models with `website_id` foreign key and scoping:
- Pwb::Page (index on website_id, slug)
- Pwb::Content (index on website_id, key)
- Pwb::Link (index on website_id, slug)
- Pwb::RealtyAsset (properties)
- Pwb::FieldKey (property taxonomy)
- Pwb::UserMembership (user access per website)

### Unique Scoping
These can have duplicate values across websites, but must be unique within a website:
```ruby
# Multiple websites can have these:
Pwb::Page.where(website_id: 1, slug: 'home')
Pwb::Page.where(website_id: 2, slug: 'home')  # ✓ Different website

Pwb::Content.where(website_id: 1, key: 'footer')
Pwb::Content.where(website_id: 2, key: 'footer')  # ✓ Different website
```

### Enforcing Tenant Context
```ruby
# In controllers/services, always scope to current website:
Pwb::Current.website = website  # Set by routing concern

# When querying:
Pwb::Current.website.pages      # ✓ Scoped correctly
Pwb::Page.all                   # ⚠ Returns ALL pages - risky
```

## User Permissions

### Role Hierarchy
```ruby
owner (4)
├─ Can manage other admins
├─ Full admin access
│
admin (3)
├─ Admin access
├─ Cannot manage other admins
│
member (2)
├─ Standard user access
│
viewer (1)
└─ Read-only access
```

### Checking Access
```ruby
# Check if user is admin for a website:
user.admin_for?(website)

# Get user's role for a website:
user.role_for(website)

# Get user's accessible websites:
user.accessible_websites

# Check specific membership:
membership = Pwb::UserMembership.find_by(user: user, website: website)
membership.admin?      # true if owner or admin
membership.owner?      # true if owner
membership.active?     # true if active
```

## Custom Domain Setup

### Steps
1. **Add domain to website:**
   ```ruby
   website.update(custom_domain: 'costaluxury.es')
   ```

2. **Generate verification token:**
   ```ruby
   website.generate_domain_verification_token!
   # Returns something like: 'abc123def456...'
   ```

3. **Instruct user to add DNS TXT record:**
   ```
   Name: _pwb-verification.costaluxury.es
   Type: TXT
   Value: [verification_token from step 2]
   ```

4. **Verify domain:**
   ```ruby
   website.verify_custom_domain!  # Returns true if verified
   website.custom_domain_verified?
   ```

5. **Check if domain is active:**
   ```ruby
   website.custom_domain_active?  # true if verified or dev/test
   ```

### Get Primary URL
```ruby
website.primary_url
# Returns: https://costaluxury.es (if custom domain verified)
# Or: https://costa-luxury.propertywebbuilder.com (if subdomain)
```

## Common Tasks

### Create Website + Seed Data
```ruby
website = Pwb::Website.create!(
  subdomain: 'mysite',
  company_display_name: 'My Agency',
  theme_name: 'bristol',
  default_currency: 'USD',
  supported_locales: ['en']
)

# Option A: Use legacy seeder
Pwb::Seeder.seed!(website: website)

# Option B: Use seed pack
pack = Pwb::SeedPack.find('spain_luxury')
pack.apply!(website: website)
```

### Add User to Website
```ruby
user = Pwb::User.create!(
  email: 'agent@mysite.com',
  password: 'secure_password',
  password_confirmation: 'secure_password',
  website: website
)

# Also create membership:
Pwb::UserMembership.create!(
  user: user,
  website: website,
  role: 'admin',
  active: true
)
```

### Invite User to Additional Website
```ruby
existing_user = Pwb::User.find_by(email: 'existing@example.com')
second_website = Pwb::Website.find(2)

Pwb::UserMembership.create!(
  user: existing_user,
  website: second_website,
  role: 'member',
  active: true
)

# User can now access both websites
existing_user.accessible_websites  # [website1, website2]
```

### List All Websites
```ruby
# All websites:
Pwb::Website.all

# By subdomain:
Pwb::Website.find_by_subdomain('mysite')

# By custom domain:
Pwb::Website.find_by_custom_domain('mysite.com')

# By host (primary lookup method):
Pwb::Website.find_by_host('mysite.propertywebbuilder.com')
```

### Get Website Properties
```ruby
website = Pwb::Website.find(1)

# All properties:
website.realty_assets

# Materialized view (optimized):
website.listed_properties

# By listing type:
website.sale_listings
website.rental_listings
```

## Important Notes

### Materialized View Warning
```ruby
# DO NOT do this:
Pwb::ListedProperty.create!(...)  # ❌ Raises ReadOnlyRecord

# DO this instead:
asset = Pwb::RealtyAsset.create!(website: website, ...)
Pwb::SaleListing.create!(realty_asset: asset, ...)

# Then refresh view:
Pwb::ListedProperty.refresh
```

### Tenant Context
```ruby
# Always set context for operations:
Pwb::Current.website = website

# This is typically done by routing concern:
# app/controllers/concerns/website_concern.rb

# For console work, set manually:
Pwb::Current.website = Pwb::Website.first
```

### MultipleWebsite Users (New Feature)
```ruby
# The system is transitioning from single-website to multi-website users
# UserMembership model added Dec 1, 2024

# Users can now:
user.accessible_websites     # Get all websites they can access
user.can_access_website?(w)  # Check access
user.websites                # Through memberships

# Legacy field still exists (being phased out):
user.website_id              # Original single-website field
```

## Testing/Development

### Local Development Domains
```
# For subdomain testing, use lvh.me (localhost VHost)
# Supports subdomains and resolves to 127.0.0.1

http://localhost:3000         → Platform default
http://site1.lvh.me:3000      → Website with subdomain 'site1'
http://site2.lvh.me:3000      → Website with subdomain 'site2'
```

### Seed Data for Testing
```bash
# E2E testing data (multi-tenant setup)
# Located in: db/seeds/e2e_seeds.rb
```

## Troubleshooting

### "Website not found" Error
- Check subdomain spelling and case (case-insensitive matching)
- Verify website exists: `Pwb::Website.find_by_subdomain('mysite')`
- Check PLATFORM_DOMAINS configuration
- For custom domain: ensure DNS is set up and verified

### User Can't Access Website
- Check UserMembership exists: `Pwb::UserMembership.find_by(user: user, website: website)`
- Check membership is active: `membership.active?`
- Check Devise authentication: `user.active_for_authentication?`

### Properties Not Showing
- Verify RealtyAsset exists: `website.realty_assets.count`
- Check Listing exists: `asset.sale_listings.count`
- Refresh materialized view: `Pwb::ListedProperty.refresh`
- Check property is published/visible in admin

### Seed Pack Apply Fails
- Verify pack exists: `Pwb::SeedPack.available`
- Check pack.yml syntax: `rails pwb:seed_packs:preview[pack_name]`
- Review error message for missing files or permissions
- Try dry run first: `pack.apply!(website: website, options: { dry_run: true })`

---

## Further Reading

- Full provisioning analysis: `/docs/claude_thoughts/tenant_provisioning_analysis.md`
- Multi-tenancy guide: `/docs/06_Multi_Tenancy.md`
- Seed packs plan: `/docs/seeding/seed_packs_plan.md`
- Seeding architecture: `/docs/seeding/SEEDING_ARCHITECTURE.md`
