# Namespace-Based Multi-Tenancy Plan

## Concept

Use Ruby module namespaces to clearly distinguish between:
- **`PwbTenant::`** - Models scoped to a specific tenant (website)
- **`Pwb::`** - Global/cross-tenant models and shared functionality

This makes tenant scoping explicit and obvious at the code level.

## Proposed Structure

```
app/models/
├── pwb/                        # Cross-tenant / global models
│   ├── website.rb              # The tenant itself
│   ├── user.rb                 # Users (can belong to multiple tenants)
│   ├── current.rb              # CurrentAttributes for thread-local storage
│   └── application_record.rb   # Base class for Pwb models
│
├── pwb_tenant/                 # Tenant-scoped models
│   ├── application_record.rb   # Base class with acts_as_tenant
│   ├── realty_asset.rb         # Properties
│   ├── sale_listing.rb         # Sale listings
│   ├── rental_listing.rb       # Rental listings
│   ├── page.rb                 # CMS pages
│   ├── page_part.rb            # Page components
│   ├── content.rb              # Web content
│   ├── contact.rb              # Contacts/leads
│   ├── message.rb              # Contact messages
│   ├── agency.rb               # Agency info
│   ├── link.rb                 # Navigation links
│   ├── field_key.rb            # Custom field definitions
│   └── ...
```

## Implementation

### Base Classes

```ruby
# app/models/pwb/application_record.rb
module Pwb
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = 'pwb_'
  end
end

# app/models/pwb_tenant/application_record.rb
module PwbTenant
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = 'pwb_'  # Same tables, different namespace

    # Automatic tenant scoping for ALL PwbTenant models
    acts_as_tenant :website

    # Belongs to website is implicit via acts_as_tenant
    # but we can add validations here
    validates :website, presence: true
  end
end
```

### Global Models (Pwb::)

```ruby
# app/models/pwb/website.rb
module Pwb
  class Website < ApplicationRecord
    # The tenant model - never scoped
    has_many :realty_assets, class_name: 'PwbTenant::RealtyAsset'
    has_many :pages, class_name: 'PwbTenant::Page'
    has_many :contacts, class_name: 'PwbTenant::Contact'
    # ...
  end
end

# app/models/pwb/user.rb
module Pwb
  class User < ApplicationRecord
    # Users can belong to multiple websites
    has_many :memberships, class_name: 'Pwb::UserMembership'
    has_many :websites, through: :memberships
  end
end

# app/models/pwb/current.rb
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
    attribute :user
  end
end
```

### Tenant-Scoped Models (PwbTenant::)

```ruby
# app/models/pwb_tenant/realty_asset.rb
module PwbTenant
  class RealtyAsset < ApplicationRecord
    # acts_as_tenant :website inherited from base class

    has_many :sale_listings
    has_many :rental_listings
    has_many :prop_photos
    has_many :features
  end
end

# app/models/pwb_tenant/page.rb
module PwbTenant
  class Page < ApplicationRecord
    has_many :page_parts
  end
end

# app/models/pwb_tenant/contact.rb
module PwbTenant
  class Contact < ApplicationRecord
    has_many :messages
  end
end
```

## Controller Usage

The namespace makes it immediately obvious which models are scoped:

```ruby
class SiteAdmin::PropsController < SiteAdminController
  def index
    # Obviously tenant-scoped - no manual scoping needed
    @properties = PwbTenant::RealtyAsset.order(created_at: :desc)
  end

  def show
    # Automatically scoped to current tenant
    @property = PwbTenant::RealtyAsset.find(params[:id])
  end
end

class TenantAdmin::WebsitesController < TenantAdminController
  def index
    # Obviously cross-tenant - Pwb:: namespace
    @websites = Pwb::Website.all
  end

  def show
    @website = Pwb::Website.find(params[:id])

    # Can view tenant data using with_tenant
    ActsAsTenant.with_tenant(@website) do
      @properties = PwbTenant::RealtyAsset.limit(10)
    end
  end
end
```

## Benefits

1. **Self-documenting code** - Namespace tells you immediately if model is tenant-scoped
2. **Compile-time clarity** - Can't accidentally use wrong model
3. **Automatic scoping** - All `PwbTenant::` models auto-scoped via base class
4. **Easy auditing** - grep for `Pwb::` in tenant controllers to find potential issues
5. **Clear mental model** - Developers know exactly what to expect

## Migration Strategy

