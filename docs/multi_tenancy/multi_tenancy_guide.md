# Multi-Tenancy Development Guide

## Quick Start

### For Public-Facing Controllers

Inherit from `Pwb::ApplicationController`:

```ruby
module Pwb
  class PropsController < ApplicationController
    # Automatically sets current_website from subdomain
    # current_website is available in all actions
    
    def show
      # Automatic subdomain scoping - only returns props for this website
      @prop = Pwb::Prop.where(website_id: current_website.id).find(params[:id])
    end
  end
end
```

### For Single-Tenant Admin Controllers

Inherit from `SiteAdminController`:

```ruby
module SiteAdmin
  class PropsController < SiteAdminController
    # Automatically:
    # 1. Resolves current_website from subdomain
    # 2. Sets ActsAsTenant.current_tenant
    # 3. Requires admin authentication
    
    def index
      # PwbTenant models auto-scoped to current website
      @props = PwbTenant::Prop.all  # No WHERE needed!
    end
    
    def show
      # Still auto-scoped
      @prop = PwbTenant::Prop.find(params[:id])
    end
  end
end
```

### For Cross-Tenant Admin Controllers

Inherit from `TenantAdminController`:

```ruby
class TenantAdminController < ActionController::Base
  # Include concerns for cross-tenant access
  
  def websites
    # Access all websites
    @websites = Pwb::Website.all
  end
  
  def website_contacts
    # Get contacts from any website
    website = Pwb::Website.find(params[:website_id])
    
    # Option 1: Manual scoping
    @contacts = Pwb::Contact.where(website_id: website.id)
    
    # Option 2: Set tenant context temporarily
    ActsAsTenant.with_tenant(website) do
      @contacts = PwbTenant::Contact.all
    end
  end
end
```

## Model Patterns

### Pattern 1: Pwb:: Models (Non-Scoped)

Use when you need global/cross-tenant access:

```ruby
# app/models/pwb/website.rb
module Pwb
  class Website < ApplicationRecord
    # No acts_as_tenant - can be queried globally
    # Tenant identifier itself
    
    self.table_name_prefix = "pwb_"
    
    has_many :contacts, class_name: 'Pwb::Contact'
  end
end

# app/models/pwb/contact.rb
module Pwb
  class Contact < ApplicationRecord
    # Manually scoped, not auto-scoped
    belongs_to :website
    
    scope :for_website, ->(website) { where(website_id: website.id) }
  end
end

# Usage:
Website.all                           # All websites
Contact.where(website_id: 1).all      # Manual scoping needed
```

### Pattern 2: PwbTenant:: Models (Auto-Scoped)

Use for most tenant data:

```ruby
# app/models/pwb_tenant/contact.rb
module PwbTenant
  class Contact < ApplicationRecord
    # Inherits acts_as_tenant from PwbTenant::ApplicationRecord
    # Automatically scoped to current website
    
    validates :email, presence: true
  end
end

# Usage in SiteAdminController:
PwbTenant::Contact.all             # Already filtered to current website!
PwbTenant::Contact.find(params[:id]) # Auto-scoped
```

### Pattern 3: Dual Model Pattern (Legacy Support)

For models with both scoped and unscoped versions:

```ruby
# app/models/pwb/prop.rb - Global access
module Pwb
  class Prop < ApplicationRecord
    self.table_name = 'pwb_props'
    # Can be queried globally with manual scoping
  end
end

# app/models/pwb_tenant/prop.rb - Tenant-scoped
module PwbTenant
  class Prop < ApplicationRecord
    # Same table as Pwb::Prop
    # Auto-scoped to current website
    # Inherits acts_as_tenant
  end
end
```

## Routing Patterns

### Subdomain-Based Routing

```ruby
# config/routes.rb

# Public routes automatically scoped to subdomain via Pwb::ApplicationController
scope module: :pwb do
  get '/properties', to: 'props#index'      # myagency.example.com/properties
  get '/pages/:slug', to: 'pages#show'      # site1.example.com/pages/about
end

# Site admin routes - single website
namespace :site_admin do
  resources :props
  resources :contacts
end
# Accessed via: myagency.example.com/site_admin/props

# Tenant admin routes - cross-tenant
namespace :tenant_admin do
  resources :websites
  resources :contacts
end
# Accessed via: admin.example.com/tenant_admin/websites
```

### API Routing with Header Support

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :properties
  end
end

# Client usage 1: Subdomain-based
GET https://myagency.example.com/api/v1/properties
# => Routed through SubdomainTenant concern

# Client usage 2: Header-based (for API clients)
GET https://api.example.com/api/v1/properties
  X-Website-Slug: myagency
# => Routed through SubdomainTenant concern using header
```

## Query Examples

### Getting Current Website Data

```ruby
# In SiteAdminController action:
def contacts_index
  # Method 1: Auto-scoped model (recommended)
  @contacts = PwbTenant::Contact.all
  # SQL: SELECT * FROM pwb_contacts WHERE website_id = 1
  
  # Method 2: Access current_website directly
  @contacts = current_website.contacts
  # Through has_many association on Website model
  
  # Method 3: Manual scoping (if using Pwb:: model)
  @contacts = Pwb::Contact.where(website_id: current_website.id)
