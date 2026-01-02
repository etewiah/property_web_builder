# Saved Searches and Email Alerts for External Property Listings

**Date:** January 1, 2026  
**Purpose:** Codebase exploration and planning for saved search and email alert features

---

## Executive Summary

PropertyWebBuilder is a multi-tenant Rails application using **Solid Queue** for background jobs and **Devise** for authentication. The codebase has **no existing saved search functionality** but has mature patterns for:

- Email delivery (via Mailers with `deliver_later`)
- Background jobs (ActiveJob with Solid Queue)
- Multi-tenancy (ActsAsTenant with `Pwb::Website` tenant)
- External feed integration (normalized search results from various providers)
- Ntfy notification system (push notifications for admin events)

This document outlines how to implement saved searches and email alerts following existing patterns.

---

## 1. Saved Search Functionality - Current State

### No Existing Implementation
- **Search for "saved_search"**: No results
- **Search for "SavedSearch"**: No results  
- **Search for "search_alert"**: No results

### How Search Currently Works

#### External Listings Controller
**File:** `/app/controllers/site/external_listings_controller.rb`

```ruby
def index
  @search_params = search_params
  @result = external_feed.search(@search_params)
  @filter_options = external_feed.filter_options(locale: I18n.locale)
end

def search_params
  permitted = params.permit(
    :listing_type,
    :location,
    :min_price,
    :max_price,
    :min_bedrooms,
    :max_bedrooms,
    :min_bathrooms,
    :max_bathrooms,
    :min_area,
    :max_area,
    :sort,
    :page,
    :per_page,
    property_types: [],
    features: []
  ).to_h.symbolize_keys
end
```

**Searchable Parameters:**
- `listing_type` - `:sale` or `:rental`
- `location` - Location/city name
- Price range - `min_price`, `max_price`
- Bedrooms/Bathrooms - `min_bedrooms`, `max_bedrooms`, `min_bathrooms`, `max_bathrooms`
- Area - `min_area`, `max_area`
- `property_types[]` - Array of property type codes
- `features[]` - Array of required features
- `sort` - `:price_asc`, `:price_desc`, `:newest`, `:updated`
- Pagination - `page`, `per_page`

#### External Feed Service
**File:** `/app/services/pwb/external_feed/base_provider.rb`

The `BaseProvider` abstract class defines search interface. All providers implement:

```ruby
def search(params)
  # @return [NormalizedSearchResult]
end

def find(reference, params = {})
  # @return [NormalizedProperty, nil]
end

def similar(property, params = {})
  # @return [Array<NormalizedProperty>]
end
```

#### Search Result Structure
**File:** `/app/services/pwb/external_feed/normalized_search_result.rb`

```ruby
class NormalizedSearchResult
  attr_accessor :properties        # Array<NormalizedProperty>
  attr_accessor :total_count       # Integer
  attr_accessor :page              # Integer (1-indexed)
  attr_accessor :per_page          # Integer
  attr_accessor :total_pages       # Integer
  attr_accessor :query_params      # Hash - The params used
  attr_accessor :provider          # Symbol
  attr_accessor :fetched_at        # DateTime
  attr_accessor :error             # String
end
```

#### Property Structure
**File:** `/app/services/pwb/external_feed/normalized_property.rb`

```ruby
class NormalizedProperty
  # Basic identification
  attr_accessor :reference         # Provider's unique ID
  attr_accessor :provider          # Symbol
  attr_accessor :provider_url      # String

  # Details
  attr_accessor :title
  attr_accessor :description
  attr_accessor :property_type
  attr_accessor :listing_type      # :sale or :rental
  attr_accessor :status            # :available, :reserved, :sold, :rented
  
  # Location
  attr_accessor :location
  attr_accessor :city
  attr_accessor :address
  
  # Pricing
  attr_accessor :price             # Integer in cents
  attr_accessor :currency
  
  # Property specs
  attr_accessor :bedrooms
  attr_accessor :bathrooms
  attr_accessor :built_area
  attr_accessor :plot_area
  attr_accessor :year_built
  
  # Media
  attr_accessor :images            # Array<Hash>
  attr_accessor :virtual_tour_url
  attr_accessor :video_url
  
  # Timestamps
  attr_accessor :created_at
  attr_accessor :updated_at
  attr_accessor :fetched_at
end
```

