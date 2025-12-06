# Multi-Tenancy Implementation Analysis

## Executive Summary

PropertyWebBuilder implements a **hybrid multi-tenancy architecture** that combines:
1. **Subdomain-based tenant resolution** (public sites)
2. **Thread-local CurrentAttributes storage** (Pwb::Current)
3. **Manual scoping with `where(website_id: ...)` patterns** (controllers)
4. **Opt-in default_scope via ScopedModel concern** (limited adoption)

The implementation is **partially automated but inconsistent**. Some models use default_scope for automatic scoping, while most rely on manual controller-level filtering. This creates a risk of cross-tenant data leakage if scoping is forgotten.

---

## 1. Current Tenancy Architecture

### 1.1 Tenant Identification and Resolution

**File:** `/app/controllers/concerns/subdomain_tenant.rb`

The `SubdomainTenant` concern handles tenant resolution:

```ruby
# Priority order for tenant resolution:
1. X-Website-Slug header (for API/GraphQL)
2. Request subdomain (for browser requests)
3. Fallback to first website
```

**Key Features:**
- Subdomain extraction with reserved subdomain filtering (www, api, admin)
- Handles multi-level subdomains (takes first part)
- Sets `Pwb::Current.website` for thread-local access
- Works in both traditional controllers and API endpoints

**Reserved Subdomains:** www, api, admin, app, mail, ftp, smtp, pop, imap, ns1, ns2, localhost, staging, test, demo

### 1.2 Current Tenant Storage

**File:** `/app/models/pwb/current.rb`

```ruby
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end
```

Simple thread-local storage of the current Pwb::Website instance. Used throughout the application for implicit tenant context.

---

## 2. Model-Level Tenant Scoping

### 2.1 Tenant Associations

**Pattern:** All tenant-scoped models have a `belongs_to :website` association.

**Models with website association:**
- Pwb::Page
- Pwb::Content
- Pwb::Contact
- Pwb::Message
- Pwb::Prop (legacy)
- Pwb::ListedProperty (materialized view)
- Pwb::RealtyAsset
- Pwb::PageContent
- Pwb::PagePart
- Pwb::Link
- Pwb::Agency
- Pwb::WebsitePhoto
- Pwb::FieldKey
- Pwb::SaleListing
- Pwb::RentalListing
- Pwb::UserMembership

**Models NOT directly scoped to website:**
- Pwb::User (has optional website + multi-website support via memberships)
- Pwb::Website (the tenant itself)
- Pwb::PropPhoto (scoped via realty_asset)
- Pwb::Feature (scoped via realty_asset)

### 2.2 Database Columns

**Schema Pattern:** All tenant-scoped models have a `website_id` bigint column with an index.

Example from schema:
```ruby
create_table :pwb_contacts do |t|
  t.bigint "website_id"
  t.index ["website_id"], name: "index_pwb_contacts_on_website_id"
end
```

### 2.3 Automatic Scoping with ScopedModel Concern

**File:** `/app/models/pwb_tenant/scoped_model.rb`

**Limited Adoption - NOT ACTIVELY USED IN CURRENT MODELS**

```ruby
module PwbTenant
  module ScopedModel
    included do
      # Global scope to current website
      default_scope { where(website_id: Pwb::Current.website&.id) }
      
      # Auto-assign website on creation
      before_validation :set_current_website
    end
  end
end
```

**Issues with this approach:**
- Default scope is a Rails anti-pattern (harder to test, unexpected behavior)
- Would require all models to inherit or include this concern
- Currently NO models use this pattern in app/models/pwb/
- Could cause issues with unscoped queries needed in some contexts

**Verdict:** This concern exists but is not adopted by the models. The team chose manual scoping instead.

---

## 3. Controller-Level Tenant Scoping

### 3.1 Base Controllers with Tenancy Support

**SiteAdminController** (`/app/controllers/site_admin_controller.rb`)
- Includes `SubdomainTenant` concern
- Automatically sets `Pwb::Current.website` from subdomain
- Provides `current_website` helper method
- Used for single-website administrative operations

