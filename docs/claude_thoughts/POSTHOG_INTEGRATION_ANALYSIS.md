# PostHog Analytics Integration Analysis

## Executive Summary

PropertyWebBuilder has a **robust, multi-tenant analytics foundation** already in place using Ahoy Matey. This analysis evaluates the existing setup and identifies opportunities for PostHog integration to enhance product analytics and user tracking across the platform.

**Key Finding:** The codebase is well-positioned for PostHog integration. Ahoy Matey currently provides visitor/event tracking at the frontend level, while PostHog could add product analytics, user identification, cohort analysis, and admin action tracking.

---

## 1. Current Analytics Setup

### 1.1 Ahoy Matey Analytics (INSTALLED)

**Status:** Fully implemented as of December 2024
- **Gem:** `ahoy_matey ~> 5.0` (Gemfile, line 246)
- **Database:** Multi-tenant schemas with `ahoy_visits` and `ahoy_events` tables
- **Configuration:** `/config/initializers/ahoy.rb`

**Architecture:**
```
ahoy_visits (Multi-tenant scoped)
├── website_id (FK -> pwb_websites)
├── user_id (FK -> pwb_users, optional)
├── visit_token, visitor_token
├── Traffic source: referrer, referring_domain, utm_*
├── Device: browser, os, device_type
└── Location: country, region, city

ahoy_events (Multi-tenant scoped)
├── website_id (FK -> pwb_websites)
├── visit_id (FK -> ahoy_visits, optional)
├── name (event type string)
├── properties (JSONB for flexible data)
└── time (timestamp)
```

**Key Configuration (`ahoy.rb`):**
- API-based tracking: `Ahoy.api = true`
- Cookies enabled: `Ahoy.cookies = true`
- IP masking for privacy: `Ahoy.mask_ips = true`
- Bot detection: `Ahoy.track_bots = false`
- Visit duration: 4 hours
- **Exclusions:** Admin paths (`/site_admin`, `/admin`), bots, non-website contexts

### 1.2 Event Tracking Service

**File:** `/app/services/pwb/analytics_service.rb`

Provides comprehensive analytics aggregation for tenant dashboards:

**Tracked Events:**
```ruby
page_viewed           # Generic page views
property_viewed       # Individual property detail views
property_searched     # Property search submissions
inquiry_submitted     # Contact form submissions
contact_form_opened   # Form open events
gallery_viewed        # Photo gallery views
property_shared       # Social share clicks
property_favorited    # Save/favorite toggles
```

**Analytics Queries:**
- `overview()` - Dashboard summary (visits, visitors, pageviews, conversions)
- `visits_by_day()`, `visitors_by_day()`, `property_views_by_day()`
- `top_properties(limit)`, `top_pages(limit)`, `top_searches(limit)`
- `traffic_sources()`, `traffic_by_source_type()`, `utm_campaigns()`
- `visitors_by_country()`, `visitors_by_city()`
- `device_breakdown()`, `browser_breakdown()`
- `inquiry_funnel()` - Conversion funnel analysis
- `real_time_visitors()`, `real_time_page_views()` (last 30 min)

### 1.3 Frontend Tracking Implementation

**File:** `/app/views/pwb/_analytics.html.erb`

**Ahoy.js Integration:**
- Asynchronously loaded after DOMContentLoaded for page performance
- Configured via `ahoy.configure()` with custom events
- Event tracking via data attributes (`[data-property-gallery]`, `[data-contact-trigger]`, etc.)

**Tracked UI Interactions:**
```javascript
gallery_viewed          // [data-property-gallery]
contact_form_opened     // [data-contact-trigger]
property_shared         // [data-share-property]
property_favorited      // [data-favorite-property]
```

**Legacy Google Analytics:**
- Conditional rendering based on `@current_website.render_google_analytics`
- Uses old GA code (async loading pattern)

### 1.4 Server-Side Tracking Concern

**File:** `/app/controllers/concerns/trackable.rb`

Provides reusable tracking methods for controllers:

