# Multi-Tenancy Routing Implementation

## Overview

PropertyWebBuilder implements a multi-tenant architecture where each website is a tenant. The system uses subdomain-based routing to identify which tenant should handle a request, combined with the `acts_as_tenant` gem for automatic database scoping.

## Key Components

### 1. Website Model & Database Schema

**Location:** `/app/models/pwb/website.rb`

**Table:** `pwb_websites`

**Key Fields:**
- `subdomain` (string, unique, case-insensitive) - Primary routing identifier
- `slug` (string) - Alternative identifier for API requests via header
- `company_display_name` (string)
- `theme_name` (string)
- Other configuration fields

**Schema Details (lines 1230-1290 in schema.rb):**
```sql
create_table "pwb_websites", id: :serial, force: :cascade do |t|
  t.string "subdomain"
  t.string "slug"
  t.index ["subdomain"], name: "index_pwb_websites_on_subdomain", unique: true
  ...
end
```

**Key Methods:**
- `find_by_subdomain(subdomain)` (line ~67 in website.rb) - Case-insensitive lookup
- Validations (lines ~48-62):
  - Subdomain format: alphanumeric + hyphens only, 2-63 chars
  - Unique constraint
  - Reserved subdomain validation (www, api, admin, app, mail, ftp, smtp, pop, imap, ns1, ns2, localhost, staging, test, demo)

### 2. Subdomain-Based Routing Concern

**Location:** `/app/controllers/concerns/subdomain_tenant.rb`

This concern handles the core routing logic and is included in controllers that need multi-tenancy support.

**Key Method: `set_current_website_from_subdomain` (lines ~14-39)**
- Priority order:
  1. Check `X-Website-Slug` request header (for API/GraphQL clients)
  2. Extract and validate request subdomain
  3. Fallback to first website in database

**Key Method: `request_subdomain` (lines ~41-60)**
- Extracts subdomain from request
- Ignores common non-tenant subdomains: www, api, admin
- Handles multi-level domains (e.g., "site1.staging" → "site1")

### 3. Current Attributes Pattern

**Location:** `/app/models/pwb/current.rb`

```ruby
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end
```

- Uses Rails 5.2+ `ActiveSupport::CurrentAttributes` for request-scoped storage
- Available as `Pwb::Current.website` throughout the request lifecycle

### 4. Controller Integration

#### SiteAdminController (Single Tenant - Subdomain Scoped)

**Location:** `/app/controllers/site_admin_controller.rb` (lines ~1-75)

Manages a single website/tenant:
- Includes `SubdomainTenant` concern - automatically sets current website from subdomain
- Sets `ActsAsTenant.current_tenant = current_website` (line ~68)
- All PwbTenant:: model queries automatically scoped to this tenant
- Requires authentication + admin authorization for the website

**Key Methods:**
- `current_website` (line ~37) - Helper to get the resolved website
- `set_tenant_from_subdomain` (line ~68-70) - Sets tenant for acts_as_tenant

#### TenantAdminController (Cross-Tenant)

**Location:** `/app/controllers/tenant_admin_controller.rb` (lines ~1-60)

Manages all tenants/websites:
- Does NOT include `SubdomainTenant` concern (intentional cross-tenant access)
- Authorization via TENANT_ADMIN_EMAILS environment variable
- Can access all websites without tenant scoping
- Uses `unscoped_model()` helper for cross-tenant queries

#### Pwb::ApplicationController (Public-Facing)

**Location:** `/app/controllers/pwb/application_controller.rb` (lines ~1-73)

Serves public website content:
- Uses `current_website_from_subdomain` (line ~50)
- Falls back to first website if subdomain not found
- Sets locale, theme path, and other per-website settings

### 5. Acts-as-Tenant Configuration

**Location:** `/config/initializers/acts_as_tenant.rb`

```ruby
ActsAsTenant.configure do |config|
  config.require_tenant = false
end
```

