# PostHog Integration - Architecture Diagrams

## 1. Current Analytics Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PROPERTYWEB BUILDER                          │
│                      Multi-Tenant SaaS                           │
└─────────────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │   Frontend   │
                    │ (Browser UI) │
                    └──────┬───────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
    ┌────▼─────────┐              ┌─────────▼──────┐
    │  Ahoy.js     │              │ Stimulus.js    │
    │ (Visitor     │              │ (Interactions) │
    │  Tracking)   │              └────────────────┘
    └────┬─────────┘
         │
         │ POST /ahoy/visits
         │ POST /ahoy/events
         │
    ┌────▼──────────────────────────────────────────┐
    │         Rails Backend                         │
    │  ┌──────────────────────────────────────────┐ │
    │  │ ApplicationController                    │ │
    │  │ - Pwb::Current.website (tenant context) │ │
    │  │ - current_user (authentication)         │ │
    │  └──────────────────────────────────────────┘ │
    │  ┌──────────────────────────────────────────┐ │
    │  │ Ahoy Store (Custom)                      │ │
    │  │ - track_visit(data)                      │ │
    │  │ - track_event(data)                      │ │
    │  │ - Inject website_id for multi-tenancy   │ │
    │  └──────────────────────────────────────────┘ │
    │  ┌──────────────────────────────────────────┐ │
    │  │ Analytics Service                        │ │
    │  │ - Pwb::AnalyticsService.new(website)    │ │
    │  │ - Queries aggregated analytics          │ │
    │  └──────────────────────────────────────────┘ │
    └────┬──────────────────────────────────────────┘
         │
    ┌────┴───────────────────────────────────────────┐
    │                                                │
    ▼                                                ▼
┌──────────────────┐                      ┌──────────────────┐
│  PostgreSQL      │                      │   Redis          │
│                  │                      │ (Caching)        │
│  ahoy_visits     │                      │                  │
│  ahoy_events     │                      │ rails_performance│
│  pwb_websites    │                      │                  │
│  pwb_users       │                      └──────────────────┘
│  ...             │
└──────────────────┘

    Additional Services (Optional):
    ┌─────────────────────────────────────────┐
    │ Sentry (Error Tracking)                 │
    │ - Rails exceptions, performance traces  │
    │ - Tenant context: subdomain, user_id    │
    └─────────────────────────────────────────┘

    ┌─────────────────────────────────────────┐
    │ Lograge (Structured Logging)            │
    │ - JSON request logs                     │
    │ - Tenant + user context                 │
    └─────────────────────────────────────────┘
```

---

## 2. Proposed PostHog Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PROPERTYWEB BUILDER                          │
│                      Multi-Tenant SaaS                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐         ┌─────────────────────────┐
│   PUBLIC SITE           │         │   ADMIN DASHBOARD       │
│   (Visitor Analytics)   │         │   (Product Analytics)   │
└────────────┬────────────┘         └────────────┬────────────┘
             │                                   │
        ┌────▼──────────┐                ┌──────▼────────┐
        │  Ahoy.js      │                │ Stimulus.js   │
        │  (Visitors)   │                │ (Interactions)│
        └────┬──────────┘                └──────┬────────┘
             │                                   │
        ┌────▼──────────────────────────────────▼────┐
        │         Rails Backend                      │
        │  ┌────────────────────────────────────┐   │
        │  │ ApplicationController              │   │
        │  │ - identify_user (PostHog)          │   │
        │  │ - posthog_client initialization   │   │
        │  └────────────────────────────────────┘   │
        │                                            │
        │  ┌────────────────────────────────────┐   │
        │  │ TenantAdminController              │   │
        │  │ - PostHog event capture            │   │
        │  │ - Admin actions tracking           │   │
        │  └────────────────────────────────────┘   │
        │                                            │
        │  ┌────────────────────────────────────┐   │
        │  │ Ahoy Store (Custom)                │   │
        │  │ - track_visit()                    │   │
        │  │ - track_event()                    │   │
        │  │ - website_id injection             │   │
        │  └────────────────────────────────────┘   │
        │                                            │
        │  ┌────────────────────────────────────┐   │
        │  │ PostHogService (NEW)               │   │
        │  │ - capture_admin_action()           │   │
        │  │ - identify_user()                  │   │
        │  │ - Multi-tenant scoping             │   │
        │  └────────────────────────────────────┘   │
        └────┬──────────────┬──────────────────┬────┘
             │              │                  │
    ┌────────▼────┐ ┌──────▼────────┐ ┌──────▼────────┐
    │   Ahoy       │ │ PostHog       │ │ Sentry        │
    │ /ahoy/events │ │ /capture      │ │ (Exceptions)  │
    └────────┬────┘ └──────┬────────┘ └──────┬────────┘
             │              │                  │
    ┌────────▼──────────────▼──────────────────▼────┐
    │            Data Layer                         │
    │                                               │
    │  ┌─────────────────┐      ┌──────────────┐   │
    │  │ PostgreSQL      │      │ PostHog API  │   │
    │  │                 │      │              │   │
    │  │ ahoy_visits     │      │ (Cloud or    │   │
    │  │ ahoy_events     │      │  Self-hosted)    │
    │  │ pwb_websites    │      │              │   │
    │  │ pwb_users       │      └──────────────┘   │
    │  │ pwb_subscriptions
    │  └─────────────────┘
    └────────────────────────────────────────────────┘
```