```ruby
# Page view tracking (automatic via after_action)
track_page_view  # Captures page_type, action, path, title

# Property tracking
track_property_view(property)    # Property details with metadata
track_property_search(params, results_count)  # Search queries
track_inquiry(message, property:)             # Form submissions
track_contact_form_opened(property:)          # Form opens
track_gallery_view(property)                  # Gallery interactions
track_property_share(property, platform:)     # Social shares
track_property_favorite(property, action:)    # Favorites (add/remove)
```

**Note:** This concern is defined but NOT currently included in any active controller (grep shows only in comment examples). Ready for implementation.

---

## 2. Multi-Tenant Architecture

### 2.1 Tenant Scoping Model

**Primary Tenant Model:** `/app/models/pwb/website.rb`

```ruby
class Website < ApplicationRecord
  has_many :listed_properties, foreign_key: 'website_id'
  has_many :users
  has_many :user_memberships, dependent: :destroy
  has_many :members, through: :user_memberships
  has_many :contacts
  has_many :messages
  has_many :media
  has_one :subscription
  
  # Analytics specific
  # Ahoy visits/events associated via website_id
end
```

**Website Access Pattern:**
- Subdomain-based: `website.subdomain.example.com`
- Custom domain: `website.custom_domain`
- ID stored in requests via `Pwb::Current.website`

### 2.2 User Authentication

**File:** `/app/models/pwb/user.rb`

**Authentication Methods:**
1. **Devise** - Email/password authentication
2. **OAuth** - Facebook via OmniAuth
3. **Firebase** - Custom Pwb::FirebaseTokenVerifier

**User Model Properties:**
- Multi-website support via `user_memberships`
- Role-based access: `owner`, `admin`, standard user
- Onboarding state machine: lead → registered → email_verified → onboarding → active
- Sign-in tracking: count, timestamps, IP addresses (Devise :trackable)

**Key Methods:**
```ruby
admin_for?(website)         # Check admin role
role_for(website)          # Get role for website
accessible_websites        # List of active websites
onboarding_progress_percentage
```

### 2.3 Current Context Tracking

**File:** `/app/models/pwb/current.rb`

Global context carrier:
```ruby
Pwb::Current.website  # Active website for request
```

Used throughout Ahoy initialization and tracking logic to ensure multi-tenant isolation.

---

## 3. Frontend Architecture

### 3.1 JavaScript Framework

**Technology Stack:**
- **Framework:** Server-rendered ERB/Liquid (primary), no Vue.js
- **Interaction:** Stimulus.js via importmap-rails
- **Styling:** Tailwind CSS 4.x
- **UI Components:** Flowbite

**Note:** Vue.js is DEPRECATED (`app/frontend/DEPRECATED.md`)

### 3.2 Stimulus Controllers

**Location:** `/app/javascript/controllers/`

**Registered Controllers:**
- `contact_form_controller.js` - Form submission handling with AJAX
- `search_form_controller.js` - Search form interactions
- `search_controller.js` - Search results
- `search_header_controller.js` - Header search widget
- `map_controller.js` - Property map interactions
- `gallery_controller.js` - Photo gallery navigation
- `filter_controller.js` - Filter UI interactions
- `location_picker_controller.js` - Location selection
- `currency_selector_controller.js` - Currency switcher
- `dropdown_controller.js` - Dropdown menus
- `tabs_controller.js` - Tab navigation
- `toggle_controller.js` - Toggle switches
- `theme_palette_controller.js` - Theme customization
- `skeleton_controller.js` - Loading states

**Import Map:** `/config/importmap.rb`
- @hotwired/stimulus (preloaded)
- @rails/ujs for AJAX (replaces jQuery)
- All controllers registered via `pin_all_from "app/javascript/controllers"`

### 3.3 Asset Pipeline

**Asset Compilation:**
- Tailwind CSS compiled to: `/app/assets/builds/tailwind-default.css` (+ theme variants)
- JavaScript via Importmap (CDN-friendly)
- Critical CSS extraction via `/scripts/extract-critical-css.js`

**Build Configuration:**
- `package.json` with npm scripts for Tailwind compilation
- Support for multiple theme variants: default, bologna, brisbane, barcelona, biarritz
- Production minification support

### 3.4 Layout Structure

