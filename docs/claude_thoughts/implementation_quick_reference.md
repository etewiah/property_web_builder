# Saved Searches & Email Alerts - Quick Reference

## Feature Status

| Feature | Current State | Ready to Build? |
|---------|---------------|-----------------|
| Saved Searches | ❌ No existing implementation | ✅ Yes |
| Email Alerts | ❌ No existing implementation | ✅ Yes |
| Favorite Properties | ❌ No existing implementation | ✅ Yes (optional) |
| External Feed Search | ✅ Exists | - |
| Email Mailers | ✅ Exists (EnquiryMailer) | ✅ Follow pattern |
| Background Jobs | ✅ Exists (Solid Queue) | ✅ Use TenantAwareJob |
| Multi-Tenancy | ✅ Exists (ActsAsTenant) | ✅ Well documented |

---

## Database Models to Create

### 1. ExternalSearch (SavedSearch)
- Stores search criteria from external feed
- User configurable alert frequency
- Tracks last run and result count
- Links user + website

### 2. SearchAlert (SearchResult)
- Tracks individual search executions
- Stores comparison of new vs. previous results
- Tracks email delivery status
- Stores JSON of found properties

### 3. SavedProperty (Optional)
- Allows users to favorite/bookmark external listings
- Caches property data for quick display
- Optional price change alerts

---

## Email Patterns

### Existing Pattern: EnquiryMailer
```ruby
# Location: /app/mailers/pwb/enquiry_mailer.rb

class EnquiryMailer < Pwb::ApplicationMailer
  after_deliver :mark_delivery_success
  rescue_from StandardError, with: :handle_delivery_error
  
  def general_enquiry_targeting_agency(contact, message)
    # ... mail implementation
  end
end

# Usage:
EnquiryMailer.general_enquiry_targeting_agency(contact, message).deliver_later
```

### New Pattern: SearchAlertMailer
```ruby
# Location: /app/mailers/pwb/search_alert_mailer.rb

class SearchAlertMailer < Pwb::ApplicationMailer
  after_deliver :mark_alert_sent
  rescue_from StandardError, with: :handle_delivery_error
  
  def search_results(user, search, alert)
    @user = user
    @search = search
    @alert = alert
    @website = search.website
    
    mail(to: user.email, subject: "New properties: #{search.name}")
  end
end

# Usage:
SearchAlertMailer.search_results(user, search, alert).deliver_later
```

---

## Background Job Patterns

### Existing Pattern: NtfyNotificationJob
```ruby
# Location: /app/jobs/ntfy_notification_job.rb

class NtfyNotificationJob < ActiveJob::Base
  include TenantAwareJob
  queue_as :notifications
  
  def perform(website_id, notification_type, ...)
    ActsAsTenant.with_tenant(website) do
      # Handle notification
    end
  end
end

# Usage:
NtfyNotificationJob.perform_later(website.id, :listing_change, ...)
```

### New Pattern: SearchAlertJob
```ruby
# Location: /app/jobs/pwb/search_alert_job.rb

class SearchAlertJob < ApplicationJob
  include TenantAwareJob
  queue_as :searches
  
  def perform(website_id, external_search_id)
    with_tenant(website_id) do
      search = PwbTenant::ExternalSearch.find(external_search_id)
      
      # 1. Execute search
      results = execute_search(search)
      
      # 2. Find new properties since last run
      new_properties = find_new_properties(search, results)
      
      # 3. Send email if results exist
      if new_properties.any?
        send_alert_email(search, new_properties)
      end
      
      # 4. Update tracking
      search.update(last_run_at: Time.current, last_result_count: results.size)
    end
  end
end

# Usage:
SearchAlertJob.perform_later(website.id, external_search.id)

# Or in a rake task (run daily/weekly/etc):
PwbTenant::ExternalSearch.active.find_each { |s| 
  SearchAlertJob.perform_later(s.website_id, s.id)
}
```

---

## Multi-Tenancy Setup

### Model Structure

**Both models required:**

```ruby
# app/models/pwb/external_search.rb (Non-tenant-scoped)
class ExternalSearch < ApplicationRecord
  belongs_to :user, class_name: 'Pwb::User'
  belongs_to :website, class_name: 'Pwb::Website'
end

# app/models/pwb_tenant/external_search.rb (Tenant-scoped)
class ExternalSearch < Pwb::ExternalSearch
  include RequiresTenant
  acts_as_tenant :website, class_name: 'Pwb::Website'
end
```

### In Jobs/Background Context