---

## 2. User Authentication and Account System

### User Model
**File:** `/app/models/pwb/user.rb`

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :trackable,
    :validatable, :lockable, :timeoutable,
    :omniauthable, omniauth_providers: [:facebook]

  belongs_to :website, optional: true  # Primary website
  
  # Multi-website support
  has_many :user_memberships, dependent: :destroy
  has_many :websites, through: :user_memberships
  
  # Helper methods
  def display_name
    name = [first_names, last_names].compact_blank.join(' ')
    name.presence || email
  end
  
  def admin_for?(website)
    user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
  end
  
  def role_for(website)
    user_memberships.active.find_by(website: website)&.role
  end
  
  def accessible_websites
    websites.where(pwb_user_memberships: { active: true })
  end
end
```

### Key Points:
- Users can have multiple websites via memberships
- Email is stored in `email` column (unique)
- Devise handles authentication
- No existing notification preferences in User model
- No saved searches or alerts currently

### Contact Model
**File:** `/app/models/pwb/contact.rb`

Used for website visitors (inquiries, not authenticated users):
- `primary_email` - Contact's email
- `primary_phone_number`
- `first_name`, `last_name`
- `details` - JSON for flexible data
- Can be linked to `user_id`

---

## 3. Email Notification System

### Mailer Base Class
**File:** `/app/mailers/pwb/application_mailer.rb`

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: -> { default_from_address }
  layout "mailer"
  
  private
  
  def self.default_from_address
    ENV.fetch("DEFAULT_FROM_EMAIL") { "PropertyWebBuilder <noreply@propertywebbuilder.com>" }
  end
end
```

### Example Mailer: EnquiryMailer
**File:** `/app/mailers/pwb/enquiry_mailer.rb`

```ruby
class EnquiryMailer < Pwb::ApplicationMailer
  after_deliver :mark_delivery_success
  rescue_from StandardError, with: :handle_delivery_error

  def general_enquiry_targeting_agency(contact, message)
    @contact = contact
    @message = message
    
    # Supports custom Liquid templates
    if custom_template_available?("enquiry.general")
      send_with_custom_template(...)
    else
      mail(to: message.delivery_email, ...)
    end
  end

  private
  
  def mark_delivery_success
    @message.update(delivery_success: true, delivered_at: Time.current)
  end
  
  def handle_delivery_error(exception)
    @message.update(
      delivery_success: false,
      delivery_error: "#{exception.class}: #{exception.message}"
    )
    raise exception  # Let job retry
  end
end
```

### Email Sending Pattern
**From Props Controller:**
```ruby
EnquiryMailer.property_enquiry_targeting_agency(@contact, @enquiry, @property).deliver_later
```

Uses ActionMailer's `deliver_later` which queues the email via Solid Queue.

### Email Template System
- **ERB templates** in `app/views/pwb/mailers/`
- **Custom Liquid templates** via `Pwb::EmailTemplate` model
- `EmailTemplateRenderer` service for rendering custom templates

---

## 4. Background Job System

### Job Queue: Solid Queue
**Gem:** `gem 'solid_queue', '~> 1.0'`

Not Sidekiq - uses **Solid Queue** (Rails native, database-backed).

### Base Job Class
**File:** `/app/jobs/application_job.rb`

```ruby
class ApplicationJob < ActiveJob::Base
  # Retries at: 3s, 18s, 83s, ~6min, ~30min (5 attempts)
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  
  discard_on ActiveJob::DeserializationError do |_job, error|
    Rails.logger.error "Job discarded due to deserialization error: #{error.message}"
  end
end
```

### Tenant-Aware Job Pattern
**File:** `/app/jobs/concerns/tenant_aware_job.rb`