```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  include AdminAuthBypass
  
  def current_website
    Pwb::Current.website
  end
  helper_method :current_website
end
```

**ApplicationController** (`/app/controllers/pwb/application_controller.rb`)
- Manually resolves current_website from subdomain
- Fallback to Pwb::Current.website or first website
- Used for public-facing pages

### 3.2 Manual Scoping Pattern in Controllers

The codebase predominantly uses **explicit `where(website_id: ...)`** filtering in controllers:

**Example - SiteAdmin::MessagesController:**
```ruby
@messages = Pwb::Message.where(website_id: current_website&.id)
           .order(created_at: :desc).limit(100)
           
@message = Pwb::Message.where(website_id: current_website&.id).find(params[:id])
```

**Other examples found:**
- `PropsController`: ListedProperty.where(website_id: @current_website.id)
- `Api::V1::PropertiesController`: ListedProperty.where(website_id: Pwb::Current.website.id)
- `Editor::ImagesController`: Multiple scoped queries
- `AdminPanel`: Explicit website lookups

### 3.3 Usage of .unscoped() in Tenant Admin

**File:** `/app/controllers/tenant_admin/*`

The TenantAdmin controllers deliberately use `.unscoped()` to see ALL websites:

```ruby
# tenant_admin/websites_controller.rb
@websites = Pwb::Website.unscoped.order(created_at: :desc)
@props_count = Pwb::Prop.unscoped.where(website_id: @website.id).count

# tenant_admin/contents_controller.rb
@contents = Pwb::Content.unscoped.includes(:website).order(created_at: :desc)
```

This is appropriate - the TenantAdmin role manages multiple tenants across the platform.

---

## 4. GraphQL API Tenancy

**File:** `/app/graphql/types/query_type.rb`

GraphQL queries use `Pwb::Current.website` implicitly:

```ruby
def search_properties(**args)
  properties = Pwb::Current.website.listed_properties.visible
  # ... apply filters
end

def find_page(slug:, locale:)
  Pwb::Current.website.pages.find_by_slug(slug)
end

def get_links(placement:)
  Pwb::Current.website.links.where(placement: placement)
end
```

**Tenancy control:** Relies on SubdomainTenant concern (via X-Website-Slug header) to set Pwb::Current.website before GraphQL execution.

---

## 5. Multi-Website User Support

**File:** `/app/models/pwb/user.rb`

The User model supports multi-website access through UserMemberships:

```ruby
class User < ApplicationRecord
  belongs_to :website, optional: true
  has_many :user_memberships, dependent: :destroy
  has_many :websites, through: :user_memberships
  
  def admin_for?(website)
    user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
  end
  
  def accessible_websites
    websites.where(pwb_user_memberships: { active: true })
  end
end
```

**Validation:**
```ruby
validates :website, presence: true, if: -> { user_memberships.none? }
```

This allows users to access multiple websites while maintaining backward compatibility with single-website users.

---

## 6. Model-Specific Scoping Details

### 6.1 ListedProperty (Materialized View)

**File:** `/app/models/pwb/listed_property.rb`

```ruby
class ListedProperty < ApplicationRecord
  self.table_name = 'pwb_properties'
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  # NO automatic scoping
end
```

**Scoping:** Manually filtered in controllers via `where(website_id:...)`

**Note:** ListedProperty is read-only, backed by a materialized view for performance.

### 6.2 Page Model

**File:** `/app/models/pwb/page.rb`

```ruby
class Page < ApplicationRecord
  belongs_to :website, optional: true
  
  # Manual scoping in methods
  def get_page_part(page_part_key)
    page_parts.where(page_part_key: page_part_key, website_id: website_id).first
  end
  
  def set_fragment_visibility(page_part_key, visible_on_page)
    page_content = self.page_contents.find_or_create_by(
      page_part_key: page_part_key, 
      website_id: website_id  # Explicit scoping
    )
  end
end
```

**Key pattern:** Methods that query related models explicitly include website_id in where clauses.

### 6.3 Content Model

**File:** `/app/models/pwb/content.rb`

