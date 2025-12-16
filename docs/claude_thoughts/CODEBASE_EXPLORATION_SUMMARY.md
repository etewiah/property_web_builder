# PropertyWebBuilder Codebase Exploration Summary

## Document Purpose
This document summarizes the PropertyWebBuilder codebase structure, key models, controllers, and existing analytics/tracking capabilities to inform analytics implementation decisions.

**Exploration Date:** December 16, 2025

---

## 1. Namespace & Architecture Overview

### Namespace Convention: `Pwb::`
The application uses the `Pwb::` namespace (PropertyWebBuilder) for all core models and application logic.

**Key Files:**
- `app/models/pwb.rb` - Namespace definition
- `app/models/pwb/application_record.rb` - Base class for all Pwb models
  - Sets `self.table_name_prefix = "pwb_"` - all table names prefixed with `pwb_`

### ApplicationRecord Pattern
```ruby
module Pwb
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "pwb_"
  end
end
```

All Pwb models inherit from `Pwb::ApplicationRecord`, which automatically prefixes tables with `pwb_`.

---

## 2. Multi-Tenancy Architecture

### Key Concept: Website = Tenant
Each tenant website is represented by a `Pwb::Website` model. Multi-tenancy is achieved through:

1. **ActsAsTenant Gem** - Automatic tenant scoping for models
2. **Pwb::Current** - Thread-safe current tenant storage
3. **SubdomainTenant Concern** - Automatic tenant resolution from request

### Pwb::Current Model
Located at: `/app/models/pwb/current.rb`

```ruby
module Pwb
  class Current < ActiveSupport::CurrentAttributes
    attribute :website
  end
end
```

Used throughout the app to access the current tenant:
- `Pwb::Current.website` - Get the current website/tenant
- Set via `before_action` in controllers

### SubdomainTenant Concern
Located at: `/app/controllers/concerns/subdomain_tenant.rb`

**Routing Priority:**
1. X-Website-Slug header (API/GraphQL requests)
2. Custom domain match (www.myrealestate.com)
3. Subdomain match (tenant.propertywebbuilder.com)
4. Fallback to default website

**Usage:**
```ruby
class SomeController < ActionController::Base
  include SubdomainTenant
  # Automatically sets Pwb::Current.website via before_action
end
```

---

## 3. Website & Tenant Model (`Pwb::Website`)

**File:** `/app/models/pwb/website.rb`

### Key Features:

#### Multi-Domain Support
- **Subdomain:** Unique slug for platform domains (e.g., "myagency" in "myagency.propertywebbuilder.com")
- **Custom Domain:** Own branded domain with DNS verification
- **Platform Domains:** Configurable via `ENV['PLATFORM_DOMAINS']` (default: propertywebbuilder.com,pwb.localhost)

#### Provisioning State Machine (AASM)
Tracks website setup progress through states:
- `pending` → `owner_assigned` → `agency_created` → `links_created` → `field_keys_created` → `properties_seeded` → `ready` → `locked_pending_email_verification` → `locked_pending_registration` → `live`
- Includes error handling with `failed` and `suspended` states

#### Key Associations
```ruby
has_many :pages
has_many :realty_assets  # Properties (new normalized model)
has_many :props          # Legacy properties (for compatibility)
has_many :contacts
has_many :messages
has_many :users
has_many :user_memberships  # For multi-website support
has_many :websites, through: :user_memberships
has_one :agency
has_one :subscription
has_many :field_keys
```

#### Key Fields
- `subdomain` - Platform subdomain (unique, validates format/reservations/profanity)
- `custom_domain` - Branded domain (with verification token support)
- `theme_name` - Active theme
- `provisioning_state` - Current setup state
- `analytics_id` / `analytics_id_type` - Google Analytics tracking (legacy)
- `supported_locales` - Array of supported languages
- `site_type` - 'residential', 'commercial', 'vacation_rental'
- `email_verified_at` - Tracks email verification
- `provisioning_started_at`, `provisioning_completed_at` - Timeline tracking

#### Subscription & Plan Integration
```ruby
has_one :subscription, class_name: 'Pwb::Subscription', dependent: :destroy

def plan
  subscription&.plan
end

def has_feature?(feature_key)
  subscription&.has_feature?(feature_key) || false
end

def can_add_property?
  return true unless subscription
  subscription.within_property_limit?(realty_assets.count + 1)
end
```

---

## 4. Key Models for Analytics

### 4.1 Property Models