**Key Layouts:**
- `/app/views/layouts/tenant_admin.html.erb` - Admin dashboard
- `/app/views/layouts/site_admin.html.erb` - Platform admin
- `/app/views/layouts/pwb/` - Public-facing layouts (devise, signup, setup)
- `/app/views/layouts/widget.html.erb` - Embeddable widgets

**Admin Layout Details:**
```erb
<!-- tenant_admin.html.erb -->
- Alpine.js for state management (sidebar toggle)
- Flowbite for UI components
- Stimulus.js via importmap
- Tailwind CSS stylesheet
```

---

## 4. Key User Actions to Track

### 4.1 Public User Actions (Website Visitors)

**Property Browsing:**
- ✅ Property view (tracked via track_property_view)
- ✅ Property search (tracked via track_property_search)
- ✅ Gallery/photo view (tracked via track_gallery_view)
- ✅ Property share to social (tracked via track_property_share)
- ✅ Save/favorite property (tracked via track_property_favorite)

**Inquiry & Contact:**
- ✅ Contact form opened (tracked via track_contact_form_opened)
- ✅ Inquiry submitted (tracked via track_inquiry)
- Page views (automatic via after_action :track_page_view)

**Site Navigation:**
- Landing page views
- Blog/content views
- Map interactions (potential custom tracking)
- Filter/search refinement clicks

### 4.2 Authenticated User Actions (Admin/Tenant Actions)

**Currently NOT tracked by Ahoy** (excluded from `/config/initializers/ahoy.rb`):
- Admin dashboard views
- Property management (create, edit, delete)
- User management
- Settings changes
- Email template edits
- Page/content edits

**Potential PostHog Tracking Opportunities:**
- Account creation completion (sign-up flow milestones)
- First property uploaded
- First inquiry received
- Website customization (theme, colors, fonts)
- Settings configuration
- User role changes
- Email configuration
- Domain custom domain setup
- Subscription plan creation/changes
- Admin invitations sent
- API/integration setup

### 4.3 Subscription & Billing Events

**Files:** 
- `/app/models/pwb/subscription.rb`
- `/app/models/pwb/subscription_event.rb`
- `/app/models/pwb/plan.rb`

**Subscription States:**
```
trialing → active/expired
active → past_due → active/canceled
canceled → active (resubscribe)
```

**Trackable Events:**
- Subscription created (trial start)
- Trial ending (days_until_expiry)
- Subscription activated (trial → active)
- Payment status changes
- Plan upgrades/downgrades
- Subscription cancellation

### 4.4 Authentication & Security Events

**File:** `/app/models/pwb/auth_audit_log.rb`

Currently logs:
- User registration
- Account lockouts
- Account unlocks
- Authentication attempts

**Available for PostHog:**
- Sign-in events (with device, location)
- Sign-up completion
- Email verification
- Password resets
- OAuth authentication
- Failed login attempts
- Account lockout/unlock

---

## 5. Database Schema Insights

### 5.1 Key Tables

**Multi-Tenant Tables:**
```
pwb_websites          # Tenant root (id: primary key)
  ├── subdomain       # URL identifier
  ├── custom_domain   # Alternative domain
  ├── theme_name      # Selected theme
  ├── seed_pack_name  # Data template used
  └── provisioning_state, subscription_id, etc.

pwb_users             # Platform users (cross-tenant via memberships)
  ├── email           # Unique
  ├── encrypted_password
  ├── firebase_uid    # OAuth
  ├── onboarding_state (AASM state machine)
  └── sign_in_count, last_sign_in_at, etc.

pwb_user_memberships  # Multi-website access control
  ├── user_id
  ├── website_id
  ├── role (owner, admin, member)
  └── active (boolean)

ahoy_visits          # Per-website visitor sessions
  ├── website_id
  ├── user_id (optional)
  ├── visitor_token, visit_token
  ├── referrer, utm_*
  └── location, device info

ahoy_events          # Per-website events
  ├── website_id
  ├── visit_id (optional)
  ├── name, properties (JSONB)
  └── time
```

### 5.2 Denormalized View

**File:** `/app/models/pwb/listed_property.rb`

- Materialized view: `pwb_properties`
- Combines realty_assets + sale_listings + rental_listings
- Optimized for fast property search/display
- Tenant-scoped by `website_id`

---

## 6. Existing Monitoring & Logging