### Phase 1: Create New Namespace Structure

1. Create `app/models/pwb_tenant/` directory
2. Create `PwbTenant::ApplicationRecord` base class with `acts_as_tenant`
3. Keep existing `Pwb::` models working

### Phase 2: Migrate Models One by One

For each tenant-scoped model:

```ruby
# Before: app/models/pwb/contact.rb
module Pwb
  class Contact < ApplicationRecord
    belongs_to :website
  end
end

# After: app/models/pwb_tenant/contact.rb
module PwbTenant
  class Contact < ApplicationRecord
    # acts_as_tenant inherited, no belongs_to needed
  end
end

# Temporary alias for backwards compatibility
# app/models/pwb/contact.rb
module Pwb
  Contact = PwbTenant::Contact
end
```

### Phase 3: Update Controllers

Replace `Pwb::` with `PwbTenant::` for tenant-scoped models:

```ruby
# Before
@contacts = Pwb::Contact.where(website_id: current_website.id)

# After
@contacts = PwbTenant::Contact.all
```

### Phase 4: Remove Aliases

Once all references are updated, remove the compatibility aliases.

## Model Classification

### PwbTenant:: (Tenant-Scoped)

| Model | Current Name | New Name |
|-------|--------------|----------|
| Properties | `Pwb::RealtyAsset` | `PwbTenant::RealtyAsset` |
| Sale Listings | `Pwb::SaleListing` | `PwbTenant::SaleListing` |
| Rental Listings | `Pwb::RentalListing` | `PwbTenant::RentalListing` |
| Property Photos | `Pwb::PropPhoto` | `PwbTenant::PropPhoto` |
| Features | `Pwb::Feature` | `PwbTenant::Feature` |
| Pages | `Pwb::Page` | `PwbTenant::Page` |
| Page Parts | `Pwb::PagePart` | `PwbTenant::PagePart` |
| Page Content | `Pwb::PageContent` | `PwbTenant::PageContent` |
| Content | `Pwb::Content` | `PwbTenant::Content` |
| Contacts | `Pwb::Contact` | `PwbTenant::Contact` |
| Messages | `Pwb::Message` | `PwbTenant::Message` |
| Agency | `Pwb::Agency` | `PwbTenant::Agency` |
| Links | `Pwb::Link` | `PwbTenant::Link` |
| Field Keys | `Pwb::FieldKey` | `PwbTenant::FieldKey` |
| Website Photos | `Pwb::WebsitePhoto` | `PwbTenant::WebsitePhoto` |

### Pwb:: (Global/Cross-Tenant)

| Model | Notes |
|-------|-------|
| `Pwb::Website` | The tenant itself |
| `Pwb::User` | Can belong to multiple websites |
| `Pwb::UserMembership` | Links users to websites |
| `Pwb::Current` | Thread-local current attributes |
| `Pwb::ListedProperty` | Materialized view (read-only) |

## Database Considerations

**No table changes required** - both namespaces use `table_name_prefix = 'pwb_'`:

```ruby
PwbTenant::Contact.table_name  # => "pwb_contacts"
Pwb::Website.table_name        # => "pwb_websites"
```

## Alternative: Module Include Pattern

If full rename is too disruptive, use a module pattern:

```ruby
# app/models/concerns/tenant_scoped.rb
module TenantScoped
  extend ActiveSupport::Concern

  included do
    acts_as_tenant :website
  end
end

# app/models/pwb/contact.rb
module Pwb
  class Contact < ApplicationRecord
    include TenantScoped  # Marks this as tenant-scoped
  end
end
```

Then use a linter/rubocop rule to enforce that SiteAdmin controllers only use models with `TenantScoped`.

## Estimated Timeline

| Phase | Time | Description |
|-------|------|-------------|
| Phase 1 | 2 hours | Create namespace structure and base classes |
| Phase 2 | 4-6 hours | Migrate models with compatibility aliases |
| Phase 3 | 3-4 hours | Update controllers and views |
| Phase 4 | 1-2 hours | Remove aliases, final cleanup |
| **Total** | **10-14 hours** | Full migration |

## Recommendation

This approach provides the clearest separation but requires more refactoring than just adding `acts_as_tenant`. Consider:

1. **Start with acts_as_tenant only** (8-12 hours) - Get automatic scoping working
2. **Then migrate to namespaces** (10-14 hours) - Add clarity via naming

Or do both together if you prefer a single larger refactor.