```ruby
module TenantAwareJob
  extend ActiveSupport::Concern

  private
  
  def with_tenant(website_id = nil)
    website_id ||= @tenant_website_id
    website = Pwb::Website.find_by(id: website_id)
    
    ActsAsTenant.with_tenant(website) do
      Pwb::Current.website = website
      yield
    end
  end
  
  def set_tenant!(website_id)
    @tenant_website_id = website_id
    website = Pwb::Website.find_by(id: website_id)
    ActsAsTenant.current_tenant = website
    Pwb::Current.website = website
    true
  end
end
```

### Example Job: NtfyNotificationJob
**File:** `/app/jobs/ntfy_notification_job.rb`

```ruby
class NtfyNotificationJob < ActiveJob::Base
  include TenantAwareJob
  queue_as :notifications
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(website_id, notification_type, record_id = nil, record_class = nil, action = nil, details = nil)
    website = Pwb::Website.find(website_id)
    return unless website.ntfy_enabled?

    ActsAsTenant.with_tenant(website) do
      # ... handle different notification types
    end
  end
end
```

**Usage Pattern:**
```ruby
NtfyNotificationJob.perform_later(
  website.id,
  :listing_change,
  listing.id,
  listing.class.name,
  :published
)
```

### Other Jobs in System
- `Pwb::BatchUrlImportJob` - Import properties from URLs
- `Pwb::DownloadScrapedImagesJob` - Download images for properties
- `Pwb::UpdateExchangeRatesJob` - Update currency exchange rates
- `RefreshPropertiesViewJob` - Refresh materialized view
- `SlaMonitoringJob` - Monitor support ticket SLAs
- `TicketNotificationJob` - Send ticket notifications

---

## 5. Multi-Tenancy Architecture

### Scoping Pattern
Every website is a **tenant**. Two model types exist:

**Pwb:: models** - Non-tenant-scoped (cross-tenant, for console work)
```ruby
class Pwb::Message < ApplicationRecord
  self.table_name = 'pwb_messages'
  belongs_to :website, class_name: 'Pwb::Website', optional: true
end
```

**PwbTenant:: models** - Tenant-scoped (for web requests)
```ruby
class PwbTenant::Message < Pwb::Message
  include RequiresTenant
  acts_as_tenant :website, class_name: 'Pwb::Website'
end
```

### Multi-Tenancy in Jobs
```ruby
def perform(website_id, ...)
  ActsAsTenant.with_tenant(website) do
    Pwb::Current.website = website
    # PwbTenant:: models now scoped to this website
  end
end
```

---

## 6. Ntfy Notification System

### Website Configuration
**File:** `/app/models/pwb/website.rb`

```ruby
# Ntfy-related columns in pwb_websites table:
# - ntfy_enabled (boolean)
# - ntfy_server_url (string, default: https://ntfy.sh)
# - ntfy_topic_prefix (string)
# - ntfy_access_token (string)
# - ntfy_notify_inquiries (boolean)
# - ntfy_notify_listings (boolean)
# - ntfy_notify_security (boolean)
# - ntfy_notify_users (boolean)
```

### Listing Notifications
**File:** `/app/models/concerns/ntfy_listing_notifications.rb`

```ruby
module NtfyListingNotifications
  extend ActiveSupport::Concern

  included do
    after_commit :notify_listing_activated, if: :listing_just_activated?
    after_commit :notify_listing_archived, if: :listing_just_archived?
  end

  private
  
  def notify_listing_activated
    return unless website&.ntfy_enabled?
    
    NtfyNotificationJob.perform_later(
      website.id,
      :listing_change,
      id,
      self.class.name,
      :published
    )
  end
end
```

### Used In:
- `Pwb::SaleListing` - for sale property listings
- `Pwb::RentalListing` - for rental property listings

**Note:** Ntfy is for **push notifications to admins**, not email alerts to users searching properties.

---

## 7. Data Models - Message and Contact Flow