### 6.1 Error Tracking (Sentry)

**File:** `/config/initializers/sentry.rb`

**Configured:**
- DSN via `SENTRY_DSN` env var
- Environment, release, traces sampling (10% default)
- PII handling configurable
- Tenant context injection:
  ```ruby
  event.tags[:tenant_subdomain] = Pwb::Current.website.subdomain
  event.tags[:tenant_id] = Pwb::Current.website.id
  ```
- User context:
  ```ruby
  event.user = { id: current_user.id, email: current_user.email }
  ```
- Filtered exceptions (routing errors, auth token errors)

**Performance Monitoring:**
- Traces sampling: 0.1 (production) to 1.0 (development)
- Profile sampling: 0.1 (10% of traces)

### 6.2 Structured Logging (Lograge)

**File:** `/config/initializers/lograge.rb`

**Output Format:** JSON (log aggregator friendly)

**Custom Payload:**
```json
{
  "timestamp": "ISO8601",
  "request_id": "...",
  "host": "...",
  "remote_ip": "...",
  "user_agent": "...",
  "tenant_subdomain": "...",
  "tenant_id": "...",
  "user_id": "...",
  "user_email": "..."
}
```

**Ignored Paths:** Health checks, asset requests

---

## 7. PostHog Integration Opportunities

### 7.1 **Recommended Approach: Hybrid Strategy**

**Continue Ahoy For:**
- ✅ Public-facing analytics (visitor tracking, property views, inquiries)
- ✅ Conversion funnels (view → contact → inquiry)
- ✅ Traffic source attribution
- ✅ Basic SEO/organic tracking

**Add PostHog For:**
- ✅ Product analytics (admin dashboard usage)
- ✅ User identification across tenants
- ✅ Feature adoption tracking
- ✅ User journeys (onboarding flow)
- ✅ Admin action tracking
- ✅ Subscription/billing correlation
- ✅ Custom event properties and cohort analysis
- ✅ Real-time alerts (signup drops, quota overages)

### 7.2 **PostHog SDK Implementation Points**

**Server-Side (Ruby):**
```ruby
# In ApplicationController or relevant base controller
def posthog_client
  @posthog_client ||= PostHog::Client.new(
    api_key: ENV['POSTHOG_API_KEY'],
    personal_api_key: ENV['POSTHOG_PERSONAL_API_KEY']
  )
end

# Track authenticated admin actions
posthog_client.capture(
  distinct_id: current_user.id,
  event: 'property_created',
  properties: {
    website_id: current_website.id,
    property_type: property.prop_type_key,
    price_range: determine_price_range(property),
    user_role: current_user.role_for(current_website),
    $set: {
      email: current_user.email,
      company: current_website.company_display_name
    }
  }
)
```

**Client-Side (JavaScript):**
```javascript
// In Stimulus controllers or main JS
if (window.posthog) {
  posthog.capture('inquiry_form_submitted', {
    property_id: propertyId,
    property_price: propertyPrice,
    inquiry_type: inquiryType
  })
}
```

### 7.3 **Key User Segments for Tracking**

**Segment 1: Public Visitors (Anonymous)**
```
Property Hunters
├── Properties Viewed
├── Searches Executed
├── Inquiry Rate
└── Time on Site
```

**Segment 2: Authenticated Users (Tenant Admins)**
```
Website Owners
├── Active Website Editing
├── Property Management
├── Team Invitations
├── Settings Configuration
└── Subscription Tier
```

**Segment 3: Multi-Website Users**
```
Platform Power Users
├── Websites Managed
├── Cross-website Actions
├── API Integration Usage
└── Team Size
```

### 7.4 **Feature Adoption Tracking**

**New Features to Monitor:**
- Dark mode toggle (`dark_mode_setting`)
- Custom domain setup (`custom_domain_verified`)
- Theme selection and customization
- Multi-language support (`supported_locales`)
- Currency configuration
- Search filter customization
- Widget embedding

### 7.5 **Conversion Funnel Analysis**

**Primary Conversion (Visitor):**
```
Landing Page View
  ↓
Property Search
  ↓
Property Detail View
  ↓
Contact Form Open
  ↓
Inquiry Submission
```