#### Legacy Model: `Pwb::Prop`
**File:** `/app/models/pwb/prop.rb`
- Backwards compatible property model
- Used in console work and cross-tenant operations
- NOT tenant-scoped (use PwbTenant::Prop in web requests)

#### New Normalized Model: `Pwb::RealtyAsset`
**File:** `/app/models/pwb/realty_asset.rb`
- Represents the physical property (building/land)
- Central property record, does NOT include transaction data
- Transactions stored separately in:
  - `Pwb::SaleListing` (for sale data)
  - `Pwb::RentalListing` (for rental data)
- Auto-generates URL slugs
- After commit hooks refresh materialized view
- Validates property limit on creation

**Key Fields:**
- `website_id` - Tenant association
- `slug` - URL-friendly identifier (auto-generated, unique)
- `prop_type_key` - Property type (from field keys)
- `address fields` - street_address, city, region, postal_code, country, latitude, longitude
- `constructed_area`, `plot_area` - Size measurements
- `count_bedrooms`, `count_bathrooms`, `count_garages`
- `created_at`, `updated_at` - Timestamps

#### Read-Only View Model: `Pwb::ListedProperty`
**File:** `/app/models/pwb/listed_property.rb`
- Backed by a materialized view (`pwb_properties`)
- Denormalizes RealtyAsset + SaleListing + RentalListing
- Used for optimized property search and display
- Read-only (calls underlying models for writes)
- Auto-refreshes view after RealtyAsset changes

**Usage:**
```ruby
# For queries and display
properties = Pwb::ListedProperty.where(website_id: website_id).visible.for_sale

# For updates
realty_asset = Pwb::RealtyAsset.find(id)
realty_asset.update(...)
Pwb::ListedProperty.refresh  # Refresh materialized view
```

#### Listing Models: `Pwb::SaleListing` & `Pwb::RentalListing`
- Transaction-specific data
- Translations via Mobility gem (Mobility translations)
- title, description fields
- Price fields (different types: current, original, low_season, high_season, standard_season)

### 4.2 Contact & Message Models

#### `Pwb::Contact`
**File:** `/app/models/pwb/contact.rb`
- Represents a person/entity that interacts with website
- NOT tenant-scoped (use PwbTenant::Contact in web requests)

**Key Associations:**
```ruby
belongs_to :website
has_many :messages
belongs_to :primary_address  # Pwb::Address
belongs_to :user, optional: true
```

**Key Fields:**
- `email`, `first_name`, `last_name`, `phone_number`
- `title` enum - mr, mrs
- `created_at` - First contact timestamp
- `details` - JSON for flexible data storage

#### `Pwb::Message`
**File:** `/app/models/pwb/message.rb`
- Represents visitor inquiries/messages
- NOT tenant-scoped (use PwbTenant::Message in web requests)

**Key Associations:**
```ruby
belongs_to :website
belongs_to :contact
```

**Key Fields:**
- `content` - Message body
- `created_at` - When received
- `delivered_at` - When message was delivered (if applicable)

**Schema Note:** Messages table has `delivered_at` column (from migration `20251209181022_add_delivery_tracking_to_messages.rb`)

### 4.3 Page Model

**File:** `/app/models/pwb/page.rb`
- CMS pages for websites
- NOT tenant-scoped (use PwbTenant::Page in web requests)

**Key Associations:**
```ruby
belongs_to :website
has_many :links  # Navigation links
has_many :page_contents
has_many :contents, through: :page_contents
has_many :page_parts
```

**Key Fields:**
- `slug` - URL slug (unique per website)
- `link_path` - Custom URL path
- `raw_html` - Page content (translatable via Mobility)
- `page_title`, `link_title` - Translatable titles
- `sort_order_top_nav`, `sort_order_footer` - Navigation ordering
- `visible` - Published status

---

## 5. Site Admin Controller Structure

### Base Controller: `SiteAdminController`
**File:** `/app/controllers/site_admin_controller.rb`

**Characteristics:**
- Base for all site admin functionality
- Single tenant/website scoped (unlike TenantAdminController)
- Uses `SubdomainTenant` concern
- Uses `AdminAuthBypass` concern
- Requires authentication via `require_admin!` before_action
- Uses `Pagy::Method` for pagination

**Layout:** `site_admin`

**Helper Methods:**
```ruby
def current_website
  Pwb::Current.website
end
helper_method :current_website

def set_tenant_from_subdomain
  ActsAsTenant.current_tenant = current_website
end
```