---

## 3. Multi-Tenant Event Flow (Detail)

```
User visits property page on website "example.com" (website_id=42)
│
├─ Browser
│  └─ Ahoy.js generates visitor_token (cookie-based)
│
├─ Rails handles GET /property/123
│  │
│  ├─ Pwb::Current.website = Website.find_by(id: 42)
│  │
│  ├─ PropsController#show
│  │  ├─ @property = Pwb::ListedProperty.find(123)
│  │  ├─ PostHog (optional): posthog.identify(user_id)
│  │  └─ after_action :track_page_view
│  │
│  └─ track_page_view (from Trackable concern)
│     └─ ahoy.track('page_viewed', {...})
│
├─ Ahoy Store intercepts
│  ├─ Custom Store.track_event(data)
│  │  └─ data[:website_id] = Pwb::Current.website.id  ← CRITICAL
│  │
│  └─ Inserts into ahoy_events table
│     {
│       website_id: 42,
│       visit_id: <visit_id>,
│       name: 'page_viewed',
│       properties: JSON.stringify({
│         page_type: 'props',
│         action: 'show',
│         path: '/property/123',
│         page_title: 'Beautiful 3BR Barcelona'
│       }),
│       time: Time.current
│     }
│
└─ Analytics
   ├─ Ahoy Dashboard: Sees data scoped to website_id=42 only
   └─ PostHog (future): Could also capture this event with website context

─────────────────────────────────────────────────────────────

If different user on website "other-site.com" (website_id=99):
- Ahoy event would have website_id=99
- Data is completely isolated in queries
- PostHog should use similar scoping: 
  distinct_id = "#{user.id}_#{website.id}"
```

---

## 4. Admin Action Tracking (PostHog-Only)

```
Admin user logs in to tenant admin dashboard
│
├─ GET /tenant_admin/dashboard (request_path starts with /admin)
│  ├─ Excluded from Ahoy (by config)
│  └─ ✗ Ahoy does not track this
│
└─ ApplicationController#identify_user
   ├─ Check if current_user exists
   └─ posthog.identify(
        distinct_id: current_user.id,
        properties: {
          email: current_user.email,
          websites_managed: user.websites.count,
          subscription_tier: subscription.plan.name,
          $set: { created_at: user.created_at.to_i }
        }
      )

─────────────────────────────────────────────────────────

Admin creates new property
│
├─ POST /tenant_admin/props
│  ├─ TenantAdmin::PropsController#create
│  └─ @property.save
│
└─ PostHog.new.capture_admin_action('property_created', {
     website_id: 42,
     property_type: 'sale',
     for_sale: true,
     for_rent: false,
     user_role: 'owner',
     properties_in_portfolio: 23  ← aggregate value
   })

─────────────────────────────────────────────────────────

Admin updates website settings
│
├─ PATCH /tenant_admin/settings/update
│  ├─ TenantAdmin::SettingsController#update
│  └─ @website.update(settings_params)
│
└─ PostHog.new.capture_admin_action('settings_updated', {
     website_id: 42,
     changed_fields: ['theme_name', 'palette_mode'],
     new_theme: 'barcelona'
   })

─────────────────────────────────────────────────────────

Admin subscribes to plan
│
├─ POST /tenant_admin/subscriptions
│  ├─ TenantAdmin::SubscriptionsController#create
│  └─ Pwb::Subscription.create(plan_id, website_id, status: 'active')
│
└─ PostHog.new.capture_admin_action('subscription_activated', {
     website_id: 42,
     plan_name: 'professional',
     plan_price: 29.99,
     billing_cycle: 'monthly',
     trial_days_remaining: 0,
     converted_from_trial: true
   })
```