**Secondary Conversion (Admin):**
```
Sign-up
  ↓
Email Verification
  ↓
Website Creation
  ↓
First Property Upload
  ↓
Settings Configuration
  ↓
Subscription Activation
```

---

## 8. Technical Implementation Roadmap

### Phase 1: Setup & Infrastructure
- [ ] Add `posthog-ruby` gem to Gemfile
- [ ] Create `/config/initializers/posthog.rb`
- [ ] Add environment variables: `POSTHOG_API_KEY`, `POSTHOG_HOST`
- [ ] Create base tracking service: `Pwb::PostHogService`
- [ ] Add PostHog SDK to frontend via importmap or CDN

### Phase 2: Authentication & User Identification
- [ ] Identify current_user in PostHog on login
- [ ] Capture user properties: role, websites_count, subscription_tier
- [ ] Implement super-user mode identification
- [ ] Add website context to all events

### Phase 3: Admin Action Tracking
- [ ] Create event tracker for property CRUD operations
- [ ] Track settings/configuration changes
- [ ] Monitor admin dashboard page views
- [ ] Capture user management events (invitations, role changes)

### Phase 4: Onboarding & Activation
- [ ] Track signup flow completion rates
- [ ] Measure time to first property upload
- [ ] Monitor subscription adoption
- [ ] Correlate with trial conversion

### Phase 5: Subscription & Business Metrics
- [ ] Track plan changes
- [ ] Correlate features used with tier
- [ ] Monitor trial → paid conversion
- [ ] Analyze churn indicators

### Phase 6: Integration & Dashboards
- [ ] Create PostHog dashboards for executive reporting
- [ ] Set up Slack alerts for anomalies
- [ ] Export cohort analysis to CRM
- [ ] Create retention dashboards

---

## 9. Security & Privacy Considerations

### 9.1 **Multi-Tenant Data Isolation**

**Critical:** Ensure PostHog events don't leak cross-tenant data

```ruby
# Always include website_id to ensure analytics isolation
posthog_client.capture(
  distinct_id: "#{current_user.id}_#{current_website.id}",  # Scoped ID
  properties: {
    website_id: current_website.id,  # Explicit scope
    # ... other properties
  }
)
```

### 9.2 **Privacy Compliance**

- ✅ IP masking already enabled in Ahoy
- ✅ PII handling configured in Sentry
- PostHog should NOT track:
  - Full email addresses of non-authenticated users
  - Password-related data
  - Credit card or payment method details
  - API keys or tokens

### 9.3 **PII in User Identification**

```ruby
# Safe: Use hashed or pseudo-anonymous ID
posthog_client.identify(
  distinct_id: current_user.id,  # Use numeric ID, not email
  properties: {
    email: current_user.email,  # Set separately if needed
    # ... other properties
  }
)
```

### 9.4 **Access Control**

- Only tenant admins should see their own analytics
- Multi-website users see cross-website patterns but not other users' data
- Platform admins have access to aggregated trends only

---

## 10. Comparison with Existing Solutions

### Ahoy Matey vs PostHog

| Feature | Ahoy Matey | PostHog | Use Case |
|---------|-----------|---------|----------|
| **Visitor Tracking** | ✅ Native | ✅ Yes | Public site analytics |
| **Event Properties (JSONB)** | ✅ Yes | ✅ Yes | Rich event data |
| **User Identification** | Limited | ✅ Strong | Admin action tracking |
| **Cohort Analysis** | Manual queries | ✅ Built-in | User segmentation |
| **User Journeys** | Complex queries | ✅ Built-in | Funnel visualization |
| **Retention Curves** | Manual queries | ✅ Built-in | Churn analysis |
| **Real-time Dashboards** | Limited | ✅ Yes | Monitoring |
| **Feature Flags** | ✗ No | ✅ Yes | A/B testing, rollouts |
| **Session Replay** | ✗ No | ✅ Yes (enterprise) | UX debugging |
| **Data Ownership** | ✅ Full (self-hosted) | ✅ Self-hosted option | Compliance |

### Sentry vs PostHog