### Controller Inheritance Pattern
All site_admin controllers inherit from `SiteAdminController`:

```
SiteAdminController (base)
├── site_admin/dashboard_controller.rb
├── site_admin/onboarding_controller.rb
├── site_admin/props_controller.rb
├── site_admin/pages_controller.rb
├── site_admin/contacts_controller.rb
├── site_admin/messages_controller.rb
├── site_admin/email_templates_controller.rb
├── site_admin/domains_controller.rb
└── ... (19 controllers total)
```

### Key Controllers

#### DashboardController
**File:** `/app/controllers/site_admin/dashboard_controller.rb`

**Responsibilities:**
- Main dashboard for site administration
- Shows statistics for the website
- Displays recent activity

**Key Stats Collected:**
```ruby
@stats = {
  total_properties: Pwb::ListedProperty.where(website_id: website_id).count,
  total_pages: Pwb::Page.where(website_id: website_id).count,
  total_contents: Pwb::Content.where(website_id: website_id).count,
  total_messages: Pwb::Message.where(website_id: website_id).count,
  total_contacts: Pwb::Contact.where(website_id: website_id).count
}
```

**Recent Activity:**
```ruby
@recent_properties = Pwb::ListedProperty.where(website_id: website_id).order(created_at: :desc).limit(5)
@recent_messages = Pwb::Message.where(website_id: website_id).order(created_at: :desc).limit(5)
@recent_contacts = Pwb::Contact.where(website_id: website_id).order(created_at: :desc).limit(5)
```

**Subscription Info:**
- Status, plan name, pricing
- Trial days remaining
- Property limit tracking
- Enabled features

#### OnboardingController
**File:** `/app/controllers/site_admin/onboarding_controller.rb`

**Purpose:** Guides new users through initial setup

**Steps:**
1. Welcome
2. Profile (agency details)
3. Property (add first listing)
4. Theme (choose template)
5. Complete (summary)

**Key Pattern:**
- Wraps onboarding steps in a state machine
- Can skip step 3 (property)
- Marks user as active on completion

### Concerns

#### SiteAdminOnboarding
**File:** `/app/controllers/concerns/site_admin_onboarding.rb`

**Purpose:** Automatically redirect new users to onboarding wizard

**Behavior:**
- Before_action hook redirects to onboarding if needed
- Skips if already on onboarding pages
- Skips for API/JSON requests
- Only shows to new admin users

---

## 6. User & Authentication Models

### `Pwb::User`
**File:** `/app/models/pwb/user.rb`

**Key Features:**

#### Devise Integration
```ruby
devise :database_authenticatable, :registerable,
  :recoverable, :rememberable, :trackable,
  :validatable, :lockable, :timeoutable,
  :omniauthable, omniauth_providers: [:facebook]
```

#### Onboarding State Machine (AASM)
```
lead → registered → email_verified → onboarding → active
       └─────────────────────────────────────────┘ (alternate paths)
```

**Onboarding Tracking:**
- `onboarding_state` - Current state
- `onboarding_step` - Progress within state
- `onboarding_started_at` - When onboarding began
- `onboarding_completed_at` - When onboarding finished
- `site_admin_onboarding_completed_at` - Site admin onboarding completion

#### Multi-Website Support
```ruby
has_many :user_memberships, dependent: :destroy
has_many :websites, through: :user_memberships

def admin_for?(website)
  user_memberships.active.where(website: website, role: ['owner', 'admin']).exists?
end

def can_access_website?(website)
  website_id == website.id || user_memberships.active.exists?(website: website)
end
```

#### Firebase Support
```ruby
def active_for_authentication?
  return true if firebase_uid.present?  # Firebase users allowed
  # ... other checks
end
```

### `Pwb::AuthAuditLog`
**File:** `/app/models/pwb/auth_audit_log.rb`

**Purpose:** Security audit trail for authentication events

**Logged Events:**
- `login_success`, `login_failure`
- `logout`
- `oauth_success`, `oauth_failure`
- `password_reset_request`, `password_reset_success`
- `account_locked`, `account_unlocked`
- `session_timeout`
- `registration`

**Key Fields:**
- `event_type` - Type of event
- `user_id` - Associated user
- `email` - User email
- `ip_address` - Request IP
- `user_agent` - Browser/client info
- `request_path` - URL path
- `failure_reason` - Why event occurred
- `metadata` - Flexible JSON data
- `created_at` - Timestamp

