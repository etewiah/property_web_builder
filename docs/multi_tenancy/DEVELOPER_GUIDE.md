# Multi-Tenancy Developer Guide

**Quick reference for working with PropertyWebBuilder's multi-tenant architecture**

---

## TL;DR

- Use **PwbTenant::** models in controllers/views (automatic tenant scoping)
- Use **Pwb::** models in console/admin (manual scoping required)
- Always set tenant context before querying PwbTenant:: models
- Test cross-tenant isolation for any new features

---

## When to Use Which Namespace

### Use PwbTenant:: Models When:

✅ Writing controller actions for site admins  
✅ Building API endpoints for tenant users  
✅ Rendering views with tenant-specific data  
✅ You want automatic tenant scoping  
✅ You want protection against accidental cross-tenant queries

**Example:**
```ruby
class SiteAdmin::PagesController < SiteAdminController
  def index
    # Automatically scoped to current website
    @pages = PwbTenant::Page.all
  end
  
  def show
    # Will raise RecordNotFound if page belongs to different tenant
    @page = PwbTenant::Page.find(params[:id])
  end
end
```

### Use Pwb:: Models When:

✅ Working in Rails console  
✅ Writing tenant admin features (cross-tenant access)  
✅ Writing background jobs that operate on multiple tenants  
✅ Writing migrations or seed scripts  
✅ You need explicit control over tenant scoping

**Example:**
```ruby
class TenantAdmin::WebsitesController < TenantAdminController
  def index
    # Explicitly access all websites across all tenants
    @websites = Pwb::Website.unscoped.all
  end
  
  def show
    # Can access any website regardless of current tenant
    @website = Pwb::Website.unscoped.find(params[:id])
  end
end
```

---

## Setting Tenant Context

### In Controllers (Automatic)

Controllers that inherit from `SiteAdminController` or include `SubdomainTenant` automatically set the tenant:

```ruby
class SiteAdmin::ContactsController < SiteAdminController
  # Tenant is automatically set from subdomain/domain
  # No manual setup needed
  
  def index
    @contacts = PwbTenant::Contact.all  # Scoped to current website
  end
end
```

### In Background Jobs (Using TenantAwareJob)

Background jobs can use the `TenantAwareJob` concern for cleaner tenant handling:

```ruby
class SendNewsletterJob < ApplicationJob
  include TenantAwareJob  # Provides with_tenant helper

  def perform(website_id:, newsletter_id:)
    with_tenant(website_id) do
      # PwbTenant:: models are now scoped
      newsletter = PwbTenant::Newsletter.find(newsletter_id)
      newsletter.send_to_subscribers
    end
  end
end
```

Or use the manual approach:

```ruby
class SendNewsletterJob < ApplicationJob
  def perform(website_id:, newsletter_id:)
    website = Pwb::Website.find(website_id)

    # Set tenant context for this job
    ActsAsTenant.with_tenant(website) do
      Pwb::Current.website = website
      newsletter = PwbTenant::Newsletter.find(newsletter_id)
      newsletter.send_to_subscribers
    end
  end
end
```

### In Rails Console (Manual)

```ruby
# Find the website
website = Pwb::Website.find_by(subdomain: 'demo')

# Set tenant context
ActsAsTenant.with_tenant(website) do
  # Now PwbTenant:: models are scoped
  pages = PwbTenant::Page.all
  puts "Pages for #{website.subdomain}: #{pages.count}"
end

# Or use Pwb:: models with manual scoping
pages = Pwb::Page.where(website_id: website.id)
```

### In Tests (Manual)

```ruby
RSpec.describe 'Some feature', type: :request do
  let(:website) { create(:pwb_website) }
  
  before do
    # Set tenant for the test
    ActsAsTenant.current_tenant = website
  end
  
  it 'scopes data to tenant' do
    page = create(:pwb_page, website: website)
    
    ActsAsTenant.with_tenant(website) do
      expect(PwbTenant::Page.all).to include(page)
    end
  end
end
```

