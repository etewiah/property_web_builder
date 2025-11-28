# PropertyWebBuilder Multi-Tenancy Guide

## Overview

PropertyWebBuilder supports multi-tenancy architecture, allowing multiple independent real estate websites to run on a single installation. Each website (tenant) is isolated by subdomain and has its own:

- Properties (listings)
- Pages and content
- Agency information
- Theme and styling
- Configuration settings

## Architecture

### Tenant Isolation

Tenants are isolated via:
1. **Subdomain routing** - Each website accessed via `subdomain.example.com`
2. **Website ID scoping** - Data associated with `website_id` foreign key
3. **Current.website context** - Thread-safe current website tracking

### Core Models

- **`Pwb::Website`** - Represents a tenant (one per subdomain)
- **`Pwb::Agency`** - Belongs to a website (one per tenant)
- **`Pwb::Prop`** - Properties scoped to website
- **`Pwb::Page`** - Pages scoped to website
- **`Pwb::Content`** - Content scoped to website

### Subdomain Tenant Concern

The `SubdomainTenant` concern (included in controllers) automatically:
1. Extracts subdomain from request
2. Finds matching `Pwb::Website.find_by_subdomain(subdomain)`
3. Sets `Pwb::Current.website` for request lifecycle
4. Falls back to first website if no subdomain present

## Managing Websites

### Tenant Admin Dashboard

Access the tenant admin at `/tenant_admin` to manage all websites across your installation.

Features:
- Create/edit/delete websites
- View all tenants in one dashboard
- Configure per-tenant settings
- Manage cross-tenant resources

### Creating a New Website

1. Navigate to `/tenant_admin/websites/new`
2. Fill in required fields:
   - **Subdomain** (required) - Alphanumeric and hyphens, 2-63 chars
   - **Company Display Name**
   - **Theme** - Default or Berlin
   - **Default Currency** - e.g., EUR, USD
   - **Default Locale** - e.g., en-UK
3. Click "Save Website"

### Accessing Websites

Each website is accessed via subdomain:
```
http://mycompany.example.com       # Website with subdomain "mycompany"
http://anotheragency.example.com   # Website with subdomain "anotheragency"
```

## Seeding Multi-Tenant Data

### Seed Specific Website

```ruby
# In rails console or seed file
website = Pwb::Website.find_by(subdomain: 'mycompany')
Pwb::Seeder.seed!(website: website, skip_properties: false)
```

### Seed Default Website

```ruby
# Seeds first website in database
Pwb::Seeder.seed!
```

### Create Website Programmatically

```ruby
website = Pwb::Website.create!(
  subdomain: 'newagency',
  company_display_name: 'New Real Estate Agency',
  theme_name: 'berlin',
  default_currency: 'EUR',
  default_client_locale: 'en-UK',
  supported_locales: ['en-UK', 'es-ES']
)

# Seed default data for this website
Pwb::Seeder.seed!(website: website)
```

## Data Associations

### Website Has:
- `has_many :props` - Properties
- `has_many :pages` - CMS pages
- `has_many :contents` - Content fragments
- `has_one :agency` - Agency info

### Scoping Queries

When querying from within a controller:
```ruby
# Automatically scoped to current website
@props = Pwb::Prop.all  # If Pwb::Prop includes Tenantable concern

# Manual scoping
@props = Pwb::Prop.where(website_id: current_website.id)

# Cross-tenant (tenant admin only)
@all_props = Pwb::Prop.unscoped.all
```

## Development & Testing

### Factory Usage

```ruby
# Creates website with unique subdomain
website = FactoryBot.create(:pwb_website, subdomain: 'test-agency')

# Creates agency for website
agency = FactoryBot.create(:pwb_agency, website: website)

# Creates property for website
prop = FactoryBot.create(:pwb_prop, website: website)
```

### Specs

Multi-tenancy specs verify:
- Multiple websites can be created
- IDs are not forced to 1
- Database sequences work correctly
- Subdomain routing isolates data