| Feature | Sentry | PostHog | Use Case |
|---------|--------|---------|----------|
| **Error Tracking** | ✅ Focused | ✅ Events only | Bug detection |
| **Performance Tracing** | ✅ Yes | ✅ Limited | App performance |
| **Business Metrics** | ✗ No | ✅ Yes | Product KPIs |
| **User Context** | ✅ Yes | ✅ Yes | Debugging |
| **Alert/Notifications** | ✅ Yes | ✅ Yes | Issue notification |

---

## 11. Potential Challenges & Solutions

### 11.1 **Multi-Tenant Event Isolation**

**Challenge:** Ensuring property search events from tenant A don't appear in tenant B's dashboard

**Solution:**
```ruby
# Always include website_id in event properties
# Use scoped distinct_id: "user_#{id}_website_#{website_id}"
# Filter PostHog dashboard by website_id cohort
```

### 11.2 **Admin vs Visitor Tracking Separation**

**Challenge:** Admin actions (/admin, /site_admin) excluded from Ahoy but needed for PostHog

**Solution:**
```ruby
# Create separate PostHog events from admin controllers
# Use `event_source: 'admin'` to differentiate
# Keep Ahoy exclusions for performance
```

### 11.3 **Performance Impact**

**Challenge:** PostHog SDK overhead on request handling

**Solution:**
- Use async event batching
- Only track high-value events in production
- Use sampling for high-traffic properties (searches)
- Cache user context to reduce API calls

### 11.4 **OAuth/Firebase User Context**

**Challenge:** How to identify OAuth users (Facebook) or Firebase users in PostHog?

**Solution:**
```ruby
# For OAuth users, use user_id as distinct_id
# Store OAuth provider info in PostHog user properties
# For Firebase users, use firebase_uid if available

posthog_client.identify(
  distinct_id: current_user.id,
  properties: {
    auth_method: 'facebook',  # or 'email', 'firebase'
    firebase_uid: current_user.firebase_uid
  }
)
```

---

## 12. Recommended PostHog Events (Comprehensive List)

### 12.1 **Public Visitor Events**
```
page_viewed               # Page load (keep from Ahoy)
property_searched        # Search executed (keep from Ahoy)
property_viewed          # Property detail page (keep from Ahoy)
property_filtered        # Filter applied
inquiry_submitted        # Contact form submitted (keep from Ahoy)
contact_form_opened      # Form interaction (keep from Ahoy)
gallery_opened           # Photo gallery opened
property_shared          # Share to social (keep from Ahoy)
property_saved           # Add to favorites (keep from Ahoy)
currency_changed         # Currency selection
language_changed         # Language preference
map_interaction          # Map pan/zoom
```

### 12.2 **Admin Action Events**
```
website_created          # New website setup
property_created         # Property listed
property_updated         # Property edited
property_deleted         # Property removed
property_bulk_import     # Batch upload
theme_customized         # Theme change
page_edited              # Content page edited
template_created         # Email template created
domain_configured        # Custom domain verified
api_key_generated        # API integration setup
user_invited             # Team member invited
user_role_changed        # Permission change
subscription_created     # Subscription activated
subscription_upgraded    # Plan change
settings_saved           # Configuration change
```

### 12.3 **Platform Events**
```
signup_started           # Registration page viewed
email_verified           # Email confirmation
onboarding_completed     # Signup wizard finished
trial_started            # Trial period begins
trial_expiring_soon      # X days before expiry
payment_successful       # Subscription payment
payment_failed           # Payment declined
trial_converted          # Conversion to paid
trial_expired            # Trial ended without conversion
subscription_canceled    # Churn event
account_locked           # Security lockout
```

---

## 13. Sample PostHog Implementation

### 13.1 **Service Class**
```ruby
# app/services/pwb/posthog_service.rb
module Pwb
  class PostHogService
    def initialize(user:, website: nil, request: nil)
      @user = user
      @website = website || Pwb::Current.website
      @request = request
    end

    def capture_admin_action(event_name, properties = {})
      return unless @user && @website

      client.capture(
        distinct_id: user_distinct_id,
        event: event_name,
        properties: {
          website_id: @website.id,
          website_subdomain: @website.subdomain,
          user_role: @user.role_for(@website),
          **properties
        }
      )
    end

    def identify_user(properties = {})
      return unless @user

      client.identify(
        distinct_id: @user.id,
        properties: {
          email: @user.email,
          name: "#{@user.first_names} #{@user.last_names}".strip,
          websites_count: @user.websites.count,
          created_at: @user.created_at.to_i,
          **properties
        }
      )
    end

    private

    def user_distinct_id
      "#{@user.id}_#{@website&.id}"
    end

    def client
      @client ||= PostHog::Client.new(
        api_key: ENV['POSTHOG_API_KEY']
      )
    end
  end
end
```

