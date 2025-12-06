# PwbTenant Scoped Models

The `PwbTenant` namespace provides secure, tenant-scoped access to models that belong to a website.

## Overview

PropertyWebBuilder uses a dual-namespace pattern for multi-tenancy:

- **`Pwb::`** - Base models that work without tenant context (for console work, cross-tenant operations)
- **`PwbTenant::`** - Tenant-scoped models that **require** a tenant to be set

This pattern ensures data isolation while allowing flexibility for administrative tasks.

## Key Concepts

### RequiresTenant Concern

All `PwbTenant::` models include the `RequiresTenant` concern which:

1. **Raises an error** if you try to query without a tenant set
2. **Scopes all queries** to the current tenant via `acts_as_tenant`
3. **Provides clear error messages** directing you to use `Pwb::` models for cross-tenant work

```ruby
# Without tenant set - RAISES ERROR
PwbTenant::Contact.count
#=> ActsAsTenant::Errors::NoTenantSet: PwbTenant::Contact requires a tenant...

# With tenant set - works correctly
ActsAsTenant.current_tenant = website
PwbTenant::Contact.count  #=> 5 (only this tenant's contacts)

# Or use a block
ActsAsTenant.with_tenant(website) do
  PwbTenant::Contact.count  #=> 5
end

# Pwb:: models always work (no tenant required)
Pwb::Contact.count  #=> 15 (all contacts across all tenants)
```

### Inheritance Pattern

`PwbTenant::` models inherit from their `Pwb::` counterparts:

```ruby
# app/models/pwb/contact.rb
module Pwb
  class Contact < ApplicationRecord
    # Full implementation - validations, associations, methods
  end
end

# app/models/pwb_tenant/contact.rb
module PwbTenant
  class Contact < Pwb::Contact
    include RequiresTenant
    acts_as_tenant :website
  end
end
```

## Available Models

| PwbTenant Model | Base Model | Notes |
|-----------------|------------|-------|
| `PwbTenant::Agency` | `Pwb::Agency` | Agency information |
| `PwbTenant::Contact` | `Pwb::Contact` | Contact/leads |
| `PwbTenant::Content` | `Pwb::Content` | Web content |
| `PwbTenant::FieldKey` | `Pwb::FieldKey` | Custom field definitions |
| `PwbTenant::Link` | `Pwb::Link` | Navigation links |
| `PwbTenant::ListedProperty` | `Pwb::ListedProperty` | Property listings view |
| `PwbTenant::Message` | `Pwb::Message` | Contact messages |
| `PwbTenant::Page` | `Pwb::Page` | CMS pages |
| `PwbTenant::PageContent` | `Pwb::PageContent` | Page content blocks |
| `PwbTenant::PagePart` | `Pwb::PagePart` | Page components |
| `PwbTenant::Prop` | `Pwb::Prop` | Legacy property model |
| `PwbTenant::RealtyAsset` | `Pwb::RealtyAsset` | Properties |
| `PwbTenant::RentalListing` | `Pwb::RentalListing` | Rental listings |
| `PwbTenant::SaleListing` | `Pwb::SaleListing` | Sale listings |
| `PwbTenant::User` | `Pwb::User` | Users |
| `PwbTenant::UserMembership` | `Pwb::UserMembership` | User-website memberships |
| `PwbTenant::WebsitePhoto` | `Pwb::WebsitePhoto` | Website images |
| `PwbTenant::Feature` | `Pwb::Feature` | Property features (tenant via parent) |

## Usage Examples

### In Controllers (SiteAdmin)

```ruby
class SiteAdmin::ContactsController < SiteAdminController
  # Tenant is automatically set via before_action in SiteAdminController

  def index
    # Automatically scoped to current website
    @contacts = PwbTenant::Contact.order(created_at: :desc)
  end

  def show
    # Raises RecordNotFound if contact belongs to another tenant
    @contact = PwbTenant::Contact.find(params[:id])
  end

  def create
    # Automatically assigns website_id
    @contact = PwbTenant::Contact.create!(contact_params)
  end
end
```