---

## Common Patterns

### Pattern 1: Controller with Tenant Scoping

```ruby
class SiteAdmin::PropertiesController < SiteAdminController
  # Tenant is set automatically by SubdomainTenant concern
  
  def index
    # Use PwbTenant:: for automatic scoping
    @properties = PwbTenant::Prop.where(visible: true)
                                  .order(created_at: :desc)
                                  .page(params[:page])
  end
  
  def show
    # find() will raise RecordNotFound if property belongs to different tenant
    @property = PwbTenant::Prop.find(params[:id])
  end
  
  def create
    # New records automatically get current tenant's website_id
    @property = PwbTenant::Prop.new(property_params)
    
    if @property.save
      redirect_to site_admin_property_path(@property)
    else
      render :new
    end
  end
end
```

### Pattern 2: Background Job with Tenant Context

```ruby
class ProcessPropertyImportJob < ApplicationJob
  queue_as :default
  
  def perform(website_id:, import_file_path:)
    # Always pass website_id as a parameter
    website = Pwb::Website.find(website_id)
    
    # Set tenant context for the job
    ActsAsTenant.with_tenant(website) do
      # Now PwbTenant:: models are scoped to this website
      importer = PropertyImporter.new(import_file_path)
      importer.import_properties
    end
  end
end

# Enqueue the job
ProcessPropertyImportJob.perform_later(
  website_id: current_website.id,
  import_file_path: '/path/to/file.csv'
)
```

### Pattern 3: Cross-Tenant Admin Operation

```ruby
class TenantAdmin::ReportsController < TenantAdminController
  def property_counts
    # Use Pwb:: models with explicit scoping
    @counts = Pwb::Website.unscoped.all.map do |website|
      {
        website: website.subdomain,
        properties: Pwb::Prop.where(website_id: website.id).count,
        pages: Pwb::Page.where(website_id: website.id).count
      }
    end
  end
end
```

### Pattern 4: Service Object with Tenant

```ruby
class PropertySearchService
  def initialize(website)
    @website = website
  end
  
  def search(params)
    ActsAsTenant.with_tenant(@website) do
      # All queries automatically scoped to @website
      PwbTenant::Prop.where(visible: true)
                     .where('price_sale_current_cents >= ?', params[:min_price])
                     .where('price_sale_current_cents <= ?', params[:max_price])
    end
  end
end

# Usage in controller
class PropertiesController < ApplicationController
  def search
    service = PropertySearchService.new(current_website)
    @properties = service.search(search_params)
  end
end
```

---

## Tenant Resolution

Tenant is resolved in this priority order:

1. **X-Website-Slug header** (for API requests)
   ```ruby
   # API request
   headers = { 'X-Website-Slug' => 'demo' }
   get '/api/properties', headers: headers
   ```

2. **Custom domain** (if configured)
   ```
   https://myrealestate.com → Website.find_by(custom_domain: 'myrealestate.com')
   ```

3. **Subdomain**
   ```
   https://demo.propertywebbuilder.com → Website.find_by(subdomain: 'demo')
   ```

4. **Pwb::Current.website** (from previous request in same thread)

5. **Website.first** (development/test fallback only - **disabled in production**)

### Production Behavior

In production, if no tenant can be resolved, API requests return:

```json
{
  "success": false,
  "error": "Missing or invalid tenant. Provide X-Website-Slug header or use subdomain."
}
```

The `Website.first` fallback is **disabled in production** to prevent accidental cross-tenant data exposure.

---

## Creating New Tenant-Scoped Models

### Step 1: Create Migration

```ruby
class CreatePwbNewsletters < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_newsletters do |t|
      t.string :subject
      t.text :body
      t.integer :website_id, null: false  # Required!
      
      t.timestamps
    end
    
    add_index :pwb_newsletters, :website_id  # Important for performance!
  end
end
```