**Scopes:**
```ruby
scope :recent
scope :for_user
scope :for_email
scope :for_ip
scope :failures
scope :successes
scope :today
scope :last_hour
scope :last_24_hours
```

**Class Methods for Logging:**
```ruby
AuthAuditLog.log_login_success(user:, request:, website:)
AuthAuditLog.log_login_failure(email:, request:, reason:, website:)
AuthAuditLog.log_logout(user:, request:, website:)
# ... and more
```

---

## 7. Subscription & Plan Models

### `Pwb::Subscription`
**File:** `/app/models/pwb/subscription.rb`

**Purpose:** Links a Website to a Plan and tracks billing status

**Status States (AASM):**
```
trialing → active (when payment received)
trialing → expired (if trial ends without payment)
active → past_due (payment fails)
active → canceled (user cancels)
past_due → active (payment succeeds)
past_due → canceled (continued failure)
canceled → active (resubscribe)
```

**Key Fields:**
- `status` - Current subscription state
- `plan_id` - Associated plan
- `trial_ends_at` - End of trial period
- `current_period_starts_at`, `current_period_ends_at` - Billing period
- `canceled_at` - When subscription was canceled

**Key Methods:**
```ruby
def in_good_standing?
  trialing? || active?
end

def trial_ended?
  trial_ends_at.present? && trial_ends_at < Time.current
end

def trial_days_remaining
  # Returns days left in trial
end

def within_property_limit?(count)
  plan.unlimited_properties? || count <= plan.property_limit
end

def has_feature?(feature_key)
  plan.has_feature?(feature_key)
end
```

**Audit Logging:**
```ruby
has_many :events, class_name: 'Pwb::SubscriptionEvent', dependent: :destroy
```

### `Pwb::Plan`
**File:** `/app/models/pwb/plan.rb`

**Purpose:** Defines subscription tiers with pricing, limits, and features

**Key Fields:**
- `name`, `slug` - Unique identifiers
- `display_name` - Human-readable name
- `price_cents`, `price_currency` - Pricing
- `billing_interval` - 'month' or 'year'
- `trial_days` - Free trial duration
- `property_limit` - Max properties (nil = unlimited)
- `user_limit` - Max team members (nil = unlimited)
- `features` - JSON array of enabled features

**Supported Features:**
```ruby
FEATURES = {
  basic_themes: 'Access to basic themes',
  premium_themes: 'Access to premium themes',
  analytics: 'Website analytics dashboard',
  custom_domain: 'Use your own custom domain',
  api_access: 'API access for integrations',
  white_label: 'Remove PropertyWebBuilder branding',
  priority_support: 'Priority email support',
  dedicated_support: 'Dedicated account manager'
}
```

**Key Methods:**
```ruby
def has_feature?(feature_key)
  features.include?(feature_key.to_s)
end

def unlimited_properties?
  property_limit.nil?
end

def remaining_properties(current_count)
  plan.property_limit - current_count
end
```

### `Pwb::SubscriptionEvent`
**File:** `/app/models/pwb/subscription_event.rb`

**Purpose:** Audit log for subscription changes

**Event Types:**
```
trial_started, activated, trial_expired, past_due, canceled, expired,
reactivated, plan_changed, payment_received, payment_failed
```

**Key Fields:**
- `event_type` - Type of event
- `subscription_id` - Associated subscription
- `metadata` - JSON object with event details
- `created_at` - When event occurred

---

## 8. Existing Analytics & Tracking

### Current Analytics Implementation

#### Google Analytics Integration
**File:** `/app/views/pwb/_analytics.html.erb`

**Current Implementation:**
```erb
<% if @current_website.render_google_analytics %>
  <script type="text/javascript">
    var _gaq = _gaq || [];
    _gaq.push(['_setAccount', '<%= @current_website.analytics_id %>']);
    _gaq.push(['_trackPageview']);
    // ... GA script loading
  </script>
<% end %>
```

**Website Fields:**
- `analytics_id` - Google Analytics tracking ID
- `analytics_id_type` - Type of analytics implementation
- `render_google_analytics` - Boolean flag (checks `Rails.env.production? && analytics_id.present?`)

**Characteristics:**
- Only enabled in production
- Legacy Google Analytics (Universal Analytics, not GA4)
- Very basic page view tracking

### Audit Logging Already in Place

#### AuthAuditLog
- Comprehensive authentication event tracking
- IP address, user agent, request path
- Supports security monitoring and analysis

#### SubscriptionEvent
- All billing events tracked
- Plan changes logged
- Payment events recorded