### Message Model (Web Visitor Inquiries)
**File:** `/app/models/pwb/message.rb`

```ruby
class Message < ApplicationRecord
  self.table_name = 'pwb_messages'
  
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  belongs_to :contact, optional: true, class_name: 'Pwb::Contact'
  
  # Columns:
  # - title (string)
  # - content (text)
  # - origin_email (string)
  # - delivery_email (string)  # Agency's email
  # - delivery_success (boolean)
  # - delivered_at (datetime)
  # - delivery_error (text)
  # - read (boolean)
  # - origin_ip, user_agent, locale, url, host
  # - contact_id (FK)
  # - website_id (FK)
  # - created_at, updated_at
end
```

### Contact Model (Visitor Profile)
**File:** `/app/models/pwb/contact.rb`

```ruby
class Contact < ApplicationRecord
  self.table_name = 'pwb_contacts'
  
  belongs_to :website, class_name: 'Pwb::Website', optional: true
  belongs_to :user, optional: true, class_name: 'Pwb::User'
  has_many :messages, class_name: 'Pwb::Message', foreign_key: :contact_id
  
  # Columns:
  # - first_name, last_name, other_names
  # - primary_email, other_email
  # - primary_phone_number, other_phone_number
  # - title (enum: mr, mrs)
  # - documentation_id, documentation_type
  # - flags (integer, for bitwise settings)
  # - details (json)
  # - website_id (FK)
  # - user_id (FK)
  # - created_at, updated_at
  
  scope :with_messages, -> {
    where('EXISTS (SELECT 1 FROM pwb_messages WHERE pwb_messages.contact_id = pwb_contacts.id)')
  }
end
```

---

## 8. Existing Favorite/Bookmark Functionality

### Current State: **NONE FOUND**

Search results:
- **"favorite"**: Only found in `ahoy/event.rb` (analytics, not relevant)
- **"bookmark"**: No results
- **"wish"**: No results

There is **no existing favorite/bookmark system** for properties or searches.

---

## 9. Database Architecture

### Key Tables Relevant to New Feature:

**pwb_websites**
- External feed configuration (external_feed_enabled, external_feed_provider, external_feed_config)
- Ntfy settings
- Email configuration (email_for_general_contact_form, email_for_property_contact_form)

**pwb_users**
- User authentication and profile data
- user_id, email, website_id
- No notification preferences column yet

**pwb_user_memberships**
- Links users to websites with roles (owner, admin, member)

**pwb_contacts**
- Website visitor profiles
- For tracking who made inquiries

**pwb_messages**
- Inquiry messages from visitors
- Tracks delivery success

---

## 10. Recommended Database Models for Implementation

### Model 1: ExternalSearch (or SavedSearch)
**Purpose:** Store saved search criteria

```ruby
# Table: pwb_external_searches (or similar)
create_table :pwb_external_searches do |t|
  # Identification
  t.references :user, class_name: 'Pwb::User', foreign_key: true
  t.references :website, class_name: 'Pwb::Website', foreign_key: true
  
  # Search metadata
  t.string :name                    # User-friendly name
  t.text :description               # Optional description
  t.string :slug                    # URL-friendly identifier
  
  # Search parameters (store as JSON for flexibility)
  t.json :search_params do
    # Example structure:
    # {
    #   listing_type: 'sale',
    #   location: 'Barcelona',
    #   min_price: 100000,
    #   max_price: 500000,
    #   min_bedrooms: 2,
    #   property_types: ['apartment', 'house'],
    #   features: ['pool', 'parking']
    # }
  end
  
  # Last search results
  t.integer :last_result_count      # How many properties matched
  t.jsonb :last_results_summary     # Store summary of last run
  t.datetime :last_run_at           # When search was last executed
  
  # Preferences
  t.boolean :active, default: true  # Temporarily disable alerts
  t.integer :alert_frequency, default: 0  # Enum: immediate, daily, weekly, monthly
  t.text :alert_emails              # Comma-separated or JSON array
  t.jsonb :notification_settings do
    # {
    #   new_matches_only: true,      # Only alert on new properties
    #   price_changes: true,          # Alert on price changes
    #   price_threshold: 50000,       # Min price change to trigger alert
    #   include_sold: false           # Include sold properties
    # }
  end
  
  # Timestamps
  t.datetime :created_at
  t.datetime :updated_at
  t.datetime :last_alerted_at       # Track last email sent
  
  # Indexes
  t.index [:user_id, :website_id]
  t.index [:website_id]
  t.index [:user_id]
  t.index :slug                     # For URL lookups
  t.index :active
  t.index :last_run_at              # For finding stale searches
end
```

