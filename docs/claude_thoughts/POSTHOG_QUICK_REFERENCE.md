# PostHog Integration - Quick Reference

## Architecture At-a-Glance

```
PropertyWebBuilder (Multi-Tenant SaaS)
│
├─ PUBLIC SITE (Visitor Analytics)
│  ├─ Ahoy.js (existing)        → visitor tracking, properties, inquiries
│  └─ PostHog? (optional)       → visitor cohorts, journey analysis
│
└─ ADMIN DASHBOARD (Product Analytics)
   ├─ Sentry                     → error tracking, performance
   ├─ Lograge                    → structured request logs
   └─ PostHog (recommended)      → admin actions, feature adoption, retention
```

## Key Fact: Multi-Tenant Isolation

**CRITICAL:** All Ahoy events are scoped by `website_id`

```ruby
# Ahoy tracks visitors per-website
Ahoy::Visit.for_website(website_id)
Ahoy::Event.for_website(website_id)

# PostHog should do the same
posthog.capture(
  distinct_id: "user_#{user.id}_website_#{website.id}",
  properties: { website_id: website.id, ... }
)
```

## Current Event Types

### Tracked by Ahoy (✅)
```
page_viewed            # page load
property_viewed        # property details
property_searched      # search query
inquiry_submitted      # contact form
contact_form_opened    # form interaction
gallery_viewed         # photo gallery
property_shared        # social share
property_favorited     # save property
```

### NOT Tracked (🚫)
- Admin actions (excluded from /admin, /site_admin paths)
- Settings changes
- Property management (CRUD)
- User management
- Email configuration
- Subscription changes

## Stimulus.js Controllers

All interaction tracking runs through Stimulus:
```
gallery_controller       → gallery_viewed
contact_form_controller  → contact_form_opened
search_form_controller   → property_searched
... + 10 more
```

## Database Tables

```
ahoy_visits
├─ website_id (FK)
├─ user_id (FK, optional - logged-in visitors)
├─ visitor_token (cookie-based tracking)
├─ referrer, utm_*, device, location
└─ started_at

ahoy_events
├─ website_id (FK)
├─ visit_id (FK, optional)
├─ name (string: event type)
├─ properties (JSONB: flexible data)
└─ time
```

## User Model

```ruby
Pwb::User
├─ email, password (Devise)
├─ firebase_uid (OAuth)
├─ onboarding_state (AASM: lead → registered → verified → onboarding → active)
├─ sign_in_count, last_sign_in_at (Devise :trackable)
└─ user_memberships [website_id, role: owner/admin/member]
```

## Website Model (Tenant)

```ruby
Pwb::Website
├─ subdomain (primary identifier)
├─ custom_domain (optional)
├─ theme_name
├─ subscription (status: trialing/active/past_due/canceled)
└─ users (through memberships)
```

## Authentication Methods

1. **Devise** (email/password) - primary
2. **OAuth** (Facebook) - via OmniAuth
3. **Firebase** - custom Pwb::FirebaseTokenVerifier

## Request Context

```ruby
# Global context carrier
Pwb::Current.website  # Active tenant for request
```

## Current Analytics Service

**File:** `/app/services/pwb/analytics_service.rb`

```ruby
analytics = Pwb::AnalyticsService.new(website, period: 30.days)

# Queries
analytics.overview                    # dashboard metrics
analytics.visits_by_day              # time series
analytics.property_views_by_day
analytics.inquiries_by_day
analytics.top_properties(limit: 10)  # ranked content
analytics.top_pages(limit: 10)
analytics.top_searches(limit: 10)
analytics.traffic_sources             # referral domains
analytics.utm_campaigns
analytics.visitors_by_country
analytics.device_breakdown
analytics.browser_breakdown
analytics.inquiry_funnel              # conversion rates
analytics.funnel_conversion_rates
analytics.real_time_visitors          # last 30 min
analytics.real_time_page_views
```

## Conversion Funnel (Visitor)

```
Landing Page View
    ↓ (70%)
Property Search/Browse
    ↓ (60%)
Property Detail View
    ↓ (30%)
Contact Form Open
    ↓ (70%)
Inquiry Submitted
```

## Key Properties for Events

### Property View Events
```ruby
{
  property_id: 123,
  property_reference: "ABC-123",
  property_type: "sale" | "rental" | "unknown",
  price: 250000,  # in cents
  bedrooms: 3,
  bathrooms: 2,
  city: "Barcelona",
  region: "Catalonia"
}
```

### Search Events
```ruby
{
  query: "3 bedroom apartment Barcelona",
  property_type: "sale" | "rental",
  min_price: 100000,
  max_price: 500000,
  bedrooms: 3,
  location: "Barcelona",
  results_count: 47
}
```