### Step 2: Create Pwb:: Model

```ruby
# app/models/pwb/newsletter.rb
module Pwb
  class Newsletter < ApplicationRecord
    belongs_to :website, class_name: 'Pwb::Website'
    validates :website, presence: true
    validates :subject, presence: true
  end
end
```

### Step 3: Create PwbTenant:: Model

```ruby
# app/models/pwb_tenant/newsletter.rb
module PwbTenant
  class Newsletter < Pwb::Newsletter
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
```

### Step 4: Add Tests

```ruby
# spec/models/pwb_tenant/newsletter_spec.rb
RSpec.describe PwbTenant::Newsletter, type: :model do
  let(:website_a) { create(:pwb_website) }
  let(:website_b) { create(:pwb_website) }
  
  it 'scopes to current tenant' do
    newsletter_a = nil
    newsletter_b = nil
    
    ActsAsTenant.with_tenant(website_a) do
      newsletter_a = create(:pwb_newsletter, website: website_a)
    end
    
    ActsAsTenant.with_tenant(website_b) do
      newsletter_b = create(:pwb_newsletter, website: website_b)
    end
    
    ActsAsTenant.with_tenant(website_a) do
      expect(PwbTenant::Newsletter.all).to include(newsletter_a)
      expect(PwbTenant::Newsletter.all).not_to include(newsletter_b)
    end
  end
  
  it 'prevents cross-tenant access' do
    newsletter_b = nil
    
    ActsAsTenant.with_tenant(website_b) do
      newsletter_b = create(:pwb_newsletter, website: website_b)
    end
    
    ActsAsTenant.with_tenant(website_a) do
      expect { PwbTenant::Newsletter.find(newsletter_b.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

---

## Common Pitfalls

### ❌ DON'T: Use Pwb:: models in controllers without scoping

```ruby
# BAD - Returns ALL pages across ALL tenants!
def index
  @pages = Pwb::Page.all
end
```

### ✅ DO: Use PwbTenant:: models in controllers

```ruby
# GOOD - Automatically scoped to current tenant
def index
  @pages = PwbTenant::Page.all
end
```

---

### ❌ DON'T: Forget tenant context in background jobs

```ruby
# BAD - No tenant context!
class SomeJob < ApplicationJob
  def perform(newsletter_id)
    newsletter = PwbTenant::Newsletter.find(newsletter_id)  # ERROR!
  end
end
```

### ✅ DO: Set tenant context in jobs

```ruby
# GOOD - Tenant context set
class SomeJob < ApplicationJob
  def perform(website_id:, newsletter_id:)
    website = Pwb::Website.find(website_id)
    ActsAsTenant.with_tenant(website) do
      newsletter = PwbTenant::Newsletter.find(newsletter_id)
      # ...
    end
  end
end
```

---

### ❌ DON'T: Use .unscoped in regular controllers

```ruby
# BAD - Bypasses tenant scoping!
class SiteAdmin::PagesController < SiteAdminController
  def index
    @pages = Pwb::Page.unscoped.all  # Shows ALL tenants' pages!
  end
end
```

### ✅ DO: Use PwbTenant:: models

```ruby
# GOOD - Properly scoped
class SiteAdmin::PagesController < SiteAdminController
  def index
    @pages = PwbTenant::Page.all  # Only current tenant's pages
  end
end
```

---

## Debugging Tenant Issues

### Check Current Tenant

```ruby
# In controller or console
puts "Current tenant: #{ActsAsTenant.current_tenant&.subdomain}"
puts "Pwb::Current.website: #{Pwb::Current.website&.subdomain}"
```

### Verify Model Scoping

```ruby
# Check if model is tenant-scoped
PwbTenant::Page.acts_as_tenant?  # => true
Pwb::Page.acts_as_tenant?        # => false