### Model 2: SearchAlert (or SearchResult)
**Purpose:** Track individual search runs and new results

```ruby
# Table: pwb_search_alerts (or pwb_external_search_results)
create_table :pwb_search_alerts do |t|
  t.references :external_search, foreign_key: true
  t.references :website, class_name: 'Pwb::Website', foreign_key: true
  
  # Search execution
  t.datetime :searched_at           # When search was run
  t.integer :results_count          # Total matching properties
  t.text :error_message             # If search failed
  
  # Results
  t.jsonb :properties_data do
    # Store compressed/summary of found properties:
    # {
    #   new: [{ ref: '123', title: '...', price: 150000 }, ...],
    #   updated: [{ ref: '456', ... }],
    #   removed: ['789', '901']  # No longer matching criteria
    # }
  end
  
  # Alert tracking
  t.boolean :alert_sent, default: false
  t.datetime :alert_sent_at
  t.text :alert_recipients          # Who it was sent to
  
  t.timestamps
  
  t.index [:external_search_id, :searched_at]
  t.index [:website_id]
  t.index :alert_sent
end
```

### Model 3: SavedProperty (or Favorite)
**Purpose:** Allow users to bookmark/favorite external listings

```ruby
# Table: pwb_saved_properties
create_table :pwb_saved_properties do |t|
  t.references :user, class_name: 'Pwb::User', foreign_key: true
  t.references :website, class_name: 'Pwb::Website', foreign_key: true
  
  # Property identification
  t.string :external_reference      # Provider's unique ID (e.g., ResalesOnline ref)
  t.string :provider                # Provider name (e.g., 'resales_online')
  t.string :title                   # Cached title for display
  
  # Cached property data (denormalized for quick display)
  t.string :property_type
  t.string :city
  t.integer :price_cents
  t.string :currency
  t.integer :bedrooms
  t.float :bathrooms
  t.string :image_url               # Cache main image
  t.string :listing_type            # 'sale' or 'rental'
  
  # Tracking
  t.text :notes                      # User's notes on property
  t.boolean :alert_on_price_change, default: false
  t.integer :alert_threshold_cents  # Minimum change to trigger alert
  
  t.timestamps
  t.index [:user_id, :website_id]
  t.index [:external_reference, :provider]
  t.index [:user_id]
end
```

---

## 11. Email Alert Sending Pattern

### New Mailer: SearchAlertMailer
**Location:** `/app/mailers/pwb/search_alert_mailer.rb`

```ruby
class SearchAlertMailer < Pwb::ApplicationMailer
  def search_results(user, search, alert)
    @user = user
    @search = search
    @alert = alert
    @website = search.website
    
    mail(
      to: user.email,
      subject: "New properties match your search: #{search.name}"
    )
  end
end
```

### New Job: SearchAlertJob
**Location:** `/app/jobs/pwb/search_alert_job.rb`

