# Multi-Tenancy Guide

PropertyWebBuilder supports multi-tenancy, allowing a single installation to serve multiple independent real estate websites. Each tenant is isolated by subdomain with its own data.

## Quick Start

### Create a New Tenant

```bash
# Create tenant with sample data
rake pwb:db:create_tenant[my-subdomain,my-slug,"My Company Name"]

# Create tenant without sample properties
SKIP_PROPERTIES=true rake pwb:db:create_tenant[my-subdomain,my-slug,"My Company Name"]

# List all tenants
rake pwb:db:list_tenants
```

### Access Tenants

```
http://tenant1.yourdomain.com  → Tenant 1's website
http://tenant2.yourdomain.com  → Tenant 2's website
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](./MULTI_TENANCY_ARCHITECTURE.md) | Request flow diagrams and data model |
| [Quick Reference](./MULTI_TENANCY_QUICK_REFERENCE.md) | Common patterns and gotchas |

## Architecture Overview

### Tenant Resolution

Tenants are identified by:
1. **Subdomain** (primary) - `tenant1.example.com` → finds website with `subdomain: "tenant1"`
2. **X-Website-Slug header** (API) - For programmatic access

### Data Isolation

All tenant-scoped models have a `website_id` column:

```
Pwb::Website (Tenant)
├── has_many :props
├── has_many :pages
├── has_many :contents
├── has_many :contacts
├── has_many :messages
└── has_one :agency
```

### Query Scoping

```ruby
# CORRECT - Scoped to current tenant
Pwb::Page.where(website_id: current_website.id)
current_website.props

# INCORRECT - Leaks data across tenants
Pwb::Page.all  # Returns ALL pages from ALL tenants
```

## Key Components

### Pwb::Current

Thread-local storage for current tenant context:

```ruby
# Set by SubdomainTenant concern automatically
Pwb::Current.website  # Returns current tenant's Website
```

### SubdomainTenant Concern

Included in controllers to automatically resolve tenant:

```ruby
class MyController < ApplicationController
  include SubdomainTenant
  # Now current_website is available
end
```

## Creating Tenants Programmatically

```ruby
# Create website
website = Pwb::Website.create!(
  subdomain: 'newagency',
  company_display_name: 'New Agency',
  theme_name: 'berlin',
  default_currency: 'EUR'
)

# Seed default data
Pwb::Seeder.seed!(website: website)
```

## Development Testing

Use `lvh.me` which resolves to localhost with subdomain support:

```
http://tenant1.lvh.me:3000  → tenant1's website
http://tenant2.lvh.me:3000  → tenant2's website
```

## Best Practices

### Always Scope Queries

```ruby
# Good
@pages = current_website.pages
@props = Pwb::Prop.where(website_id: current_website.id)

# Bad - Data leak!
@pages = Pwb::Page.all
```

### Use with_tenant in Seeds/Scripts

```ruby
ActsAsTenant.with_tenant(website) do
  Pwb::Prop.create!(title: "New Property")
end
```

### Test Isolation

```ruby
RSpec.describe "Feature" do
  let!(:website_a) { FactoryBot.create(:pwb_website, subdomain: 'a') }
  let!(:website_b) { FactoryBot.create(:pwb_website, subdomain: 'b') }
  
  it "isolates tenant data" do
    prop_a = ActsAsTenant.with_tenant(website_a) do
      FactoryBot.create(:pwb_prop)
    end
    
    expect(website_a.props).to include(prop_a)
    expect(website_b.props).not_to include(prop_a)
  end
end
```

## Troubleshooting

### "No tenant set" errors

Wrap model operations in tenant context:

```ruby
ActsAsTenant.with_tenant(website) do
  # Operations here are scoped to website
end
```

### Cross-tenant data leaks

Always filter queries by `website_id`:

```ruby
Pwb::Prop.where(website_id: current_website.id).find(params[:id])
```

### DNS for local development

Add to `/etc/hosts`:
```
127.0.0.1 tenant-a.localhost
127.0.0.1 tenant-b.localhost
```

Or use `lvh.me` which works out of the box.