### 13.2 **Usage in Controllers**
```ruby
class TenantAdmin::PropsController < TenantAdminController
  def create
    @property = @website.listed_properties.build(prop_params)
    
    if @property.save
      Pwb::PostHogService.new(user: current_user, website: current_website)
        .capture_admin_action('property_created', {
          property_type: @property.prop_type_key,
          for_sale: @property.for_sale?,
          for_rent: @property.for_rent?
        })
      
      redirect_to @property
    else
      render :new
    end
  end
end
```

---

## 14. Questions for Implementation Planning

1. **Budget:** Self-hosted PostHog or managed cloud instance?
2. **Data Retention:** How long to keep analytics data (90/180/365 days)?
3. **Event Volume:** Estimated events/month from admin actions?
4. **Real-time Requirements:** Need real-time dashboards or batch analysis sufficient?
5. **Compliance:** GDPR/privacy laws requiring data residency? (affects self-hosted vs cloud)
6. **Team Access:** Who should have dashboard access? (all admins, marketing only, executives?)
7. **Integration:** Need to sync with CRM/email platform (Segment, Zapier)?
8. **Feature Flags:** Priority use case (A/B testing, gradual rollouts, kill switches)?

---

## 15. Summary

### Strengths of Current Setup
- ✅ Ahoy Matey provides solid visitor analytics foundation
- ✅ Multi-tenant architecture properly isolated by website_id
- ✅ Comprehensive event properties captured in JSONB
- ✅ Structured logging and error tracking (Sentry) already implemented
- ✅ User authentication flows well-documented (Devise, OAuth, Firebase)
- ✅ Frontend architecture clean (Stimulus.js, no jQuery)

### Gaps PostHog Would Fill
- ⚠️ Admin action tracking (currently excluded from Ahoy)
- ⚠️ User identification and cohort analysis
- ⚠️ Feature adoption metrics
- ⚠️ Retention/churn analysis
- ⚠️ Real-time dashboards and alerts
- ⚠️ User journey visualization

### Implementation Priority
1. **High:** Admin action tracking service
2. **High:** User identification and properties
3. **Medium:** Feature adoption dashboards
4. **Medium:** Subscription correlation events
5. **Low:** Real-time alerting (can start with Slack integration)

### Timeline Estimate
- **Phase 1-2 (Setup):** 1-2 weeks
- **Phase 3-4 (Core Events):** 2-3 weeks
- **Phase 5-6 (Dashboards):** 1-2 weeks
- **Total:** 4-7 weeks for full implementation

---

## Appendix: File Reference

**Analytics Core:**
- `/app/services/pwb/analytics_service.rb` - Main analytics service
- `/app/controllers/concerns/trackable.rb` - Tracking helpers
- `/app/models/ahoy/visit.rb` - Visit model with scopes
- `/app/models/ahoy/event.rb` - Event model with scopes
- `/config/initializers/ahoy.rb` - Ahoy configuration
- `/app/views/pwb/_analytics.html.erb` - Frontend tracking

**Multi-Tenant:**
- `/app/models/pwb/website.rb` - Tenant model
- `/app/models/pwb/user.rb` - User authentication
- `/app/models/pwb/current.rb` - Request context

**Logging & Monitoring:**
- `/config/initializers/sentry.rb` - Error tracking
- `/config/initializers/lograge.rb` - Structured logging

**Frontend:**
- `/app/javascript/controllers/` - Stimulus controllers
- `/config/importmap.rb` - Asset imports
- `/app/views/layouts/tenant_admin.html.erb` - Admin layout

**Database:**
- `/db/migrate/20251216210000_create_ahoy_visits_and_events.rb` - Schema
- `/app/models/pwb/listed_property.rb` - Denormalized property view
