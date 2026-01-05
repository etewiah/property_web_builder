# PropertyWebBuilder: Architecture Patterns & Best Practices

A deep dive into the architectural patterns used throughout PropertyWebBuilder, with examples and guidance for maintaining consistency.

## Table of Contents

1. [Multi-Tenancy Pattern](#multi-tenancy-pattern)
2. [Model Architecture](#model-architecture)
3. [Controller Patterns](#controller-patterns)
4. [View & Theme System](#view--theme-system)
5. [Background Job Patterns](#background-job-patterns)
6. [Testing Patterns](#testing-patterns)
7. [API Design](#api-design)

---

## Multi-Tenancy Pattern

### Overview

PropertyWebBuilder uses the **acts-as-tenant gem** to provide automatic query scoping and tenant isolation. This is the single most important architectural pattern in the application.

### How It Works

```ruby
# In models/pwb_tenant/property.rb
class PwbTenant::Property < Pwb::Property
  acts_as_tenant :website, class_name: 'Pwb::Website'
end

# In controllers/site_admin_controller.rb
before_action :set_tenant_from_subdomain

def set_tenant_from_subdomain
  ActsAsTenant.current_tenant = current_website
end

# Result: All PwbTenant::Property queries are automatically scoped
PwbTenant::Property.all  # Automatically: WHERE website_id = current_website.id
```

### Model Tier System

```
Pwb::*              Non-scoped models (for cross-tenant operations)
  ↓ (used by)
PwbTenant::*        Tenant-scoped models (auto-scoped via acts_as_tenant)
```

**Examples:**

| Non-Scoped | Tenant-Scoped | Purpose |
|-----------|--------------|---------|
| `Pwb::User` | `PwbTenant::User` | Users belong to multiple websites |
| `Pwb::RealtyAsset` | `PwbTenant::RealtyAsset` | Properties belong to one website |
| `Pwb::Subscription` | N/A | Subscriptions don't need scoping |
| `Pwb::Website` | N/A | Websites are the tenant |

### When to Use Each Tier

**Use `Pwb::*` (Non-Scoped) When:**
- Processing cross-tenant operations (admin scripts)
- Console work and debugging
- Background jobs that process all tenants
- Platform-wide queries in tenant_admin

**Use `PwbTenant::*` (Scoped) When:**
- In site_admin controllers
- In views rendered to website admins
- In website-specific background jobs
- Testing website isolation

### Important: Scoping Verification

```ruby
# WRONG - In site_admin context, this breaks isolation
Pwb::Property.all  # Returns ALL properties across all tenants!

# CORRECT - Auto-scoped to current_website
PwbTenant::Property.all  # WHERE website_id = current_website.id

# ALSO CORRECT - In non-scoped context, explicitly scope
Pwb::Property.where(website_id: website_id)
```

### Tenant Awareness in Background Jobs

```ruby
# app/jobs/concerns/tenant_aware_job.rb
module TenantAwareJob
  extend ActiveSupport::Concern
  
  included do
    before_perform do |job|
      # Automatically set tenant for the job
      ActsAsTenant.current_tenant = job.arguments.find { |arg| arg.is_a?(Website) }
    end
  end
end

# Usage
class RefreshPropertiesViewJob < ApplicationJob
  include TenantAwareJob
  
  def perform(website)
    # Queries automatically scoped to website
    PwbTenant::Property.refresh
  end
end
```

---

## Model Architecture

### Model Tier System Explained

PropertyWebBuilder uses a sophisticated model tier system to handle both normalized writes and denormalized reads:

```
Physical Data Layer          Transaction Data Layer         Read Layer (Query)
────────────────────        ──────────────────────         ─────────────────

pwb_realty_assets      →    pwb_sale_listings       →     pwb_properties
(normalized core data)      (sale-specific data)           (materialized view)
                                                            
                            pwb_rental_listings     →     [optimized for search]
                            (rental-specific data)
```

### RealtyAsset Pattern

**Purpose:** Single source of truth for physical property data

```ruby
class Pwb::RealtyAsset < ApplicationRecord
  # Physical property attributes
  # street_address, city, postal_code, country
  # count_bedrooms, count_bathrooms, count_garages
  # constructed_area, plot_area, latitude, longitude
  
  has_many :sale_listings, dependent: :destroy
  has_many :rental_listings, dependent: :destroy
  has_many :prop_photos, dependent: :destroy
  
  # Validation: Can't exceed website's subscription property limit
  validate :within_subscription_property_limit, on: :create
  
  # Callback: Generate URL-friendly slug
  before_validation :generate_slug, on: :create
  before_validation :ensure_slug_uniqueness
end
```

### Sale/Rental Listing Pattern

**Purpose:** Separate transaction-specific data from physical property data

```ruby
class Pwb::SaleListing < ApplicationRecord
  belongs_to :realty_asset
  
  # Sale-specific attributes
  # price_cents, currency, commission_cents
  # is_active, is_archived, highlighted
  # availability_date, closing_date
  
  enum status: { draft: 0, active: 1, archived: 2, sold: 3 }
end

class Pwb::RentalListing < ApplicationRecord
  belongs_to :realty_asset
  
  # Rental-specific attributes
  # price_monthly_cents, price_weekly_cents, price_nightly_cents
  # furnished, available_from, minimum_stay_days
  # for_long_term, for_short_term
  
  enum status: { available: 0, booked: 1, unavailable: 2 }
end
```

### MaterializedView Pattern

**Purpose:** Denormalized, read-optimized view combining all property data

```ruby
class Pwb::ListedProperty < ApplicationRecord
  self.table_name = 'pwb_properties'  # Materialized view table
  
  # Read-only model (no saves)
  def readonly?
    true
  end
  
  # Refresh materialized view after changes
  def self.refresh
    execute_sql "REFRESH MATERIALIZED VIEW CONCURRENTLY pwb_properties"
  end
end
```

**When to Use:**
- Searching properties (filter, sort, paginate)
- Displaying property lists
- Generating reports

**When NOT to Use:**
- Updating property data (use RealtyAsset, SaleListing, RentalListing)
- Writing transaction data (use SaleListing, RentalListing)

### Model Validation Pattern

```ruby
class Pwb::Property < ApplicationRecord
  # Presence validations
  validates :street_address, :city, :country, presence: true
  validates :slug, presence: true, uniqueness: true
  
  # Inclusion validations
  validates :prop_type_key, presence: true, 
    inclusion: { in: PROPERTY_TYPES, message: "%{value} is not valid" }
  
  # Subscription limit validation
  validate :within_subscription_property_limit, on: :create
  
  # Conditional validations
  validates :price_cents, presence: true, 
    if: -> { for_sale? }
  validates :price_monthly_cents, presence: true, 
    if: -> { for_rent? }
  
  def within_subscription_property_limit
    return unless website
    
    limit = website.subscription&.plan&.property_limit
    return unless limit
    
    if website.realty_assets.count >= limit
      errors.add(:base, "You've reached your property limit")
    end
  end
end
```

---

## Controller Patterns

### Base Controller Pattern

```ruby
# SiteAdminController - handles per-tenant admin
class SiteAdminController < ActionController::Base
  include ::Devise::Controllers::Helpers
  include SubdomainTenant          # Sets current_website from subdomain
  include AdminAuthBypass          # Dev-only bypass
  include DevSubscriptionBypass    # Dev-only plan override
  include Pagy::Method             # Pagination
  
  before_action :set_tenant_from_subdomain
  before_action :require_admin!, unless: :bypass_admin_auth?
  before_action :check_subscription_access
  
  layout 'site_admin'
  
  def current_website
    Pwb::Current.website
  end
  helper_method :current_website
  
  private
  
  def set_tenant_from_subdomain
    ActsAsTenant.current_tenant = current_website
  end
  
  def require_admin!
    unless current_user && user_is_admin_for_subdomain?
      render 'pwb/errors/admin_required', status: :forbidden
    end
  end
end
```

### Nested Resource Pattern

```ruby
# routes.rb
resources :props, only: %i[index show new create] do
  member do
    get 'edit/general', to: 'props#edit_general'
    get 'edit/text', to: 'props#edit_text'
    get 'edit/photos', to: 'props#edit_photos'
  end
  
  # Nested sale listings
  resources :sale_listings, controller: 'props/sale_listings' do
    member do
      patch :activate
      patch :archive
    end
  end
  
  # Nested rental listings
  resources :rental_listings, controller: 'props/rental_listings' do
    member do
      patch :activate
      patch :archive
    end
  end
end

# app/controllers/site_admin/props/sale_listings_controller.rb
class SiteAdmin::Props::SaleListingsController < SiteAdminController
  before_action :set_realty_asset
  
  def create
    @sale_listing = @realty_asset.sale_listings.build(sale_listing_params)
    if @sale_listing.save
      redirect_to @realty_asset, notice: 'Sale listing created'
    else
      render :new
    end
  end
  
  private
  
  def set_realty_asset
    @realty_asset = PwbTenant::RealtyAsset.find(params[:prop_id])
  end
  
  def sale_listing_params
    params.require(:sale_listing).permit(:price_cents, :currency, :status)
  end
end
```

### Index with Pagination Pattern

```ruby
# site_admin/props_controller.rb
def index
  query = PwbTenant::Property.all
  query = query.by_type(params[:type]) if params[:type]
  query = query.by_status(params[:status]) if params[:status]
  
  @pagy, @properties = pagy(query, items: 50)
end

# view: site_admin/props/index.html.erb
<%= render 'pagy/nav', pagy: @pagy %>
```

### Form Pattern (Strong Parameters)

```ruby
class SiteAdmin::PropsController < SiteAdminController
  def update
    @property = PwbTenant::RealtyAsset.find(params[:id])
    
    if @property.update(property_params)
      redirect_to @property, notice: 'Property updated'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def property_params
    params.require(:realty_asset).permit(
      :street_address, :city, :country, :postal_code,
      :count_bedrooms, :count_bathrooms, :constructed_area,
      sale_listings_attributes: [:id, :price_cents, :currency, :_destroy],
      rental_listings_attributes: [:id, :price_monthly_cents, :currency, :_destroy]
    )
  end
end
```

### Respond Format Pattern

```ruby
class Api::V1::PropertiesController < ApplicationApiController
  def index
    @properties = PwbTenant::Property.all
    
    respond_to do |format|
      format.json { render json: @properties }
      format.xml { render xml: @properties }
      format.csv { render_csv @properties }
    end
  end
  
  def render_csv(properties)
    csv_data = PropertyCsvExporter.new(properties).export
    send_data csv_data, filename: 'properties.csv', type: 'text/csv'
  end
end
```

---

## View & Theme System

### View Directory Structure

```
app/views/
  ├── site_admin/          # Per-tenant admin dashboard
  │   ├── props/           # Property management
  │   ├── pages/           # Page management
  │   ├── users/           # User management
  │   └── analytics/       # Analytics dashboard
  │
  ├── tenant_admin/        # Cross-tenant admin
  │   ├── websites/        # Tenant management
  │   ├── subscriptions/   # Billing management
  │   └── support_tickets/ # Platform support
  │
  ├── pwb/                 # Public-facing pages
  │   ├── welcome/
  │   ├── search/
  │   └── props/           # Property detail pages
  │
  └── layouts/             # Layout templates
```

### Theme Architecture Pattern

```
app/themes/
  ├── barcelona/
  │   ├── views/
  │   │   └── pwb/
  │   │       ├── welcome/     # Landing page
  │   │       ├── search/      # Search results
  │   │       ├── props/       # Property detail
  │   │       └── sections/    # Reusable components
  │   │
  │   └── palettes/            # Color palettes
  │       ├── primary.css
  │       ├── dark.css
  │       └── custom.css
  │
  └── config.json              # Theme registry and metadata
```

### Theme Selection & Override Pattern

```ruby
# Website model
class Pwb::Website < ApplicationRecord
  # Theme name (e.g., 'barcelona')
  attribute :theme_name
  
  # Palette (e.g., 'primary', 'dark')
  attribute :selected_palette
  
  # Compiled CSS with color palette applied
  attribute :compiled_palette_css
  
  # Custom CSS for additional styling
  attribute :raw_css
end

# View lookup order (Rails convention)
# 1. app/themes/barcelona/views/pwb/props/show.html.erb
# 2. app/views/pwb/props/show.html.erb
# 3. Not found → error

# Theme CSS inclusion
<link rel="stylesheet" href="<%= custom_css_path(website.theme_name) %>">
<style><%= website.compiled_palette_css %></style>
<style><%= website.raw_css %></style>
```

### Liquid Template Pattern (Page Parts)

```erb
<!-- Theme template with Liquid injection points -->
<div class="page-header">
  <h1><%= @page.title %></h1>
  <div class="description">
    <%= render_liquid(@page.description) %>
  </div>
</div>

<div class="page-parts">
  <% @page.page_parts.each do |part| %>
    <div class="page-part <%= part.key %>">
      <!-- Render Liquid template from page_part content -->
      <%= render_liquid(part.content) %>
    </div>
  <% end %>
</div>
```

### Responsive Theme Pattern

```scss
// Theme CSS with Tailwind breakpoints
.property-grid {
  @apply grid grid-cols-1 gap-4;
  
  @apply md:grid-cols-2;
  @apply lg:grid-cols-3;
  @apply xl:grid-cols-4;
}

.property-card {
  @apply rounded-lg shadow-md overflow-hidden;
  @apply transition-all duration-300;
  
  &:hover {
    @apply shadow-lg transform scale-105;
  }
}

@media (max-width: 768px) {
  .sidebar {
    display: none;
  }
}
```

---

## Background Job Patterns

### Job Naming & Organization Pattern

```
app/jobs/
  ├── application_job.rb                    # Base class
  ├── concerns/
  │   └── tenant_aware_job.rb              # Tenant scoping
  │
  ├── subscription_lifecycle_job.rb         # Top-level (global)
  ├── refresh_properties_view_job.rb        # Top-level
  │
  └── pwb/
      ├── search_alert_job.rb              # Tenant-aware
      ├── batch_url_import_job.rb          # Tenant-aware
      └── download_scraped_images_job.rb   # Tenant-aware
```

### Tenant-Aware Job Pattern

```ruby
class Pwb::BatchUrlImportJob < ApplicationJob
  include TenantAwareJob
  
  def perform(website, urls)
    # website parameter makes this job tenant-aware
    # TenantAwareJob sets ActsAsTenant.current_tenant = website
    
    urls.each do |url|
      # All PwbTenant:: queries automatically scoped to website
      PwbTenant::ScrapedProperty.create_from_url(url)
    end
  end
end

# Enqueue with website parameter
Pwb::BatchUrlImportJob.perform_later(website, urls)
```

### Scheduled Job Pattern

```ruby
# config/solid_queue.yml
schedules:
  refresh_exchange_rates:
    class: Pwb::UpdateExchangeRatesJob
    cron: '0 */4 * * *'  # Every 4 hours
  
  monitor_sla_breaches:
    class: SlaMonitoringJob
    cron: '*/5 * * * *'  # Every 5 minutes
  
  cleanup_orphaned_files:
    class: CleanupOrphanedBlobsJob
    cron: '0 2 * * 0'    # Weekly Sunday 2am

# app/jobs/sla_monitoring_job.rb
class SlaMonitoringJob < ApplicationJob
  def perform
    Pwb::SupportTicket.check_sla_breaches
  end
end
```

### Error Handling in Jobs

```ruby
class Pwb::SearchAlertJob < ApplicationJob
  include TenantAwareJob
  
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
  
  def perform(website, user)
    # Automatic retry on error (max 3 attempts)
    send_search_alert(user)
  rescue StandardError => e
    Rails.logger.error("Search alert failed: #{e.message}")
    raise  # Triggers retry
  end
end
```

---

## Testing Patterns

### Model Spec Pattern

```ruby
# spec/models/pwb/realty_asset_spec.rb
describe Pwb::RealtyAsset do
  describe 'validations' do
    it { should validate_presence_of(:street_address) }
    it { should validate_uniqueness_of(:slug) }
  end
  
  describe 'associations' do
    it { should have_many(:sale_listings).dependent(:destroy) }
    it { should have_many(:rental_listings).dependent(:destroy) }
  end
  
  describe '#within_subscription_property_limit' do
    context 'when under limit' do
      it 'allows creation' do
        website = create(:website, property_limit: 10)
        property = build(:realty_asset, website: website)
        expect(property).to be_valid
      end
    end
    
    context 'when at limit' do
      it 'rejects creation' do
        website = create(:website, property_limit: 0)
        property = build(:realty_asset, website: website)
        expect(property).not_to be_valid
        expect(property.errors[:base]).to include("You've reached your property limit")
      end
    end
  end
end
```

### Request Spec Pattern

```ruby
# spec/requests/site_admin/props_spec.rb
describe 'SiteAdmin::PropsController' do
  let(:user) { create(:user, :admin) }
  let(:website) { create(:website, owner: user) }
  
  before do
    sign_in user
    host! "#{website.subdomain}.localhost"
  end
  
  describe 'POST /site_admin/props' do
    it 'creates a new property' do
      expect {
        post site_admin_props_path, params: {
          realty_asset: attributes_for(:realty_asset)
        }
      }.to change { PwbTenant::RealtyAsset.count }.by(1)
      
      expect(response).to redirect_to(site_admin_prop_path(RealtyAsset.last))
    end
    
    it 'returns error on invalid params' do
      post site_admin_props_path, params: {
        realty_asset: { city: 'Barcelona' }  # Missing required fields
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
  
  describe 'Multi-tenancy isolation' do
    let(:other_website) { create(:website) }
    
    it 'does not show properties from other websites' do
      create(:realty_asset, website: other_website)
      
      get site_admin_props_path
      expect(response.body).not_to include(other_website.name)
    end
  end
end
```

### Factory Pattern

```ruby
# spec/factories/realty_assets.rb
FactoryBot.define do
  factory :realty_asset, class: 'Pwb::RealtyAsset' do
    website
    
    street_address { Faker::Address.street_address }
    city { Faker::Address.city }
    country { 'Spain' }
    postal_code { Faker::Address.postcode }
    
    count_bedrooms { rand(1..5) }
    count_bathrooms { rand(1..3) }
    constructed_area { rand(100..300) }
    
    trait :with_sale_listing do
      after(:create) do |asset|
        create(:sale_listing, realty_asset: asset)
      end
    end
    
    trait :with_rental_listing do
      after(:create) do |asset|
        create(:rental_listing, realty_asset: asset)
      end
    end
  end
end

# Usage in specs
create(:realty_asset)                                # Minimal
create(:realty_asset, :with_sale_listing)           # With sale
create(:realty_asset, :with_rental_listing)         # With rental
create_list(:realty_asset, 5, website: website)     # Multiple
```

---

## API Design

### RESTful Endpoint Pattern

```
GET    /api_public/v1/properties              # List
GET    /api_public/v1/properties/:id           # Show
POST   /api/v1/properties                      # Create (internal only)
PUT    /api/v1/properties/:id                  # Update (internal only)
DELETE /api/v1/properties/:id                  # Destroy (internal only)
```

### Response Format Pattern

```ruby
# app/controllers/api_public/v1/properties_controller.rb
class ApiPublic::V1::PropertiesController < ApplicationApiController
  def index
    @properties = ListPropertyQuery.new(search_params).results
    
    render json: {
      data: @properties.map { |p| property_serializer.new(p) },
      meta: {
        total: @properties.count,
        page: search_params[:page],
        per_page: search_params[:per_page]
      }
    }
  end
  
  def show
    @property = PwbTenant::ListedProperty.find(params[:id])
    render json: property_serializer.new(@property)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Property not found' }, status: :not_found
  end
  
  private
  
  def property_serializer
    @property_serializer ||= PropertySerializer
  end
end
```

### Serializer Pattern

```ruby
# app/serializers/property_serializer.rb
class PropertySerializer
  def initialize(property)
    @property = property
  end
  
  def as_json(*args)
    {
      id: @property.id,
      title: @property.title,
      address: {
        street: @property.street_address,
        city: @property.city,
        postal_code: @property.postal_code,
        country: @property.country,
        coordinates: {
          latitude: @property.latitude,
          longitude: @property.longitude
        }
      },
      property_type: @property.prop_type_key,
      bedrooms: @property.count_bedrooms,
      bathrooms: @property.count_bathrooms,
      area: @property.constructed_area,
      price: {
        amount: @property.price_cents,
        currency: @property.currency,
        formatted: "#{@property.currency} #{@property.price_cents / 100}"
      },
      for_sale: @property.for_sale,
      for_rent: @property.for_rent,
      photos: @property.photos.map { |p| PhotoSerializer.new(p) }
    }
  end
end
```

### Error Response Pattern

```ruby
# app/controllers/application_api_controller.rb
class ApplicationApiController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  rescue_from StandardError, with: :internal_error
  
  private
  
  def record_not_found(exception)
    render json: {
      error: {
        type: 'not_found',
        message: "#{exception.model} not found",
        status: 404
      }
    }, status: :not_found
  end
  
  def parameter_missing(exception)
    render json: {
      error: {
        type: 'invalid_request',
        message: "Missing required parameter: #{exception.param}",
        status: 422
      }
    }, status: :unprocessable_entity
  end
  
  def internal_error(exception)
    render json: {
      error: {
        type: 'internal_error',
        message: 'An unexpected error occurred',
        status: 500
      }
    }, status: :internal_server_error
  end
end
```

---

## Key Takeaways

1. **Multi-Tenancy:** Always use `PwbTenant::*` models in controllers/views, `Pwb::*` models only for cross-tenant operations
2. **Models:** Separate reads (ListedProperty) from writes (RealtyAsset)
3. **Controllers:** Keep logic lean, delegate to models and services
4. **Views:** Use themes for customization, Liquid for dynamic content
5. **Jobs:** Include `TenantAwareJob` concern for proper scoping
6. **Tests:** Test isolation, authorization, and happy paths
7. **API:** Follow REST conventions, proper error responses

---

*Last Updated: January 4, 2026*
