# acts_as_tenant Adoption Plan

## Overview

This document outlines the plan for adopting the `acts_as_tenant` gem to improve multi-tenancy handling in PropertyWebBuilder.

## Current State

PropertyWebBuilder currently uses a manual multi-tenancy approach:
- `Pwb::Current.website` stores the current tenant (thread-local)
- Controllers manually scope queries with `where(website_id: current_website&.id)`
- Models have `belongs_to :website` associations
- A `ScopedModel` concern exists but is not actively used

### Problems with Current Approach

1. **Boilerplate code** - Every controller action must remember to add website scope
2. **Risk of data leakage** - Forgetting to scope a query exposes other tenants' data
3. **Inconsistent patterns** - Some places use `current_website`, others use `Pwb::Current.website`
4. **No automatic assignment** - New records must manually set `website_id`

## What acts_as_tenant Provides

```ruby
# In model
class Pwb::Page < ApplicationRecord
  acts_as_tenant :website
end

# Queries are automatically scoped
Pwb::Page.all  # => SELECT * FROM pwb_pages WHERE website_id = 123

# New records automatically get tenant assigned
Pwb::Page.create(slug: 'home')  # => website_id automatically set

# Unscoped queries raise errors (configurable)
Pwb::Page.unscoped.all  # => raises error if require_tenant enabled
```

## Implementation Plan

### Phase 1: Setup and Infrastructure (1-2 hours)

1. **Add gem to Gemfile**
   ```ruby
   gem 'acts_as_tenant', '~> 1.0'
   ```

2. **Configure in initializer**
   ```ruby
   # config/initializers/acts_as_tenant.rb
   ActsAsTenant.configure do |config|
     config.require_tenant = false  # Start permissive, tighten later
   end
   ```

3. **Set tenant in ApplicationController**
   ```ruby
   class ApplicationController < ActionController::Base
     set_current_tenant_through_filter
     before_action :set_tenant

     private

     def set_tenant
       set_current_tenant(Pwb::Current.website)
     end
   end
   ```

4. **Update SiteAdminController**
   ```ruby
   class SiteAdminController < ActionController::Base
     set_current_tenant_through_filter
     before_action :set_tenant

     private

     def set_tenant
       set_current_tenant(current_website)
     end
   end
   ```

### Phase 2: Model Migration - Core Models (2-3 hours)

Migrate models in order of dependency (leaf models first):

**Batch 1: Simple Models (no has_many through website)**
```ruby
# app/models/pwb/contact.rb
class Pwb::Contact < ApplicationRecord
  acts_as_tenant :website
  # Remove: belongs_to :website (acts_as_tenant adds this)
end
```

Models to update:
- [ ] `Pwb::Contact`
- [ ] `Pwb::Message`
- [ ] `Pwb::Content`
- [ ] `Pwb::Link`
- [ ] `Pwb::FieldKey`
- [ ] `Pwb::WebsitePhoto`

**Batch 2: Page-related Models**
- [ ] `Pwb::Page`
- [ ] `Pwb::PagePart`
- [ ] `Pwb::PageContent`

**Batch 3: Property Models**
- [ ] `Pwb::RealtyAsset`
- [ ] `Pwb::SaleListing` (through realty_asset or direct?)
- [ ] `Pwb::RentalListing` (through realty_asset or direct?)

**Batch 4: Agency Model**
- [ ] `Pwb::Agency`

### Phase 3: Controller Cleanup (2-3 hours)

Remove manual scoping from controllers:

**Before:**
```ruby
def index
  @contacts = Pwb::Contact.where(website_id: current_website&.id).order(created_at: :desc)
end

def show
  @contact = Pwb::Contact.where(website_id: current_website&.id).find(params[:id])
end
```

**After:**
```ruby
def index
  @contacts = Pwb::Contact.order(created_at: :desc)
end

def show
  @contact = Pwb::Contact.find(params[:id])
end
```

Controllers to update:
- [ ] `SiteAdmin::ContactsController`
- [ ] `SiteAdmin::MessagesController`
- [ ] `SiteAdmin::ContentsController`
- [ ] `SiteAdmin::PagesController`
- [ ] `SiteAdmin::PagePartsController`
- [ ] `SiteAdmin::UsersController`
- [ ] `SiteAdmin::PropsController`
- [ ] `SiteAdmin::Properties::SettingsController`
- [ ] `Pwb::Api::V1::*` controllers
- [ ] `ApiPublic::V1::*` controllers

### Phase 4: Test Updates (2-3 hours)

Update specs to work with acts_as_tenant:

```ruby
RSpec.describe SiteAdmin::ContactsController, type: :controller do
  let(:website) { create(:pwb_website) }

  before do
    # Set tenant for acts_as_tenant
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  # Tests remain largely the same but cross-tenant tests
  # now verify acts_as_tenant protection
end
```

### Phase 5: Enable Strict Mode (optional, 1 hour)

Once confident:

```ruby
# config/initializers/acts_as_tenant.rb
ActsAsTenant.configure do |config|
  config.require_tenant = true  # Raise if no tenant set
end
```

This will catch any unscoped queries during development/testing.

## Models NOT to Migrate

Some models should NOT use acts_as_tenant:

1. **`Pwb::Website`** - The tenant model itself
2. **`Pwb::User`** - Can belong to multiple websites via memberships
3. **`Pwb::PropPhoto`** - Scoped through `RealtyAsset`
4. **`Pwb::Feature`** - Scoped through `RealtyAsset`
5. **`Pwb::ListedProperty`** - Materialized view, read-only

## Migration Considerations

### Database Changes
No database migrations needed - `website_id` columns already exist on all models.

### Backwards Compatibility
- Keep `belongs_to :website` validations initially
- `acts_as_tenant` adds `belongs_to` automatically
- Remove redundant `belongs_to` declarations after verification

### Testing Strategy
1. Run full test suite after each batch
2. Manually test admin interface for each model
3. Check for any unscoped queries in logs

## Rollback Plan

If issues arise:
1. Remove `acts_as_tenant` from models
2. Restore manual `where(website_id: ...)` scoping
3. Remove gem from Gemfile

The rollback is straightforward since no database changes are required.

## Estimated Timeline

| Phase | Time | Description |
|-------|------|-------------|
| Phase 1 | 1-2 hours | Setup and infrastructure |
| Phase 2 | 2-3 hours | Model migration |
| Phase 3 | 2-3 hours | Controller cleanup |
| Phase 4 | 2-3 hours | Test updates |
| Phase 5 | 1 hour | Enable strict mode |
| **Total** | **8-12 hours** | Full implementation |

## Success Criteria

- [ ] All tenant-scoped models use `acts_as_tenant`
- [ ] Controllers no longer have manual `where(website_id: ...)` calls
- [ ] All existing tests pass
- [ ] No cross-tenant data leakage in manual testing
- [ ] `require_tenant = true` enabled without errors

## References

- [acts_as_tenant gem](https://github.com/ErwinM/acts_as_tenant)
- [acts_as_tenant documentation](https://github.com/ErwinM/acts_as_tenant#readme)
- Current analysis: `docs/multi_tenancy/MULTI_TENANCY_ANALYSIS.md`