- Set to `false` to allow Pwb:: models to work without tenant context
- Allows TenantAdminController cross-tenant access
- PwbTenant:: models still enforce scoping

### 6. Model Architecture

#### Pwb::ApplicationRecord

**Location:** `/app/models/pwb/application_record.rb`

```ruby
module Pwb
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "pwb_"
  end
end
```

- Base class for non-scoped models (like Pwb::Website itself)
- Can be queried globally without tenant context

#### PwbTenant::ApplicationRecord

**Location:** `/app/models/pwb_tenant/application_record.rb`

```ruby
module PwbTenant
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = 'pwb_'
    acts_as_tenant :website, class_name: 'Pwb::Website'
    validates :website, presence: true
  end
end
```

- Base class for tenant-scoped models
- Automatically filtered by `ActsAsTenant.current_tenant`
- All PwbTenant:: models inherit automatic scoping

### 7. Route Constraints

**Location:** `/lib/constraints/tenant_admin_constraint.rb`

Route constraint for protecting admin-only routes:
- Checks `TENANT_ADMIN_EMAILS` environment variable
- Used in routes.rb for mounting admin engines (Logster, ActiveStorageDashboard)
- Can bypass in development with `BYPASS_ADMIN_AUTH=true`

**Usage (routes.rb line ~75-80):**
```ruby
constraints Constraints::TenantAdminConstraint.new do
  mount ActiveStorageDashboard::Engine => "/active_storage_dashboard"
  mount Logster::Web, at: "/logs"
end
```

### 8. Routing Structure

**Location:** `/config/routes.rb`

**Public Routes (scoped to current subdomain):**
- Line ~80-200: Main public routes (pages, properties, search)
- Locale support via `scope "(:locale)"`
- Automatically use `current_website` from subdomain

**Site Admin Routes (namespace: :site_admin):**
- Line ~39-79: Dashboard and CRUD for single website
- Includes SubdomainTenant concern
- Requires admin authentication

**Tenant Admin Routes (namespace: :tenant_admin):**
- Line ~11-37: Cross-tenant management
- No SubdomainTenant concern (cross-tenant by design)
- Requires TENANT_ADMIN_EMAILS authorization

**API Routes:**
- Line ~209-310: API v1 routes with tenant scoping
- Line ~313-328: Public API routes (api_public)

## Data Isolation & Scoping

### Automatic Scoping

For models inheriting from `PwbTenant::ApplicationRecord`:
```ruby
# Automatically filtered to current website
PwbTenant::Contact.all  
# => SELECT * FROM pwb_contacts WHERE website_id = current_website.id
```

### Manual Scoping (for Pwb:: models)

For non-scoped models that have `website_id`:
```ruby
# Manual where clause needed
Pwb::Prop.where(website_id: current_website.id)
```

### Cross-Tenant Access

In TenantAdminController or super-admin contexts:
```ruby
# Bypass tenant scoping
ActsAsTenant.without_tenant do
  PwbTenant::Contact.all  # => Returns ALL contacts across websites
end
```

## Subdomain Resolution Priority

1. **X-Website-Slug Header** (for API clients)
   - Check request header: `X-Website-Slug`
   - Look up by Website.slug

2. **Request Subdomain** (for browser requests)
   - Extract request.subdomain
   - Filter out reserved subdomains (www, api, admin)
   - Look up by Website.find_by_subdomain()
   - Case-insensitive match

3. **Fallback**
   - Return first website in database
   - Used when no subdomain can be determined

## Request Flow Example

### Example 1: Browser Request to Subdomain

Request: `https://myagency.example.com/properties`

1. Rails extracts subdomain: "myagency"
2. SubdomainTenant concern calls `set_current_website_from_subdomain`
3. Looks up: `Website.find_by_subdomain("myagency")`
4. Sets: `Pwb::Current.website = Website[id: 1, subdomain: "myagency", ...]`
5. Sets: `ActsAsTenant.current_tenant = current_website`
6. All PwbTenant:: queries automatically scoped: `WHERE website_id = 1`