end
```

### Cross-Tenant Queries

```ruby
# In TenantAdminController:
def all_contacts
  # Direct access - not auto-scoped
  @all_contacts = Pwb::Contact.all
  
  # Or explicitly bypass tenant scoping
  @all_contacts = ActsAsTenant.without_tenant do
    PwbTenant::Contact.all
  end
end

def website_specific
  website = Pwb::Website.find(params[:website_id])
  
  # Temporarily set tenant context
  @contacts = ActsAsTenant.with_tenant(website) do
    PwbTenant::Contact.all
  end
  
  # Or manual scoping
  @contacts = Pwb::Contact.where(website_id: website.id)
end
```

### Filtered Queries with Tenant Scoping

```ruby
# In SiteAdminController:
def expensive_properties
  # Auto-scoped to current website
  @properties = PwbTenant::Property.where('price_cents > ?', 1000000)
  # SQL: SELECT * FROM pwb_properties 
  #      WHERE website_id = 1 AND price_cents > 1000000
end

def search_contacts
  query = params[:query]
  # Auto-scoped AND filtered
  @contacts = PwbTenant::Contact.where('email ILIKE ?', "%#{query}%")
  # SQL: SELECT * FROM pwb_contacts 
  #      WHERE website_id = 1 AND email ILIKE '%query%'
end
```

## Controller Best Practices

### Best Practice 1: Single-Tenant Admin Controller

```ruby
# Good: Proper inheritance and concerns
module SiteAdmin
  class PropsController < SiteAdminController
    before_action :set_prop, only: [:show, :edit, :update, :destroy]
    
    def index
      # Auto-scoped to current_website
      @props = PwbTenant::Prop.all
    end
    
    def show
      # @prop already set by before_action
      # and auto-scoped to current website
    end
    
    def create
      # New records auto-assigned to current_website
      # if model includes: before_create -> { self.website = Pwb::Current.website }
      @prop = PwbTenant::Prop.new(prop_params)
      @prop.save
    end
    
    private
    
    def set_prop
      @prop = PwbTenant::Prop.find(params[:id])
    end
    
    def prop_params
      params.require(:prop).permit(:title, :price)
    end
  end
end
```

### Best Practice 2: Cross-Tenant Admin with Explicit Scoping

```ruby
# Good: Clear cross-tenant access with explicit scoping
class TenantAdminController < ActionController::Base
  before_action :set_website, only: [:show_website_contacts]
  
  def websites
    @websites = Pwb::Website.all
  end
  
  def show_website_contacts
    # Explicit: set tenant context for queries
    @contacts = ActsAsTenant.with_tenant(@website) do
      PwbTenant::Contact.all
    end
  end
  
  private
  
  def set_website
    @website = Pwb::Website.find(params[:website_id])
  end
end
```

### Best Practice 3: API Controller with Tenant Resolution

```ruby
# Good: Explicit tenant context for API
module Api
  module V1
    class PropertiesController < ApplicationController
      include SubdomainTenant  # Resolves website from subdomain/header
      
      before_action :set_tenant_context
      
      def index
        @properties = PwbTenant::Property.limit(50)
        render json: @properties
      end
      
      private
      
      def set_tenant_context
        ActsAsTenant.current_tenant = current_website
      end
    end
  end
end
```

## Avoiding Common Pitfalls

### Pitfall 1: Missing Tenant Context

```ruby
# WRONG: Forgot to set tenant context
class ContactsController < SiteAdminController
  def index
    # Error if not using auto-scoped model!
    @contacts = PwbTenant::Contact.all
    # might return contacts from wrong website
  end
end

# RIGHT: Either use include in controller or ensure set_tenant_from_subdomain is called
class ContactsController < SiteAdminController
  # SiteAdminController already sets tenant in before_action
  # So this just works:
  def index
    @contacts = PwbTenant::Contact.all
  end
end
```

### Pitfall 2: Manual Scoping Bypassed

```ruby
# WRONG: Forgot website_id condition
def index
  @contacts = Pwb::Contact.all  # Returns ALL contacts!
end

# RIGHT: Always scope manually if using Pwb:: models
def index
  @contacts = Pwb::Contact.where(website_id: current_website.id)
end
```

### Pitfall 3: Cross-Tenant Query in Single-Tenant Context

```ruby
# WRONG: Trying to access cross-tenant data from single-tenant controller
module SiteAdmin
  class DataExportController < SiteAdminController
    def export
      # ERROR: These come from different websites!
      all_contacts = Pwb::Contact.all
      this_website = current_website
      
      # This is a security issue - accidental data leak
      export_csv(all_contacts)
    end
  end
end

# RIGHT: Only access current_website data
module SiteAdmin
  class DataExportController < SiteAdminController
    def export
      contacts = PwbTenant::Contact.all  # Auto-scoped
      export_csv(contacts)
    end
  end