```ruby
# WARNING: This method exports ALL contents without tenant filtering
def self.to_csv(export_column_names = nil)
  CSV.generate do |csv|
    csv << export_column_names
    all.each do |content|  # UNSCOPED - POTENTIAL LEAK
      csv << content.attributes.values_at(*export_column_names)
    end
  end
end

# Multi-tenant safe CSV export
def self.to_csv_for_website(website, export_column_names = nil)
  CSV.generate do |csv|
    csv << export_column_names
    where(website_id: website&.id).each do |content|  # EXPLICITLY SCOPED
      csv << content.attributes.values_at(*export_column_names)
    end
  end
end
```

**Good pattern:** Method naming indicates tenant safety (to_csv_for_website)

### 6.4 Prop Model (Legacy)

**File:** `/app/models/pwb/prop.rb`

```ruby
class Prop < ApplicationRecord
  belongs_to :website, optional: true
  # NO default_scope
  # NO explicit website_id initialization in creation
  
  private
  def set_defaults
    current_website = Pwb::Current.website || website || Website.first
    return if current_website.nil?
    
    if current_website.default_currency.present?
      self.currency = current_website.default_currency
      save
    end
  end
end
```

**Issue:** No automatic website assignment during creation. Relies on controller to set website_id.

---

## 7. Website Model

**File:** `/app/models/pwb/website.rb`

The Website model is the tenant. Key features:

```ruby
class Website < ApplicationRecord
  has_many :page_contents
  has_many :contents, through: :page_contents
  has_many :listed_properties, class_name: 'Pwb::ListedProperty'
  has_many :pages
  has_many :users
  has_many :contacts
  has_many :messages
  
  # Multi-website user support
  has_many :user_memberships, dependent: :destroy
  has_many :members, through: :user_memberships, source: :user
  
  # Subdomain validation
  validates :subdomain, uniqueness: { case_sensitive: false }
  validate :subdomain_not_reserved
  
  # Find by subdomain
  def self.find_by_subdomain(subdomain)
    return nil if subdomain.blank?
    where("LOWER(subdomain) = ?", subdomain.downcase).first
  end
  
  # Explicit website_id scoping in methods
  def page_parts
    Pwb::PagePart.where(page_slug: "website", website_id: id)
  end
  
  def get_page_part(page_part_key)
    page_parts.where(page_part_key: page_part_key).first
  end
end
```

---

## 8. Data Isolation and Security

### 8.1 Potential Vulnerabilities

#### 1. **Manual Scoping Forgetting**
RISK LEVEL: **MEDIUM-HIGH**

Models without explicit scoping in controller queries could leak data. Example:

```ruby
# UNSAFE - Missing website_id filter
@all_contents = Pwb::Content.all

# SAFE
@contents = Pwb::Content.where(website_id: current_website&.id)
```

**Affected patterns:**
- Any call to `.all`, `.find()`, `.first()` on tenant models without preceding `.where(website_id:...)`
- Queries in services or jobs that don't validate tenant context

#### 2. **.unscoped() Abuse**
RISK LEVEL: **LOW** (controlled, intentional)

Uses are in TenantAdmin controllers with explicit admin role requirements. However, any new code using unscoped without careful context could leak data.

#### 3. **Models Without Explicit Scoping**
RISK LEVEL: **MEDIUM**

Several models don't enforce website_id assignment:
- Pwb::Prop: No before_validation to set website_id
- Pwb::Contact: website_id is optional and not set automatically
- Pwb::Message: website_id is optional

```ruby
# Prop model - NO auto-assignment
class Prop < ApplicationRecord
  belongs_to :website, optional: true
  # Missing: before_validation :set_current_website
end
```

#### 4. **Null website_id Values**
RISK LEVEL: **MEDIUM**

Several models have `optional: true` on website association, allowing null website_id:
- Contact: `belongs_to :website, optional: true`
- Message: `belongs_to :website, optional: true`
- Content: `belongs_to :website, optional: true`

This could allow queries like `where(website_id: nil)` to leak shared data.