### Example 2: API Request with Header

Request: `POST https://api.example.com/graphql` with header `X-Website-Slug: myagency`

1. SubdomainTenant concern calls `set_current_website_from_subdomain`
2. Reads header: "myagency"
3. Looks up: `Website.find_by(slug: "myagency")`
4. Sets: `Pwb::Current.website = Website[id: 1, ...]`
5. GraphQL queries automatically scoped

### Example 3: Cross-Tenant Admin Access

Request: `GET https://admin.example.com/tenant_admin/websites`

1. TenantAdminController - no SubdomainTenant concern
2. TenantAdminController checks `TENANT_ADMIN_EMAILS` authorization
3. Query: `Website.all` (not scoped - cross-tenant access)
4. Returns all websites for super-admin management

## Database Migrations

**Recent multi-tenancy migrations:**

| Migration | Purpose |
|-----------|---------|
| 20251121190959 | Add website_id to tables |
| 20251121191127 | Add slug to websites |
| 20251126181412 | Add subdomain to websites |
| 20251127143145 | Scope links.slug by website |
| 20251127150724 | Scope contents.key by website |
| 20251202112123 | Add website_id to page_parts |
| 20251204135225 | Add website_id to field_keys |
| 20251204141849 | Add website to contacts, messages, photos |

## Environment Configuration

**Key Environment Variables:**

```bash
# Super admin authorization (comma-separated emails)
TENANT_ADMIN_EMAILS="admin@example.com,super@example.com"

# Development bypass (NOT for production)
BYPASS_ADMIN_AUTH=true
```

## Security Considerations

1. **Reserved Subdomains** - Cannot be assigned to tenants:
   - www, api, admin, app, mail, ftp, smtp, pop, imap, ns1, ns2, localhost, staging, test, demo

2. **Case Insensitivity** - Subdomain lookup is case-insensitive to prevent tenant confusion

3. **Automatic Scoping** - Acts_as_tenant prevents accidental cross-tenant queries for PwbTenant:: models

4. **Authorization Layers**:
   - Public routes: No auth needed
   - Site Admin: User must be authenticated + admin for that website
   - Tenant Admin: User email must be in TENANT_ADMIN_EMAILS list

## Troubleshooting

### Website Not Found

If `current_website` is nil:
1. Check subdomain is spelled correctly
2. Ensure website exists with that subdomain in database
3. Verify subdomain is not in reserved list
4. Check X-Website-Slug header matches a website.slug

### Cross-Tenant Data Leak

If seeing data from wrong tenant:
1. Verify `ActsAsTenant.current_tenant` is set in controller
2. Use `PwbTenant::` models instead of `Pwb::` for scoped queries
3. Check for manual `.where()` overrides that bypass scoping

### Subdomain Not Resolving

Common causes:
1. DNS not configured (subdomain needs A/CNAME record)
2. Rails domain config - check `config.hosts` in environment file
3. Test environment - use `host:` parameter in request specs

## Files Summary

| File | Purpose |
|------|---------|
| `/app/models/pwb/website.rb` | Website model, subdomain validation |
| `/app/models/pwb/current.rb` | Request-scoped current attributes |
| `/app/controllers/concerns/subdomain_tenant.rb` | Subdomain routing logic |
| `/app/controllers/site_admin_controller.rb` | Single-tenant admin base |
| `/app/controllers/tenant_admin_controller.rb` | Cross-tenant admin base |
| `/app/controllers/pwb/application_controller.rb` | Public website base |
| `/app/models/pwb/application_record.rb` | Non-scoped model base |
| `/app/models/pwb_tenant/application_record.rb` | Scoped model base |
| `/lib/constraints/tenant_admin_constraint.rb` | Route constraint for admins |
| `/config/initializers/acts_as_tenant.rb` | Acts_as_tenant config |
| `/config/routes.rb` | Route definitions |
| `/db/schema.rb` | Database schema |