#### Message Delivery Tracking
- `delivered_at` field on messages
- Tracks when messages are delivered to contacts

### No Analytics Gems Currently Installed
Search of Gemfile revealed:
- No `ahoy` gem
- No `mixpanel` gem
- No `segment` gem
- No `amplitude` gem
- Only error tracking: `sentry-ruby`, `sentry-rails`
- Performance monitoring: `rails_performance`

---

## 9. Gemfile Dependencies (Relevant to Analytics)

### Installed Gems

**Core Framework:**
- Rails ~> 8.1
- Devise ~> 4.8 (authentication)
- OmniAuth ~> 2.1 (OAuth)

**Multi-Tenancy & Data:**
- `acts_as_tenant` ~> 1.0 (automatic tenant scoping)
- `scenic` (database materialized views)
- `mobility` (translations)
- `aasm` ~> 5.5 (state machines)

**Background Jobs:**
- `solid_queue` ~> 1.0 (Rails 8 native job processor)
- `mission_control-jobs` ~> 0.3 (job monitoring)

**Error Tracking & Performance:**
- `sentry-ruby` (error tracking)
- `sentry-rails` (Rails integration)
- `rails_performance` (performance monitoring dashboard)

**Monitoring Utilities:**
- `sys-cpu` (CPU monitoring for dashboard)
- `sys-filesystem` (filesystem monitoring)
- `get_process_mem` (memory monitoring)

**Logging:**
- `lograge` (structured logging)
- `logstash-event` (log formatting)

**Money & Pricing:**
- `money-rails` ~> 1.15 (currency handling)

**Pagination:**
- `pagy` ~> 43.0 (fast pagination)

**Security:**
- `rack-attack` ~> 6.7 (rate limiting)
- `obscenity` ~> 1.0 (profanity filter)

**API:**
- `graphql` ~> 2.0 (GraphQL API)
- `rswag-api`, `rswag-ui` (OpenAPI/Swagger)

**Cloud/Storage:**
- `aws-sdk-s3` (S3/Cloudflare R2 storage)
- `aws-sdk-sesv2` (Email delivery)

---

## 10. Database Schema Patterns

### Multi-Tenant Data Model
All core tables have `website_id` foreign key:
- `pwb_contacts.website_id`
- `pwb_messages.website_id`
- `pwb_pages.website_id`
- `pwb_realty_assets.website_id`
- `pwb_props.website_id`

### Timestamp Patterns
All tables include:
- `created_at` - Record creation time
- `updated_at` - Last modification time

### JSON Column Usage
- `pwb_websites.configuration` - Flexible configuration storage
- `pwb_contacts.details` - Flexible contact data
- `pwb_auth_audit_logs.metadata` - Additional event context
- `pwb_subscription_events.metadata` - Event-specific data

### Mobility Translations
Models use Mobility gem with container backend (JSONB):
- `pwb_props.translations` - Property title, description (multi-language)
- `pwb_pages.translations` - Page content (multi-language)
- `pwb_listings.translations` - Listing marketing text

---

## 11. Key Implementation Patterns

### Tenant Scoping Pattern

**In Controllers:**
```ruby
class SomeAdminController < SiteAdminController
  def index
    @records = Pwb::SomeModel.where(website_id: current_website.id)
  end
end
```

**With ActsAsTenant:**
```ruby
class SiteAdminController < ActionController::Base
  include SubdomainTenant
  
  before_action :set_tenant_from_subdomain
  # All queries are now scoped to current_website automatically
end
```

### State Machine Pattern (AASM)

**Website Provisioning:**
```ruby
aasm column: :provisioning_state do
  state :pending, initial: true
  state :owner_assigned
  # ...
  event :assign_owner do
    transitions from: :pending, to: :owner_assigned, guard: :has_owner?
    after { log_provisioning_step('owner_assigned') }
  end
end
```

**User Onboarding:**
```ruby
aasm column: :onboarding_state do
  state :lead, initial: true
  state :registered
  state :active
  # ... transitions
end
```

### Logging Pattern

**Method 1 - Class Methods:**
```ruby
AuthAuditLog.log_login_success(user:, request:, website:)
```

**Method 2 - Inline:**
```ruby
log_provisioning_step('owner_assigned')
```

**Method 3 - After Hooks:**
```ruby
after_commit :send_security_notification, on: :create
```

---

## 12. Recommendations for Analytics Implementation

Based on the exploration, here are key observations for analytics:

### Strengths to Leverage