---

## 5. Event Data Structure

### Ahoy Event (Database)

```sql
ahoy_events:
{
  id: 1,
  website_id: 42,        ← Multi-tenant scoping
  visit_id: 100,         ← Link to session
  name: 'property_viewed',
  properties: {
    "property_id": "123",
    "property_reference": "ABC-456",
    "property_type": "sale",
    "price": "250000",
    "bedrooms": "3",
    "city": "Barcelona"
  },
  time: 2024-12-29 14:32:00
}
```

### PostHog Event (Hybrid)

```json
{
  "event": "property_created",
  "properties": {
    "website_id": 42,
    "website_subdomain": "example-site",
    "user_role": "owner",
    "property_type": "sale",
    "for_sale": true,
    "for_rent": false,
    "user_role": "owner",
    "$set": {
      "email": "admin@example.com",
      "name": "Jane Smith",
      "websites_managed": 1,
      "created_at": 1700000000
    }
  },
  "distinct_id": "42_1",  ← user_id_website_id
  "timestamp": "2024-12-29T14:32:00Z"
}
```

---

## 6. Dashboard Data Flow

### Visitor Analytics (Ahoy)

```
Visitor Views Property
  ↓
Ahoy.js captures event
  ↓
POST /ahoy/events
  ↓
Ahoy Store (backend)
  ├─ Injects website_id
  ├─ Validates exclude rules
  └─ Inserts to ahoy_events
  ↓
PostgreSQL
  ↓
Analytics Service query
  ├─ Pwb::AnalyticsService.new(website).property_views_by_day
  └─ SELECT COUNT(*) WHERE website_id = 42 AND name = 'property_viewed'
  ↓
Admin dashboard displays chart
```

### Admin Analytics (PostHog)

```
Admin creates property
  ↓
TenantAdmin::PropsController#create
  ├─ property.save
  └─ posthog.capture('property_created', {...})
  ↓
POST https://posthog.example.com/capture
  ├─ API endpoint receives event
  ├─ Batches with other events
  └─ Processes asynchronously
  ↓
PostHog Dashboard / API
  ├─ Filter by website_id cohort
  ├─ Group by user_role
  ├─ Analyze retention curves
  └─ Create alerts (zero properties created in 7 days)
  ↓
Executive Dashboard
  ├─ Feature adoption metrics
  ├─ User journey funnels
  └─ Churn predictions
```

---

## 7. Integration Point: Trackable Concern

**Current State:** Defined but unused

```ruby
# app/controllers/concerns/trackable.rb
module Trackable
  after_action :track_page_view, if: :should_track?
  
  def track_page_view
    ahoy.track('page_viewed', page_view_properties)
  end
  
  def track_property_view(property)
    ahoy.track('property_viewed', {...})
  end
  
  # ... 7 more tracking methods
  
  def should_track?
    request.get? && !request.xhr? && Pwb::Current.website.present? && !admin_path?
  end
end
```

**To Enable:**
```ruby
class PublicPropsController < ApplicationController
  include Trackable  # Enable tracking
  
  def show
    @property = Pwb::ListedProperty.find(params[:id])
    track_property_view(@property)  # Automatic page_view, plus property details
  end
end
```

---

## 8. Conversion Funnel Flow