end
```

### Pitfall 4: Missing Website Assignment

```ruby
# WRONG: New record not assigned to website
module SiteAdmin
  class ContactsController < SiteAdminController
    def create
      @contact = PwbTenant::Contact.new(contact_params)
      @contact.save  # Fails because website_id is nil!
    end
  end
end

# RIGHT: Assign website to new record
module SiteAdmin
  class ContactsController < SiteAdminController
    def create
      @contact = PwbTenant::Contact.new(contact_params)
      @contact.website = current_website  # or automatic via before_create
      @contact.save
    end
  end
end

# EVEN BETTER: Auto-assign in model
module PwbTenant
  class Contact < ApplicationRecord
    before_create :assign_website
    
    private
    
    def assign_website
      self.website ||= Pwb::Current.website
    end
  end
end
```

## Testing Multi-Tenancy

### Test Setup

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.before(:each) do |example|
    # Reset Current attributes
    Pwb::Current.website = nil
    
    # Reset acts_as_tenant context
    ActsAsTenant.current_tenant = nil
  end
end
```

### Single-Tenant Controller Test

```ruby
describe SiteAdmin::PropsController do
  let(:website) { create(:pwb_website, subdomain: 'myagency') }
  let!(:prop) { create(:pwb_prop, website: website) }
  let(:other_website) { create(:pwb_website, subdomain: 'other') }
  let!(:other_prop) { create(:pwb_prop, website: other_website) }
  
  it 'shows only props for this website' do
    get :index, params: { host: 'myagency.example.com' }
    
    expect(assigns(:props)).to include(prop)
    expect(assigns(:props)).not_to include(other_prop)
  end
end
```

### Cross-Tenant Controller Test

```ruby
describe TenantAdminController do
  let(:website1) { create(:pwb_website) }
  let(:website2) { create(:pwb_website) }
  let!(:contact1) { create(:pwb_contact, website: website1) }
  let!(:contact2) { create(:pwb_contact, website: website2) }
  
  it 'shows contacts from all websites' do
    get :all_contacts
    
    expect(assigns(:all_contacts)).to include(contact1)
    expect(assigns(:all_contacts)).to include(contact2)
  end
end
```

### Model Test with Tenant Context

```ruby
describe PwbTenant::Contact do
  let(:website) { create(:pwb_website) }
  
  context 'with tenant context set' do
    before do
      ActsAsTenant.current_tenant = website
    end
    
    it 'only returns contacts for that website' do
      contact_in_tenant = create(:pwb_contact, website: website)
      contact_in_other = create(:pwb_contact, website: create(:pwb_website))
      
      expect(PwbTenant::Contact.all).to include(contact_in_tenant)
      expect(PwbTenant::Contact.all).not_to include(contact_in_other)
    end
  end
  
  context 'without tenant context' do
    it 'raises error (or uses without_tenant)' do
      ActsAsTenant.without_tenant do
        expect(PwbTenant::Contact.all).to include(all_contacts)
      end
    end
  end
end
```

## Debugging Multi-Tenancy Issues

### Check Current Website Context

```ruby
# In console or controller
puts "Current website: #{Pwb::Current.website&.id}"
puts "Current subdomain: #{request.subdomain}"
puts "Acts as tenant: #{ActsAsTenant.current_tenant&.id}"
```

### Verify Query Scoping

```ruby
# Check what SQL is generated
PwbTenant::Contact.all.to_sql
# => SELECT "pwb_contacts".* FROM "pwb_contacts" WHERE "pwb_contacts"."website_id" = 1

Pwb::Contact.all.to_sql
# => SELECT "pwb_contacts".* FROM "pwb_contacts"
# (no WHERE - not scoped)
```

### Test Subdomain Resolution

```ruby
# In test:
get :index, params: { host: 'myagency.example.com' }

# In controller:
puts "Subdomain: #{request.subdomain}"
puts "Extracted: #{request_subdomain}"
puts "Current website: #{current_website&.subdomain}"
```

### Check Model Inheritance

```ruby
# Verify model has acts_as_tenant
PwbTenant::Contact.ancestors
# => Should show acts_as_tenant middleware

Pwb::Contact.ancestors
# => Should NOT show acts_as_tenant middleware
```

## Summary Table

| Feature | Pwb:: | PwbTenant:: |
|---------|-------|-----------|
| Auto-scoped | No | Yes |
| Cross-tenant access | Natural | Requires `without_tenant` |
| Use case | Super-admin, Website itself | Most tenant data |
| Table prefix | pwb_ | pwb_ |
| Manual scoping | Required | Not needed |
| Best for | Pwb::Website, Pwb::User | Most models |

| Controller | Includes SubdomainTenant | Tenant Scoping | Authorization |
|-----------|-------------------------|----------------|---------------|
| Pwb::* | Implicit (in parent) | Single website | Public |
| SiteAdmin | Yes | Single website | Admin for website |
| TenantAdmin | No | Cross-tenant | Env-based email list |