### Inquiry Events
```ruby
{
  property_id: 123,
  source: "contact_form" | "inquiry_button" | "...",
  has_phone: true,
  message_length: 245
}
```

## Existing Monitoring

### Sentry
- Error tracking
- Performance tracing (traces_sample_rate: 10%)
- Tenant context injection

### Lograge
- JSON structured logging
- Request/response logging
- Tenant + user context

## Layout & Frontend Stack

**Tech:**
- Server-rendered ERB (no Vue.js - deprecated)
- Stimulus.js (importmap-based, no jQuery)
- Tailwind CSS 4.x
- Flowbite components
- Alpine.js for state (mobile sidebar)

**Asset Loading:**
- Ahoy.js loaded async after DOMContentLoaded
- Stimulus controllers preloaded via importmap
- Tailwind compiled to `/app/assets/builds/tailwind-*.css`

## Admin Areas

```
/site_admin/*           # Platform-wide admin (all tenants)
/admin/*                # Legacy admin (TBD)
/tenant_admin/*         # Website-specific admin dashboard
```

**Controllers:**
- Props, Pages, Settings, Users, Email Templates, Domains, Subscriptions, etc.

## Controller Concern (Ready to Use)

**File:** `/app/controllers/concerns/trackable.rb`

Not currently included in any controller, but defines:
```ruby
track_page_view                          # auto via after_action
track_property_view(property)
track_property_search(params, count)
track_inquiry(message, property:)
track_contact_form_opened(property:)
track_gallery_view(property)
track_property_share(property, platform:)
track_property_favorite(property, action:)
```

## PostHog Integration Point Options

### Option 1: In ApplicationController
```ruby
class ApplicationController < ActionController::Base
  def posthog_client
    @posthog_client ||= PostHog::Client.new(api_key: ENV['POSTHOG_API_KEY'])
  end
  
  # Auto-identify logged-in users
  before_action :identify_user
  
  private
  
  def identify_user
    return unless current_user
    posthog_client.identify(distinct_id: current_user.id, properties: {...})
  end
end
```

### Option 2: Service Class
```ruby
Pwb::PostHogService.new(user: current_user, website: current_website)
  .capture_admin_action('property_created', {...})
```

### Option 3: Ahoy Integration
```ruby
# Extend Ahoy::Store to also send to PostHog
class Ahoy::Store < Ahoy::DatabaseStore
  def track_event(data)
    super(data)
    # Also send to PostHog
    PostHog.capture(...)
  end
end
```

## Common PostHog Properties to Set

### User-Level ($set)
```ruby
{
  $set: {
    email: user.email,
    name: user.full_name,
    websites_managed: user.websites.count,
    subscription_tier: subscription.plan.name,
    created_at: user.created_at.to_i
  }
}
```

### Event-Level
```ruby
{
  website_id: 123,
  website_subdomain: 'mysite',
  user_role: 'owner',  # or 'admin', 'member'
  timestamp: Time.current.to_i,
  # ... custom properties
}
```

## Tracking Ideas (Ranked by Value)

| Priority | Event | Reason |
|----------|-------|--------|
| 🔴 High | property_created | Engagement metric |
| 🔴 High | signup_completed | Activation metric |
| 🔴 High | first_property_uploaded | Milestone |
| 🔴 High | inquiry_received | Conversion |
| 🔴 High | subscription_activated | Revenue |
| 🟠 Medium | settings_configured | Customization |
| 🟠 Medium | theme_changed | Feature adoption |
| 🟠 Medium | user_invited | Collaboration |
| 🟠 Medium | trial_ending_soon | Churn risk |
| 🟢 Low | page_view (admin) | Engagement detail |

## Testing PostHog Events

```ruby
# In console
client = PostHog::Client.new(api_key: 'YOUR_KEY')
client.capture(
  distinct_id: 'test_user_123',
  event: 'test_event',
  properties: { test: true }
)
```

## Environment Variables Needed

```bash
POSTHOG_API_KEY=phc_xxxx                    # PostHog API key
POSTHOG_PERSONAL_API_KEY=phc_xxxx           # For server-side operations (optional)
POSTHOG_HOST=https://us.posthog.com         # Default, or self-hosted URL
```

## Performance Considerations

- Use async batching (PostHog default)
- Avoid tracking in hot loops
- Sample high-volume events (e.g., searches: 10% sample rate)
- Cache user properties (don't re-identify every request)

## Privacy & Compliance

- ✅ IP masking enabled in Ahoy
- ✅ Do not track passwords or tokens
- ✅ Do not track credit card details
- ✅ Use user ID, not email, as distinct_id
- ⚠️ GDPR: Consider data residency (self-hosted PostHog for compliance)

---

**Full Analysis:** `/docs/claude_thoughts/POSTHOG_INTEGRATION_ANALYSIS.md`