```ruby
# Always use with_tenant helper for jobs
def perform(website_id, search_id)
  with_tenant(website_id) do
    # PwbTenant:: models are now auto-scoped
    search = PwbTenant::ExternalSearch.find(search_id)
    results = search.website.external_feed.search(search.search_params)
  end
end
```

### In Controllers/Web Context

```ruby
# Controllers use PwbTenant:: models directly
class ExternalSearchesController < ApplicationController
  def index
    @searches = PwbTenant::ExternalSearch.where(user: current_user)
  end
  
  def create
    @search = current_user.external_searches.build(search_params)
    @search.website = current_website
    @search.save!
  end
end
```

---

## Search Parameters Storage

### Search Param Structure
```ruby
# Store as JSON in database
{
  listing_type: "sale",           # :sale or :rental
  location: "Barcelona",           # City/region name
  min_price: 100000,               # In euros (or property currency)
  max_price: 500000,
  min_bedrooms: 2,
  max_bedrooms: 4,
  min_bathrooms: 1.5,
  max_bathrooms: nil,
  min_area: 100,                   # Square meters
  max_area: 300,
  property_types: ["apartment", "house"],  # Array of types
  features: ["pool", "parking"],   # Array of features
  sort: "price_asc"                # price_asc, price_desc, newest, updated
}
```

### Using Stored Params
```ruby
def execute_search(search)
  external_feed = search.website.external_feed
  
  # Merge stored params with pagination/locale
  params = search.search_params.merge(
    locale: search.user.default_client_locale,
    page: 1
  )
  
  external_feed.search(params)
end
```

---

## Email Template Locations

### ERB Templates (Standard)
```
app/views/pwb/mailers/
  - search_alert_mailer/
    - search_results.html.erb
    - search_results.text.erb
```

### Liquid Templates (Custom)
```
# Custom templates managed via EmailTemplate model
# Rendered via EmailTemplateRenderer service
# Keys: "search_alert.results", "search_alert.digest", etc.
```

---

## Key Configuration in Website Model

### Website Columns for Feature

The `Pwb::Website` model already has:
- External feed configuration
- Email configuration
- Ntfy settings (for admin notifications, not user emails)

**No new columns needed** - store alert settings on ExternalSearch model.

---

## Controller Structure

### New Controllers to Create

```ruby
# app/controllers/site/external_searches_controller.rb
class ExternalSearchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_search, only: [:show, :edit, :update, :destroy]
  
  # GET /external_searches
  def index
    @searches = current_user.external_searches.where(website: current_website)
  end
  
  # POST /external_listings/save_search
  def create
    @search = current_user.external_searches.build(search_params)
    @search.website = current_website
    
    if @search.save
      # Trigger first search immediately
      SearchAlertJob.perform_later(current_website.id, @search.id)
      redirect_to @search, notice: 'Search saved successfully'
    else
      render :new
    end
  end
  
  # PATCH /external_searches/:id
  def update
    if @search.update(search_params)
      redirect_to @search, notice: 'Search updated'
    else
      render :edit
    end
  end
  
  # DELETE /external_searches/:id
  def destroy
    @search.destroy
    redirect_to external_searches_url
  end
  
  private
  
  def search_params
    params.require(:external_search).permit(
      :name, :description, :alert_frequency,
      :active, :alert_on_new_only, :alert_emails,
      search_params: [
        :listing_type, :location, :min_price, :max_price,
        :min_bedrooms, :max_bedrooms, :min_bathrooms, :max_bathrooms,
        :min_area, :max_area, :sort,
        property_types: [], features: []
      ]
    )
  end
end
```

---

## Migration Template

```ruby
class CreatePwbExternalSearches < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_external_searches do |t|
      # Associations
      t.references :user, foreign_key: { to_table: :pwb_users }, null: false
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false
      
      # Search metadata
      t.string :name, null: false
      t.text :description
      
      # Search criteria (flexible JSON structure)
      t.json :search_params, default: {}
      
      # Alert configuration
      t.integer :alert_frequency, default: 0  # 0=immediate, 1=daily, 2=weekly, 3=monthly
      t.string :alert_emails                  # Comma-separated or store as array
      t.json :notification_settings, default: {}
      
      # Tracking
      t.datetime :last_run_at
      t.integer :last_result_count, default: 0
      t.datetime :last_alerted_at
      t.boolean :active, default: true
      
      t.timestamps
    end
    
    add_index :pwb_external_searches, [:user_id, :website_id]
    add_index :pwb_external_searches, :website_id
    add_index :pwb_external_searches, :active
  end
end

class CreatePwbSearchAlerts < ActiveRecord::Migration[7.1]
  def change
    create_table :pwb_search_alerts do |t|
      t.references :external_search, foreign_key: { to_table: :pwb_external_searches }, null: false
      t.references :website, foreign_key: { to_table: :pwb_websites }, null: false
      
      # Execution tracking
      t.datetime :searched_at, null: false
      t.integer :results_count, default: 0
      t.text :error_message
      
      # Results storage
      t.json :properties_data, default: {}
      
      # Delivery tracking
      t.boolean :alert_sent, default: false
      t.datetime :alert_sent_at
      
      t.timestamps
    end
    
    add_index :pwb_search_alerts, [:external_search_id, :searched_at]
    add_index :pwb_search_alerts, :alert_sent
  end
end
```