# Check current tenant
ActsAsTenant.current_tenant  # => #<Pwb::Website id: 1, subdomain: "demo">
```

### Test Cross-Tenant Isolation

```ruby
website_a = Pwb::Website.find_by(subdomain: 'tenant-a')
website_b = Pwb::Website.find_by(subdomain: 'tenant-b')

# Create data for tenant A
ActsAsTenant.with_tenant(website_a) do
  page_a = PwbTenant::Page.create!(slug: 'test', visible: true)
  puts "Created page: #{page_a.id}"
end

# Try to access from tenant B
ActsAsTenant.with_tenant(website_b) do
  begin
    PwbTenant::Page.find(page_a.id)
    puts "ERROR: Cross-tenant access succeeded!"
  rescue ActiveRecord::RecordNotFound
    puts "GOOD: Cross-tenant access blocked"
  end
end
```

---

## Testing Checklist

When adding new tenant-scoped features, always test:

- [ ] Data is scoped to current tenant
- [ ] Cross-tenant access is denied
- [ ] Counts don't leak across tenants
- [ ] Updates/deletes only affect current tenant
- [ ] Background jobs preserve tenant context
- [ ] API endpoints validate tenant

**Example Test Template:**

```ruby
RSpec.describe 'Feature', type: :request do
  let(:website_a) { create(:pwb_website, subdomain: 'tenant-a') }
  let(:website_b) { create(:pwb_website, subdomain: 'tenant-b') }
  
  before do
    # Create data for both tenants
    ActsAsTenant.with_tenant(website_a) { create(:resource, website: website_a) }
    ActsAsTenant.with_tenant(website_b) { create(:resource, website: website_b) }
  end
  
  it 'only shows current tenant data' do
    get resources_path, headers: { 'HTTP_HOST' => 'tenant-a.test' }
    # Verify only tenant A data is shown
  end
  
  it 'denies cross-tenant access' do
    resource_b = Pwb::Resource.find_by(website: website_b)
    get resource_path(resource_b), headers: { 'HTTP_HOST' => 'tenant-a.test' }
    expect(response).to have_http_status(:not_found)
  end
end
```

---

## API Development

### Api::BaseController Tenant Resolution

The `Api::BaseController` automatically resolves tenant from requests:

```ruby
class Api::V1::PropertiesController < Api::BaseController
  # Tenant is automatically set from X-Website-Slug header or subdomain

  # Override to require tenant (returns 400 if missing)
  def require_tenant?
    true
  end

  def index
    # current_website is available
    @properties = PwbTenant::ListedProperty.active
    success_response(properties: @properties)
  end
end
```

### Making API Requests

```bash
# Preferred: Use X-Website-Slug header
curl -H "X-Website-Slug: demo" \
     -H "Content-Type: application/json" \
     https://api.example.com/v1/properties

# Alternative: Use subdomain
curl https://demo.example.com/api/v1/properties
```

### Requiring Tenant in API Controllers

Override `require_tenant?` to enforce tenant presence:

```ruby
class Api::V1::SecureController < Api::BaseController
  def require_tenant?
    true  # Returns 400 Bad Request if no tenant found
  end
end
```

---

## Additional Resources

- **Security Audit:** `docs/multi_tenancy/MULTI_TENANCY_SECURITY_AUDIT.md`
- **TenantAwareJob Concern:** `app/jobs/concerns/tenant_aware_job.rb`
- **SubdomainTenant Concern:** `app/controllers/concerns/subdomain_tenant.rb`
- **Api::BaseController:** `app/controllers/api/base_controller.rb`
- **ActsAsTenant Gem:** https://github.com/ErwinM/acts_as_tenant
- **Test Examples:** `spec/requests/site_admin/multi_tenant_isolation_spec.rb`
- **Model Examples:** `spec/models/pwb_tenant/tenant_scoping_spec.rb`

---

**Questions?** Check the audit document or ask in #development channel.