Run multi-tenancy specs:
```bash
bundle exec rspec spec/models/pwb/website_multi_tenancy_spec.rb
bundle exec rspec spec/models/pwb/agency_multi_tenancy_spec.rb
bundle exec rspec spec/requests/multi_tenant_website_creation_spec.rb
```

## Migration from Single-Tenant

### Historical Context

Prior to multi-tenancy support, PropertyWebBuilder used singleton patterns:
- `Website.unique_instance` - Forced ID=1
- `Agency.unique_instance` - Forced ID=1

These have been **removed** to support multiple tenants.

### Backward Compatibility

Existing single-tenant installations continue to work:
- If only one website exists with ID=1, it's used as default
- `Pwb::Current.website || Website.first` pattern provides fallback
- No database migration required

### Upgrading to Multi-Tenant

1. Existing installation continues working as-is
2. To add additional tenants:
   - Access `/tenant_admin`
   - Create new websites
   - Seed data for each website
   - Configure DNS/subdomains

## Best Practices

### Always Use Current Website

```ruby
# Good - uses current tenant context
@website = current_website
@props = Pwb::Prop.where(website_id: @website.id)

# Avoid - bypasses tenant scoping
@props = Pwb::Prop.all.unscoped
```

### Testing Multi-Tenancy

```ruby
RSpec.describe "Feature", type: :feature do
  let(:website1) { create(:pwb_website, subdomain: 'tenant1') }
  let(:website2) { create(:pwb_website, subdomain: 'tenant2') }

  it "isolates data between tenants" do
    prop1 = create(:pwb_prop, website: website1)
    prop2 = create(:pwb_prop, website: website2)
    
    # Verify isolation
    expect(website1.props).to include(prop1)
    expect(website1.props).not_to include(prop2)
  end
end
```

### Database Sequence Management

If you encounter sequence issues after manual data manipulation:
```ruby
# Reset all sequences to match current max IDs
ActiveRecord::Base.connection.reset_pk_sequence!('pwb_websites')
ActiveRecord::Base.connection.reset_pk_sequence!('pwb_agencies')
```

## Troubleshooting

### "Undefined method unique_instance"

**Cause:** Code is still trying to call removed singleton methods.

**Fix:** Update to use:
```ruby
# Instead of:
Website.unique_instance

# Use:
Pwb::Current.website || Pwb::Website.first
```

### "No website found"

**Cause:** No subdomain provided and no default website exists.

**Fix:** Create at least one website in database:
```ruby
Pwb::Website.create!(
  subdomain: 'default',
  theme_name: 'default',
  default_currency: 'EUR',
  default_client_locale: 'en-UK'
)
```

### Cross-Contamination Between Tenants

**Cause:** Query not scoped to `website_id`.

**Fix:** Always filter by website:
```ruby
Pwb::Prop.where(website_id: current_website.id)
```

## API Endpoints

API endpoints respect tenant context via:
1. Subdomain in request
2. GraphQL `websiteId` argument
3. Current.website fallback

Example GraphQL query:
```graphql
query {
  properties(websiteId: 1) {
    nodes {
      reference
      city
    }
  }
}
```

## Deployment Considerations

### DNS Configuration

Set up wildcard DNS or individual subdomains:
```
*.example.com  →  Your server IP
```

Or individual:
```
tenant1.example.com  →  Your server IP
tenant2.example.com  →  Your server IP
```

### Web Server Configuration

Configure your web server (Nginx/Apache) to accept wildcard subdomains and route to Rails app.

Example Nginx:
```nginx
server {
  server_name *.example.com example.com;
  # ... rest of config
}
```

### Environment Variables

No special environment variables needed for multi-tenancy. Standard Rails configuration applies.

## Further Reading

- [Tenant Admin Dashboard](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/tenant_admin)
- [SubdomainTenant Concern](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/controllers/concerns/subdomain_tenant.rb)
- [Website Model](file:///Users/etewiah/dev/sites-legacy/property_web_builder/app/models/pwb/website.rb)
- [Multi-Tenancy Specs](file:///Users/etewiah/dev/sites-legacy/property_web_builder/spec/models/pwb/website_multi_tenancy_spec.rb)