---

## Routes

```ruby
# config/routes.rb

namespace :site do
  resources :external_searches do
    member do
      post :run_now  # Run search immediately
      get :results   # View results
    end
  end
  
  # Add to existing external_listings routes
  resources :external_listings do
    member do
      post :save_search  # Quick save current search
    end
  end
end
```

---

## Testing Strategy

### Unit Tests
```ruby
# spec/models/pwb/external_search_spec.rb
describe Pwb::ExternalSearch do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:website) }
  it { is_expected.to validate_presence_of(:name) }
  
  describe '#alert_frequency' do
    it 'defaults to 0 (immediate)'
  end
  
  describe '#search_params' do
    it 'stores and retrieves JSON'
    it 'validates required parameters'
  end
end

# spec/jobs/pwb/search_alert_job_spec.rb
describe Pwb::SearchAlertJob do
  it 'executes search with saved parameters'
  it 'finds new properties since last run'
  it 'sends email only if new properties exist'
  it 'updates last_run_at timestamp'
  it 'respects multi-tenancy'
end

# spec/mailers/pwb/search_alert_mailer_spec.rb
describe Pwb::SearchAlertMailer do
  it 'sends email to user'
  it 'includes property list'
  it 'marks delivery as successful'
end
```

### Integration Tests
```ruby
# spec/requests/site/external_searches_spec.rb
describe 'External Searches' do
  it 'allows user to save current search'
  it 'lists saved searches for current user'
  it 'triggers search alert job on create'
  it 'allows updating search criteria'
  it 'allows deleting saved search'
end
```

---

## Performance Considerations

### Indexes Needed
```ruby
# In migrations:
add_index :pwb_external_searches, [:user_id, :website_id]
add_index :pwb_external_searches, :active
add_index :pwb_external_searches, :last_run_at
add_index :pwb_search_alerts, [:external_search_id, :searched_at]
add_index :pwb_search_alerts, :alert_sent
```

### Caching Strategy
```ruby
# Cache search results for 24 hours
# Use Redis or Rails cache

def find_new_properties(search, results)
  cache_key = "search_#{search.id}_results"
  previous_results = Rails.cache.read(cache_key) || []
  
  new_refs = results.map(&:reference) - previous_results
  new_properties = results.select { |p| new_refs.include?(p.reference) }
  
  Rails.cache.write(cache_key, results.map(&:reference), expires_in: 24.hours)
  new_properties
end
```

---

## Authorization

### Controller Scoping
```ruby
# Only user who created search can access
before_action :authorize_user!, only: [:show, :edit, :update, :destroy]

private

def authorize_user!
  redirect_unless_authorized current_user, @search.user, 'External search access denied'
end
```

### Scope by Website
```ruby
# Searches belong to website
scope :for_website, ->(website) { where(website: website) }

# Only active searches for current website
PwbTenant::ExternalSearch.for_website(current_website).active
```

---

## Next Steps

1. ✅ **Exploration** (Complete - this document)
2. Create database models and migrations
3. Implement model validations and associations
4. Create background job for search execution
5. Create mailer for alerts
6. Build UI components
7. Write comprehensive tests
8. Deploy and monitor

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `/app/mailers/pwb/enquiry_mailer.rb` | Email pattern to follow |
| `/app/jobs/ntfy_notification_job.rb` | Job pattern to follow |
| `/app/jobs/concerns/tenant_aware_job.rb` | Tenant-aware helper |
| `/app/controllers/site/external_listings_controller.rb` | Search params structure |
| `/app/services/pwb/external_feed/manager.rb` | How to run searches |
| `/app/models/pwb/contact.rb` | Multi-tenancy scoping pattern |
| `/config/routes.rb` | Route definitions to follow |

---

## Question? Reference the Full Exploration

See: `/docs/claude_thoughts/saved_searches_email_alerts_exploration.md` for detailed analysis and background.