```
VISITOR JOURNEY (Ahoy tracking)

[1] Land on Site (UTM source: google)
    └─ page_viewed {'page_type': 'landing', ...}
       website_id: 42, visit_id: 100
       
[2] Search for Properties
    └─ property_searched {'query': '3 bedroom Barcelona', results_count: 47}
       website_id: 42, visit_id: 100
       
[3] Click Property Details (Property #123)
    └─ property_viewed {'property_id': 123, 'price': 250000, ...}
       website_id: 42, visit_id: 100
       
[4] Gallery interaction
    └─ gallery_viewed {'property_id': 123}
       website_id: 42, visit_id: 100
       
[5] Open Contact Form
    └─ contact_form_opened {'property_id': 123}
       website_id: 42, visit_id: 100
       
[6] Submit Inquiry
    └─ inquiry_submitted {'property_id': 123, 'phone': true, ...}
       website_id: 42, visit_id: 100

─────────────────────────────────────────────────────────────

Analytics View:
Conversions per step (for website #42):
  Step 1→2: 7/10 visits (70%)
  Step 2→3: 5/7 searches (71%)
  Step 3→4: 4/5 detail views (80%)
  Step 4→5: 2/4 gallery views (50%)  ← BOTTLENECK
  Step 5→6: 2/2 form opens (100%)

Recommendation: Improve gallery UX to increase 4→5 conversion
```

---

## 9. Service Architecture (PostHog Addition)

```
┌────────────────────────────────────────────────────────┐
│         Pwb::PostHogService (NEW)                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│  def initialize(user, website, request)               │
│  def capture_admin_action(event_name, properties)     │
│  def identify_user(properties)                        │
│  def track_subscription_event(event, subscription)    │
│                                                        │
│  private                                              │
│    - client initialization                           │
│    - multi-tenant scope enforcement                  │
│    - property validation                             │
│    - async batching                                  │
│                                                        │
└────────────────────────────────────────────────────────┘

Usage in Controllers:
─────────────────────

class TenantAdmin::PropsController < TenantAdminController
  def create
    @property = current_website.listed_properties.build(...)
    if @property.save
      Pwb::PostHogService.new(
        user: current_user,
        website: current_website,
        request: request
      ).capture_admin_action('property_created', {
        property_type: @property.prop_type_key,
        price_cents: @property.price_cents,
        for_sale: @property.for_sale?
      })
    end
  end
end
```

---

## 10. Data Isolation Guarantee

```
Scenario: Attacker tries to see other website's data
─────────────────────────────────────────────────────

GET /tenant_admin/dashboard?website_id=99

Rails routing:
  ├─ current_user loaded from session
  ├─ current_website determined from subdomain/host
  └─ Pwb::Current.website = website_id from host, NOT from params

Results:
  ├─ can_access_website?(website) checks user_memberships
  ├─ Ahoy queries scoped: .where(website_id: current_website.id)
  └─ PostHog events scoped: properties['website_id'] == current_website.id

Outcome:
  ✓ Cannot access analytics of website they don't own/admin
  ✓ Data is impossible to mix (app-level + query-level scoping)
```

---

## 11. Async Event Processing

```
┌─────────────────────────────────────────┐
│  Request Handler                        │
│  (TenantAdmin::PropsController#create)  │
└────────────────┬────────────────────────┘
                 │
         ┌───────▼────────┐
         │ property.save  │
         └───────┬────────┘
                 │
         ┌───────▼────────────────────────────┐
         │ PostHogService.capture_admin_action│
         │ (Non-blocking, async batched)      │
         └───────┬────────────────────────────┘
                 │
         ┌───────▼────────────────────────────┐
         │ PostHog Client                     │
         │ (Queues event in batch)            │
         └───────┬────────────────────────────┘
                 │
         ┌───────▼────────────────────────────┐
         │ Background Worker                  │
         │ (Every X seconds)                  │
         │ - Flushes batch                    │
         │ - HTTP POST to PostHog API         │
         │ - Retry on failure                 │
         └────────────────────────────────────┘

Result: Request completes in <50ms
        Event arrives at PostHog in <2 seconds
        No user-facing performance impact
```

---

## Summary

**Current:** Ahoy Matey provides robust visitor tracking, isolated per-website

**Proposed Addition:** PostHog adds admin action & product analytics, also multi-tenant scoped

**Key Principle:** All events scoped by `website_id` + events properly isolated in queries

**Effort:** 4-7 weeks implementation across 6 phases