1. **ActsAsTenant Already Configured** - Automatic tenant isolation available
2. **Strong Audit Trail Foundation** - AuthAuditLog and SubscriptionEvent patterns
3. **Event-Driven Architecture** - State machines with after hooks perfect for event capture
4. **Existing Timestamps** - All models have created_at/updated_at
5. **Multi-Tenant Design** - website_id on all tables enables scoped analytics
6. **AASM State Machines** - Natural places to emit events

### Analytics Candidates

**High Priority Events:**
- User registration (Pwb::User creation)
- User onboarding completion (onboarding_completed_at)
- Property creation/updates (RealtyAsset)
- Property views (needs implementation)
- Contact/message creation
- Subscription events (already tracked)
- Website provisioning milestones

**Metrics to Track:**
- Properties per website
- Messages per contact
- Onboarding completion rate
- Feature usage (per plan)
- Website growth over time

### Potential Tracking Integrations

1. **Ahoy Analytics** - Lightweight, Rails-native, good for user behavior
2. **Custom Event System** - Build on existing AuthAuditLog/SubscriptionEvent pattern
3. **Sentry Events** - Already installed, could use for business events
4. **Rails Performance Dashboard** - Already installed, could supplement with custom metrics

### Implementation Considerations

1. **Where to Capture Events:**
   - After-commit hooks on models
   - Controller actions
   - State machine transitions
   - Service objects (if created)

2. **Tenant Isolation:**
   - All events must be scoped to website_id
   - Use Pwb::Current.website in event capture
   - Filter analytics by website in dashboards

3. **Performance:**
   - Use background jobs (SolidQueue already available)
   - Batch event processing to avoid blocking requests
   - Consider materialized views for aggregated analytics

4. **Privacy:**
   - Plan field-level encryption for PII
   - Implement data retention policies
   - Support GDPR compliance (user data deletion)

---

## 13. File Locations Reference

### Core Models
```
app/models/pwb/
├── application_record.rb      # Base class with table prefix
├── website.rb                  # Tenant model
├── user.rb                     # Authentication & onboarding
├── auth_audit_log.rb          # Auth events
├── realty_asset.rb            # Property model
├── listed_property.rb         # Read-only property view
├── sale_listing.rb            # Sale transaction data
├── rental_listing.rb          # Rental transaction data
├── contact.rb                 # Contact/lead model
├── message.rb                 # Inquiry/message model
├── page.rb                    # CMS page model
├── subscription.rb            # Billing model
├── plan.rb                    # Pricing tier model
├── subscription_event.rb      # Billing audit log
└── current.rb                 # Thread-safe tenant storage
```

### Controllers
```
app/controllers/
├── site_admin_controller.rb        # Base site admin controller
└── site_admin/
    ├── dashboard_controller.rb     # Main dashboard
    ├── onboarding_controller.rb    # Setup wizard
    ├── props_controller.rb         # Property management
    ├── contacts_controller.rb      # Lead management
    ├── messages_controller.rb      # Message inbox
    └── ... (14 other controllers)
```

### Concerns
```
app/controllers/concerns/
├── subdomain_tenant.rb        # Tenant resolution from request
├── site_admin_onboarding.rb  # Onboarding redirect logic
└── admin_auth_bypass.rb      # Dev/E2E auth bypass
```

### Views
```
app/views/
├── pwb/_analytics.html.erb     # Google Analytics snippet
└── site_admin/
    └── onboarding/
        ├── welcome.html.erb
        ├── profile.html.erb
        ├── property.html.erb
        ├── theme.html.erb
        └── complete.html.erb
```

### Database
```
db/
└── schema.rb                  # Current schema definition
```

---

## 14. Key Takeaways

1. **Well-Structured Multi-Tenant App** - Clear separation of concerns, automatic tenant scoping via ActsAsTenant
2. **Event-Ready Architecture** - AASM state machines with hooks, existing audit logs, proper timestamps
3. **Minimal Existing Analytics** - Only Google Analytics tracker, no advanced analytics gems installed
4. **Strong Audit Foundation** - AuthAuditLog and SubscriptionEvent patterns show proven event tracking approach
5. **Team & Onboarding Focus** - Strong user management with onboarding states and progress tracking
6. **Subscription-Aware** - Plans and features already integrated, perfect for feature-based analytics
7. **No Analytics Gems Yet** - Greenfield opportunity to implement analytics cleanly without conflicts

This codebase is well-positioned for implementing comprehensive analytics with proper multi-tenant isolation and event tracking.