#### 5. **GraphQL/API Header-Based Tenancy**
RISK LEVEL: **LOW-MEDIUM**

The X-Website-Slug header could be spoofed if validation is weak:
```ruby
slug = request.headers["X-Website-Slug"]
Pwb::Current.website = Pwb::Website.find_by(slug: slug)
```

Mitigation: Should validate slug against authenticated user's accessible websites.

### 8.2 Protected Patterns

**Strengths:**
- URL-based subdomain routing makes tenant mismatches obvious
- Controller layer filtering (where(website_id:...)) is pervasive and mostly followed
- SiteAdminController includes SubdomainTenant automatically
- GraphQL queries implicitly use Pwb::Current.website
- Tests would catch obvious data leaks with subdomain mismatch

---

## 9. Cross-Tenant Data Leakage Prevention

### 9.1 Current Safeguards

1. **Subdomain routing** - Most natural safeguard (URL-visible)
2. **Manual where clauses** - Required for safety, widely used
3. **Helper methods** - current_website passed explicitly to queries
4. **Controller-based filtering** - Layered defense
5. **Materialized view queries** - Always through association (Pwb::Website.listed_properties)

### 9.2 Gaps and Weaknesses

| Risk Area | Current State | Missing |
|-----------|---------------|---------|
| Model-level enforcement | Optional (ScopedModel unused) | Default scope on all models |
| Auto-assignment | Ad-hoc (some models) | Consistent before_validation |
| API security | Header-based tenant | Validation against user roles |
| Query safety | Manual (error-prone) | Automatic/enforced scoping |
| Testing | Not addressed | Tenant isolation specs |
| Unscoped queries | Intentional (TenantAdmin) | Policy/restrictions |

---

## 10. Would acts_as_tenant Gem Help?

### Gem Overview
`acts_as_tenant` automatically scopes all queries to current tenant via default_scope.

### Benefits for This Project

1. **Automatic Query Scoping**
   ```ruby
   # With acts_as_tenant
   class Content < ApplicationRecord
     acts_as_tenant :website
   end
   
   Content.all  # Automatically scoped to Pwb::Current.website
   ```
   - Reduces manual scoping burden
   - Would catch many bugs automatically

2. **Consistent Enforcement**
   - All models benefit from same safety mechanism
   - Less room for developer error

3. **Better Test Isolation**
   - Default scope helps prevent test data leakage

### Drawbacks and Concerns

1. **Performance Impact**
   - Default scope affects ALL queries
   - Potential N+1 problems
   - Some queries legitimately need unscoped access (TenantAdmin)

2. **Incompatibility**
   ```ruby
   # Current code using .unscoped() would break
   Pwb::Website.unscoped.order(created_at: :desc)
   Pwb::Content.unscoped.includes(:website)  # Would need explicit logic
   ```
   - TenantAdmin controllers depend on .unscoped()
   - Would require significant refactoring

3. **Materialized Views**
   - ListedProperty is read-only, would conflicts with acts_as_tenant assumptions

4. **Multi-Website Users**
   - Acts_as_tenant doesn't handle multi-membership well
   - User can access multiple websites, but only one is "current"

5. **Testing Complexity**
   - Default scopes make some tests harder to write
   - Unscoped queries needed for admin features
   - Could complicate test setup

### Recommendation

**CAUTIOUS: NOT RECOMMENDED in current state, but could be beneficial with:**

1. **Partial adoption approach:**
   - Only apply to core models (Page, Content, Message, Contact)
   - NOT to User, Website, ListedProperty
   - Keep .unscoped() available for admin features

2. **Alternative improvements (RECOMMENDED):**
   - Add `before_validation :set_website` to all models without it
   - Create a `SiteAdmin::Base` model concern that enforces scoping
   - Implement query validation tests for tenant isolation
   - Add strong_assign_attributes to SiteAdminController
   - Use scope methods consistently:
     ```ruby
     scope :for_website, ->(website) { where(website_id: website&.id) }
     Page.for_website(current_website)  # More explicit and testable
     ```