### In Console

```ruby
# List available tenants
list_tenants

# Switch to a tenant (by ID or subdomain)
tenant(1)
tenant('my-site')

# Now PwbTenant queries work
PwbTenant::Contact.count  #=> 5

# Check current tenant
current_tenant

# Clear tenant to use Pwb:: models
clear_tenant
Pwb::Contact.count  #=> 15 (all contacts)

# Or use with_tenant block
ActsAsTenant.with_tenant(Pwb::Website.find(1)) do
  PwbTenant::Contact.count
end
```

### Cross-Tenant Operations (TenantAdmin)

```ruby
class TenantAdmin::WebsitesController < TenantAdminController
  def index
    # Use Pwb:: models for cross-tenant access
    @websites = Pwb::Website.all
  end

  def show
    @website = Pwb::Website.find(params[:id])

    # View tenant data using with_tenant
    ActsAsTenant.with_tenant(@website) do
      @recent_contacts = PwbTenant::Contact.limit(10)
    end
  end
end
```

## How Tenant is Set

### In Web Requests

The `SiteAdminController` sets the tenant automatically:

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant  # Resolves website from subdomain

  before_action :set_tenant_from_subdomain

  private

  def set_tenant_from_subdomain
    ActsAsTenant.current_tenant = current_website
  end
end
```

### In Console

Use the console helpers defined in `config/initializers/console_helpers.rb`:

```ruby
tenant(1)           # Set tenant by ID
tenant('subdomain') # Set tenant by subdomain
current_tenant      # Show current tenant
clear_tenant        # Clear tenant
list_tenants        # List all tenants
```

### In Background Jobs

```ruby
class ProcessContactJob < ApplicationJob
  def perform(contact_id, website_id)
    website = Pwb::Website.find(website_id)

    ActsAsTenant.with_tenant(website) do
      contact = PwbTenant::Contact.find(contact_id)
      # Process contact...
    end
  end
end
```

## Best Practices

1. **Use `PwbTenant::` in SiteAdmin controllers** - Ensures automatic tenant scoping
2. **Use `Pwb::` for console debugging** - Allows seeing all data across tenants
3. **Use `ActsAsTenant.with_tenant` for cross-tenant work** - Explicit, safe tenant switching
4. **Never use `PwbTenant::` without setting tenant first** - Will raise clear error
5. **Website associations should use `Pwb::`** - Website already provides tenant context

## Error Handling

If you see `ActsAsTenant::Errors::NoTenantSet`:

```
PwbTenant::Contact requires a tenant to be set.
Use Pwb::Contact for cross-tenant queries,
or set a tenant with ActsAsTenant.with_tenant(website) { ... }
```

This means:
1. You're using a `PwbTenant::` model without setting a tenant
2. Fix by either:
   - Setting tenant: `ActsAsTenant.current_tenant = website`
   - Using a block: `ActsAsTenant.with_tenant(website) { ... }`
   - Switching to `Pwb::` model if cross-tenant access is intended

## Testing

When testing `PwbTenant::` models, set the tenant in your test setup:

```ruby
RSpec.describe PwbTenant::Contact, type: :model do
  let(:website) { create(:pwb_website) }

  before do
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  it 'creates contact for current tenant' do
    contact = PwbTenant::Contact.create!(first_name: 'Test')
    expect(contact.website).to eq(website)
  end
end
```

Or use `ActsAsTenant.with_tenant`:

```ruby
it 'scopes queries to tenant' do
  ActsAsTenant.with_tenant(website) do
    expect(PwbTenant::Contact.count).to eq(expected_count)
  end
end
```

## Files Reference

- `app/models/concerns/pwb_tenant/requires_tenant.rb` - The RequiresTenant concern
- `app/models/pwb_tenant/*.rb` - All tenant-scoped models
- `app/models/pwb/*.rb` - All base models
- `config/initializers/console_helpers.rb` - Console helper methods
- `config/initializers/acts_as_tenant.rb` - acts_as_tenant configuration