```ruby
class SearchAlertJob < ApplicationJob
  include TenantAwareJob
  queue_as :searches
  
  def perform(website_id, search_id)
    with_tenant(website_id) do
      search = PwbTenant::ExternalSearch.find(search_id)
      
      # Execute search with saved parameters
      results = execute_search(search)
      
      # Find new/changed properties since last run
      new_properties = find_new_properties(search, results)
      
      # Send email if there are new results
      if new_properties.any?
        send_alert_email(search, new_properties)
      end
      
      # Update last_run tracking
      search.update(
        last_result_count: results.total_count,
        last_run_at: Time.current,
        last_alerted_at: Time.current
      )
    end
  end
  
  private
  
  def execute_search(search)
    external_feed = search.website.external_feed
    external_feed.search(search.search_params)
  end
  
  def find_new_properties(search, results)
    # Compare with previous results
    # Return only new or changed properties
  end
  
  def send_alert_email(search, properties)
    alert = PwbTenant::SearchAlert.create(
      external_search: search,
      searched_at: Time.current,
      results_count: properties.size,
      properties_data: serialize_properties(properties),
      alert_sent: true,
      alert_sent_at: Time.current
    )
    
    SearchAlertMailer.search_results(search.user, search, alert).deliver_later
  end
end
```

### Scheduling (using Solid Queue)
**Location:** Job scheduler configuration

```ruby
# Run all active searches daily
SearchAlertSchedulerJob.perform_later  # Could be triggered by cron job or scheduler
```

Or manually in a rake task:
```ruby
# lib/tasks/scheduler.rake
task search_alerts: :environment do
  Pwb::ExternalSearch.active.find_each do |search|
    Pwb::SearchAlertJob.perform_later(search.website_id, search.id)
  end
end
```

---

## 12. Implementation Roadmap

### Phase 1: Core Saved Search Model
1. Create `Pwb::ExternalSearch` model and migration
2. Create `PwbTenant::ExternalSearch` for tenant scoping
3. Add model validations and associations
4. Create database indexes for performance
5. Write model tests

### Phase 2: UI - Save/Manage Searches
1. Add "Save this search" button to search results page
2. Create modal for naming and configuring search
3. Add "My Saved Searches" dashboard page
4. Implement search edit/delete functionality
5. Add alert frequency configuration UI

### Phase 3: Search Result Tracking
1. Create `Pwb::SearchAlert` model
2. Create job to execute searches and track changes
3. Store comparison logic (new properties vs previous run)
4. Create SearchAlertMailer
5. Write job tests

### Phase 4: Alert Delivery
1. Create background job for sending emails
2. Add email templates (ERB and custom Liquid)
3. Implement alert frequency logic (immediate, daily, weekly)
4. Add user preference controls
5. Implement bounce/unsubscribe handling

### Phase 5: Property Favorites (Optional)
1. Create `Pwb::SavedProperty` model
2. Add "Save to favorites" button on property details
3. Create user favorites page
4. Implement comparison functionality (compare 2+ properties)
5. Optional: Export comparison as PDF

### Phase 6: Testing & Optimization
1. Integration tests for end-to-end flow
2. Performance testing for large search result sets
3. Email delivery tests
4. Implement caching for frequently run searches
5. Monitor job queue performance

---

## 13. Key Architecture Decisions

### 1. Search Parameters Storage
**Decision:** Store as JSON in database
**Rationale:** 
- External feed API parameters evolve over time
- Flexibility without schema migrations
- Easy to version/audit changes

### 2. Multi-Tenancy
**Decision:** Implement both Pwb:: and PwbTenant:: models
**Rationale:**
- Follows existing codebase pattern
- Ensures tenant isolation in web requests
- Allows console operations across tenants if needed

### 3. Background Jobs vs. Scheduled Tasks
**Decision:** Use background jobs with Solid Queue
**Rationale:**
- Existing system uses Solid Queue
- Better for handling failures and retries
- Can be triggered on-demand or via cron

### 4. Email Delivery
**Decision:** Use ActionMailer with `deliver_later`
**Rationale:**
- Existing pattern in codebase (see EnquiryMailer)
- Non-blocking email delivery
- Automatic retry on failure

### 5. Alert Frequency
**Decision:** Implement as enum-based configuration
**Rationale:**
- Simple to implement
- Can easily add more frequencies (hourly, daily, weekly, monthly)
- Allows per-search configuration

---