3. **If you adopt acts_as_tenant:**
   - Keep it optional (only include in models that need it)
   - Use `acts_as_tenant :website, optional: true` where needed
   - Explicit tenant assignment in controllers
   - Strong tests for unscoped queries in admin controllers

---

## 11. Current Implementation Summary

### Strengths
1. ✅ Clear tenant model (Website)
2. ✅ Consistent foreign key pattern (website_id)
3. ✅ Subdomain-based routing
4. ✅ Thread-local CurrentAttributes storage
5. ✅ Most controllers manually filter properly
6. ✅ Good separation of SiteAdmin vs TenantAdmin concerns

### Weaknesses
1. ❌ No automatic model-level scoping (ScopedModel unused)
2. ❌ Manual where clauses are error-prone
3. ❌ Inconsistent website_id assignment (some models auto-assign, others don't)
4. ❌ Several models have optional website_id
5. ❌ No test-level tenant isolation enforcement
6. ❌ API security relies only on header validation
7. ❌ No validation that user can access requested website

### Risk Level: **MEDIUM**
- Current code mostly follows safety patterns
- But lacks enforcement mechanisms
- Single developer mistake could leak data
- No automated tests checking tenant isolation

---

## 12. Recommended Improvements

### Priority 1 (Do First)
1. **Add automatic website_id assignment** to all models
   ```ruby
   before_validation :set_current_website
   
   def set_current_website
     self.website_id ||= Pwb::Current.website&.id
   end
   ```

2. **Create test suite for tenant isolation**
   - Verify queries in one subdomain don't leak into another
   - Test header-based API tenant switching

3. **Validate user can access website before processing**
   ```ruby
   def current_website
     website = Pwb::Website.find_by_subdomain(request.subdomain)
     authorize_website_access!(website) if current_user
     website
   end
   ```

### Priority 2 (Soon)
1. **Create helper method for safe queries**
   ```ruby
   def scoped_for_website(model_class)
     model_class.where(website_id: current_website&.id)
   end
   ```

2. **Add strong params filtering** to prevent mass assignment of website_id
   ```ruby
   def permitted_params
     params.require(:content).permit(...).except(:website_id)
   end
   ```

3. **Document tenancy patterns** (add to README)

### Priority 3 (Nice to Have)
1. **Evaluate acts_as_tenant** for core models (test with Page, Content)
2. **Add Pundit authorization** for role-based access
3. **Create admin-only scopes** to explicitly show all-tenants queries

---

## 13. Key Files Reference

| File | Purpose | Tenancy Method |
|------|---------|-----------------|
| `/app/controllers/concerns/subdomain_tenant.rb` | Tenant resolution | Subdomain + thread-local |
| `/app/models/pwb/current.rb` | Thread-local storage | CurrentAttributes |
| `/app/models/pwb_tenant/scoped_model.rb` | Automatic scoping (unused) | default_scope |
| `/app/controllers/site_admin_controller.rb` | Admin base controller | SubdomainTenant concern |
| `/app/controllers/pwb/application_controller.rb` | Public base controller | Manual subdomain resolution |
| `/app/models/pwb/website.rb` | The tenant model | Foreign key pattern |
| `/app/models/pwb/page.rb` | Example model | Manual where clauses |
| `/app/models/pwb/user.rb` | Multi-website support | Memberships + foreign key |
| `/app/graphql/types/query_type.rb` | GraphQL entry point | Implicit Pwb::Current.website |

---

## 14. Conclusion

PropertyWebBuilder uses a **manual, discipline-based multi-tenancy approach** that works but lacks automation. The SubdomainTenant concern + thread-local storage pattern is solid, but the heavy reliance on manual `where(website_id:...)` filtering creates risk.

The unused `ScopedModel` concern suggests the team originally considered automatic scoping but chose explicit filtering for clarity and control. This is reasonable but requires careful code review and testing.

**Recommendation:** Improve the approach by:
1. Making website_id auto-assignment consistent
2. Adding tenant isolation tests
3. Creating explicit scoping helper methods
4. Documenting patterns clearly
5. Only consider acts_as_tenant if performance/safety testing shows clear benefit