## 14. Patterns to Follow from Codebase

### Pattern 1: Mailer with Callbacks
```ruby
# From EnquiryMailer
class MyMailer < Pwb::ApplicationMailer
  after_deliver :mark_success
  rescue_from StandardError, with: :handle_error
  
  private
  
  def mark_success
    # Update record on success
  end
  
  def handle_error(exception)
    # Log failure on record
    raise exception  # Let job retry
  end
end
```

### Pattern 2: Tenant-Aware Background Job
```ruby
# From NtfyNotificationJob
class MyJob < ApplicationJob
  include TenantAwareJob
  queue_as :my_queue
  
  def perform(website_id, ...)
    website = Pwb::Website.find(website_id)
    ActsAsTenant.with_tenant(website) do
      # Work with PwbTenant:: models
    end
  end
end
```

### Pattern 3: Scoped Model Associations
```ruby
# From Contact model
# Use exists subquery instead of DISTINCT for JSON columns
scope :with_messages, -> {
  where('EXISTS (SELECT 1 FROM pwb_messages WHERE pwb_messages.contact_id = pwb_contacts.id)')
}
```

### Pattern 4: JSON Storage for Flexible Data
```ruby
# From Contact and other models
t.json :details, default: {}  # Flexible additional data
t.jsonb :search_params        # Structured but flexible

# Querying:
Contact.where("details->>'field' = ?", value)
```

---

## 15. Considerations & Gotchas

### 1. Multi-Tenancy in Tests
- Must set `ActsAsTenant.current_tenant = website`
- Use `with_tenant` helper from jobs
- Always scope queries in tests

### 2. External Feed API Rate Limits
- Check provider rate limits before running searches
- Consider caching search results
- Implement backoff logic for failed searches

### 3. Email Deliverability
- Monitor bounce rates
- Implement unsubscribe mechanism
- Handle invalid email addresses gracefully

### 4. Performance with Large Result Sets
- Don't store entire result sets in database
- Store only new property references
- Use pagination in emails

### 5. Timezone Handling
- Search alert times should respect user timezone
- Use `Time.current` for UTC
- Store timezone preference on user/website

### 6. Authorization
- Only authenticated users can create saved searches
- Only user who created search can modify it
- Admins can view search analytics across their website

---

## 16. References in Codebase

**Key Files to Reference:**
- `/app/mailers/pwb/enquiry_mailer.rb` - Email patterns
- `/app/jobs/ntfy_notification_job.rb` - Background job patterns
- `/app/jobs/concerns/tenant_aware_job.rb` - Tenant-aware pattern
- `/app/controllers/site/external_listings_controller.rb` - Search implementation
- `/app/services/pwb/external_feed/base_provider.rb` - Provider interface
- `/app/services/pwb/external_feed/normalized_search_result.rb` - Result structure
- `/app/models/pwb/contact.rb` - Multi-website scoping pattern
- `/app/models/pwb/website.rb` - Website configuration

**Key Gems:**
- `solid_queue` (v1.0) - Background job queue
- `devise` - Authentication
- `acts_as_tenant` - Multi-tenancy
- `mobility` - Translations (used in SaleListing)

---

## Summary

PropertyWebBuilder has **no saved search functionality** but has **mature patterns** for:

1. **Email delivery** - ActionMailer with `deliver_later`
2. **Background jobs** - Solid Queue with tenant awareness
3. **Multi-tenancy** - ActsAsTenant with Pwb::/ PwbTenant:: split
4. **External feeds** - Normalized search results structure
5. **User authentication** - Devise with multi-website support

**To implement saved searches and email alerts:**

1. Create `PwbExternalSearch` and `PwbSearchAlert` models
2. Implement search result change detection
3. Create `SearchAlertMailer` following `EnquiryMailer` pattern
4. Create `SearchAlertJob` as tenant-aware background job
5. Build UI for saving/managing searches
6. Implement alert frequency scheduling

The architecture is well-suited for this feature, as all supporting patterns already exist in the codebase.
