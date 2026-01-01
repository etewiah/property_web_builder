# PostHog Integration Plan for PropertyWebBuilder

## Executive Summary

This document outlines a comprehensive plan to integrate PostHog analytics into PropertyWebBuilder. PostHog will complement the existing Ahoy Matey visitor analytics by providing **product analytics** for admin actions, user journeys, feature adoption, and subscription insights.

**Estimated Timeline:** 4-7 weeks
**Risk Level:** Low (phased rollout, existing infrastructure)
**ROI:** High (product insights, churn prediction, feature adoption metrics)

---

## 1. Current Analytics Landscape

### What We Have

| Tool | Purpose | Status |
|------|---------|--------|
| **Ahoy Matey** | Visitor analytics (page views, property views, inquiries) | Fully implemented |
| **Sentry** | Error tracking and performance monitoring | Active |
| **Lograge** | Structured JSON request logging | Active |

### Current Event Tracking (Ahoy)

```
page_viewed           # Generic page loads
property_viewed       # Property detail views
property_searched     # Search queries
inquiry_submitted     # Contact form submissions
contact_form_opened   # Form interactions
gallery_viewed        # Photo gallery opens
property_shared       # Social shares
property_favorited    # Save/favorite actions
```

### Analytics Gaps (What PostHog Addresses)

- Admin actions (property CRUD, settings changes)
- User identification across tenants
- Feature adoption tracking
- User journey visualization
- Cohort analysis and retention curves
- Subscription correlation analytics
- Churn prediction signals

---

## 2. Recommended Strategy: Hybrid Approach

### Keep Ahoy For
- Public-facing visitor analytics
- Property view/search/inquiry tracking
- Traffic source attribution
- Cost-effective self-hosted data

### Add PostHog For
- Admin/product analytics
- User journeys and funnels
- Feature adoption metrics
- Subscription/billing correlation
- Real-time dashboards and alerts
- Cohort analysis

### Keep Sentry For
- Error tracking (no overlap with PostHog)
- Performance monitoring
- Incident alerting

---

## 3. Multi-Tenant Scoping Requirements

### Critical Principle

**All PostHog events MUST include `website_id` in properties**

PropertyWebBuilder is multi-tenant - each website is a separate tenant with isolated data. Analytics must maintain this isolation.

### Implementation Pattern

```ruby
posthog.capture(
  distinct_id: "#{user.id}_#{website.id}",  # Scoped to tenant
  event: 'property_created',
  properties: {
    website_id: website.id,           # Always include
    website_subdomain: website.subdomain,
    # ... other properties
  }
)
```

### Isolation Enforcement Levels

1. **App-level:** `Pwb::Current.website` context per request
2. **Service-level:** Scoped `distinct_id` format
3. **Query-level:** PostHog filters by `website_id` property

---

## 4. Implementation Roadmap

### Phase 1: Setup & Infrastructure (Week 1-2)

**Tasks:**
- [ ] Add `posthog-ruby` gem to Gemfile
- [ ] Create `/config/initializers/posthog.rb`
- [ ] Add environment variables (`POSTHOG_API_KEY`, `POSTHOG_HOST`)
- [ ] Create `Pwb::PostHogService` base class
- [ ] Configure development/staging/production environments
- [ ] Set up PostHog project and API keys

**Deliverables:**
- Working PostHog client initialization
- Environment-specific configuration
- Basic service class with multi-tenant scoping

### Phase 2: User Identification (Week 2-3)

**Tasks:**
- [ ] Add `identify_user` call in ApplicationController
- [ ] Capture user properties (role, websites_count, subscription_tier)
- [ ] Handle multi-website user context
- [ ] Implement OAuth/Firebase user identification

**Code Example:**

```ruby
# app/controllers/application_controller.rb
before_action :identify_user_to_posthog

def identify_user_to_posthog
  return unless current_user && current_website

  Pwb::PostHogService.new(current_user, current_website).identify_user(
    email: current_user.email,
    name: current_user.full_name,
    websites_managed: current_user.websites.count,
    subscription_tier: current_website.subscription&.plan&.name
  )
end
```

### Phase 3: Admin Action Tracking (Week 3-5)

**Priority Events:**

| Event | Controller | Business Value |
|-------|------------|----------------|
| `property_created` | TenantAdmin::PropsController | Activation metric |
| `property_updated` | TenantAdmin::PropsController | Engagement |
| `property_deleted` | TenantAdmin::PropsController | Churn signal |
| `settings_updated` | TenantAdmin::SettingsController | Feature adoption |
| `theme_changed` | TenantAdmin::ThemesController | Customization |
| `user_invited` | TenantAdmin::UsersController | Collaboration |

**Implementation Pattern:**

```ruby
# app/controllers/tenant_admin/props_controller.rb
def create
  @property = current_website.listed_properties.build(prop_params)

  if @property.save
    Pwb::PostHogService.new(current_user, current_website)
      .capture_admin_action('property_created', {
        property_type: @property.prop_type_key,
        for_sale: @property.for_sale?,
        for_rent: @property.for_rent?,
        price_cents: @property.price_cents
      })

    redirect_to @property
  else
    render :new
  end
end
```

### Phase 4: Onboarding & Activation Tracking (Week 5-6)

**Key Events:**
- `signup_started` - Registration page viewed
- `email_verified` - Email confirmation completed
- `website_created` - First website setup
- `first_property_uploaded` - Activation milestone
- `onboarding_completed` - Wizard finished

**Activation Funnel:**

```
Sign Up Started
    ↓ (target: 90%)
Email Verified
    ↓ (target: 80%)
Website Created
    ↓ (target: 60%)
First Property Uploaded  ← KEY ACTIVATION METRIC
    ↓ (target: 40%)
Settings Configured
```

### Phase 5: Subscription & Billing Events (Week 6)

**Events:**
- `trial_started` - Trial period begins
- `trial_ending_soon` - X days before expiry
- `subscription_activated` - Conversion to paid
- `subscription_upgraded` - Plan upgrade
- `subscription_canceled` - Churn event
- `payment_failed` - Revenue risk

**Properties to Track:**

```ruby
{
  plan_name: 'professional',
  plan_price_cents: 2999,
  billing_cycle: 'monthly',
  trial_days_remaining: 3,
  converted_from_trial: true,
  previous_plan: 'basic'
}
```

### Phase 6: Dashboards & Alerts (Week 7)

**PostHog Dashboards to Create:**

1. **Executive Overview**
   - Active users by subscription tier
   - Feature adoption rates
   - Trial conversion rate
   - Revenue metrics

2. **Product Engagement**
   - Properties created/day
   - Admin session duration
   - Feature usage heatmap
   - Power user identification

3. **Onboarding Funnel**
   - Step completion rates
   - Drop-off points
   - Time to activation

4. **Churn Risk**
   - Inactive users (7/14/30 days)
   - Zero property creates
   - Settings never configured

**Alerts to Configure:**
- Zero property creates in 7 days (for active trial)
- Trial ending in 3 days (no payment method)
- High-value user inactive for 14 days
- Subscription payment failed

---

## 5. Event Taxonomy

### Visitor Events (Ahoy - Existing)

```yaml
page_viewed:
  properties: [page_type, action, path, page_title]

property_viewed:
  properties: [property_id, property_reference, property_type, price, bedrooms, city]

property_searched:
  properties: [query, property_type, min_price, max_price, location, results_count]

inquiry_submitted:
  properties: [property_id, source, has_phone, message_length]
```

### Admin Events (PostHog - New)

```yaml
property_created:
  properties: [property_type, for_sale, for_rent, price_cents, bedrooms, city]

property_updated:
  properties: [property_id, changed_fields, significant_changes]

property_deleted:
  properties: [property_id, property_type, days_listed]

settings_updated:
  properties: [changed_fields, previous_values]

theme_changed:
  properties: [previous_theme, new_theme]

user_invited:
  properties: [role, invitation_method]
```

### Platform Events (PostHog - New)

```yaml
signup_started:
  properties: [source, utm_campaign, referrer]

email_verified:
  properties: [time_since_signup]

onboarding_completed:
  properties: [steps_completed, time_to_complete]

trial_started:
  properties: [plan_name, trial_days]

trial_converted:
  properties: [plan_name, trial_days_used]

subscription_canceled:
  properties: [plan_name, reason, days_active]
```

---

## 6. Technical Architecture

### Service Class Design

```ruby
# app/services/pwb/posthog_service.rb
module Pwb
  class PostHogService
    def initialize(user, website = nil, request = nil)
      @user = user
      @website = website || Pwb::Current.website
      @request = request
    end

    def identify_user(properties = {})
      return unless @user

      client.identify(
        distinct_id: @user.id,
        properties: {
          email: @user.email,
          name: @user.full_name,
          websites_count: @user.websites.count,
          created_at: @user.created_at.to_i,
          **properties
        }
      )
    end

    def capture_admin_action(event_name, properties = {})
      return unless @user && @website

      client.capture(
        distinct_id: scoped_distinct_id,
        event: event_name,
        properties: {
          website_id: @website.id,
          website_subdomain: @website.subdomain,
          user_role: @user.role_for(@website),
          **properties
        }
      )
    end

    def track_subscription_event(event_name, subscription, properties = {})
      return unless subscription

      client.capture(
        distinct_id: scoped_distinct_id,
        event: event_name,
        properties: {
          website_id: subscription.website_id,
          plan_name: subscription.plan&.name,
          status: subscription.status,
          **properties
        }
      )
    end

    private

    def scoped_distinct_id
      "#{@user.id}_#{@website&.id}"
    end

    def client
      @client ||= PostHog::Client.new(
        api_key: ENV['POSTHOG_API_KEY'],
        host: ENV.fetch('POSTHOG_HOST', 'https://us.posthog.com')
      )
    end
  end
end
```

### Initializer Configuration

```ruby
# config/initializers/posthog.rb
require 'posthog'

POSTHOG_CLIENT = PostHog::Client.new(
  api_key: ENV['POSTHOG_API_KEY'],
  host: ENV.fetch('POSTHOG_HOST', 'https://us.posthog.com'),
  on_error: ->(status, msg) { Rails.logger.error("PostHog error: #{status} - #{msg}") }
) if ENV['POSTHOG_API_KEY'].present?
```

### Environment Variables

```bash
# .env
POSTHOG_API_KEY=phc_xxxxxxxxxxxxx
POSTHOG_HOST=https://us.posthog.com  # or self-hosted URL
POSTHOG_PERSONAL_API_KEY=phx_xxxxx   # optional, for feature flags
```

---

## 7. Data Flow Diagrams

### Admin Action Flow

```
Admin creates property
       │
       ▼
TenantAdmin::PropsController#create
       │
       ├── @property.save
       │
       └── PostHogService.capture_admin_action('property_created', {...})
              │
              ▼
       PostHog Client (async batch)
              │
              ▼
       POST https://posthog.com/capture
              │
              ▼
       PostHog Dashboard
         ├── Filter by website_id
         ├── Aggregate by user_role
         └── Visualize trends
```

### Multi-Tenant Data Isolation

```
Website A (id: 42)          Website B (id: 99)
      │                           │
      ▼                           ▼
PostHog Events:              PostHog Events:
  website_id: 42               website_id: 99
  distinct_id: user_1_42       distinct_id: user_2_99
      │                           │
      └───────────┬───────────────┘
                  ▼
          PostHog Dashboard
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
Filter: website_id=42   Filter: website_id=99
        │                   │
        ▼                   ▼
Website A sees only     Website B sees only
its own data            its own data
```

---

## 8. Security & Privacy

### Requirements

- [ ] Use numeric `user_id` as distinct_id (not email)
- [ ] Always include `website_id` in event properties
- [ ] Never track passwords, API keys, or tokens
- [ ] Never track credit card details
- [ ] Implement data retention policy
- [ ] Consider self-hosted PostHog for GDPR compliance
- [ ] Test cross-tenant data isolation thoroughly

### IP Masking

Already enabled in Ahoy (`Ahoy.mask_ips = true`). PostHog can be configured similarly:

```ruby
client.capture(
  distinct_id: user.id,
  event: 'property_created',
  properties: {
    $ip: nil  # Disable IP collection
  }
)
```

### GDPR Considerations

For EU compliance, consider:
1. **Self-hosted PostHog** - Full data control
2. **EU PostHog Cloud** - Data residency in EU
3. **Consent management** - Cookie banner integration
4. **Data export** - User data request handling
5. **Data deletion** - Right to be forgotten

---

## 9. Testing Strategy

### Unit Tests

```ruby
# spec/services/pwb/posthog_service_spec.rb
RSpec.describe Pwb::PostHogService do
  let(:user) { create(:user) }
  let(:website) { create(:website) }
  let(:service) { described_class.new(user, website) }

  describe '#capture_admin_action' do
    it 'includes website_id in all events' do
      expect_any_instance_of(PostHog::Client).to receive(:capture)
        .with(hash_including(properties: hash_including(website_id: website.id)))

      service.capture_admin_action('test_event', {})
    end

    it 'uses scoped distinct_id' do
      expect_any_instance_of(PostHog::Client).to receive(:capture)
        .with(hash_including(distinct_id: "#{user.id}_#{website.id}"))

      service.capture_admin_action('test_event', {})
    end
  end
end
```

### Integration Tests

```ruby
# spec/requests/tenant_admin/props_spec.rb
RSpec.describe 'TenantAdmin::Props', type: :request do
  it 'tracks property_created event' do
    expect_any_instance_of(Pwb::PostHogService)
      .to receive(:capture_admin_action)
      .with('property_created', hash_including(:property_type))

    post tenant_admin_props_path, params: { property: valid_attributes }
  end
end
```

---

## 10. Questions for Stakeholders

Before implementation, clarify:

1. **Hosting:** Self-hosted PostHog or cloud (posthog.com)?
2. **Budget:** Any cost constraints for PostHog plan?
3. **Compliance:** GDPR/CCPA data residency requirements?
4. **Volume:** Estimated admin events per month?
5. **Access:** Who should have PostHog dashboard access?
6. **Retention:** How long to keep analytics data?
7. **Integration:** Need to sync with CRM/email platform?
8. **Features:** Priority use case (dashboards, alerts, feature flags)?

---

## 11. Success Metrics

After PostHog integration, we'll be able to:

- Track which admin users create properties (activation)
- See time-to-first-property (time-to-value)
- Identify unused features (adoption gaps)
- Predict churn (trial-to-paid conversion analysis)
- Correlate subscriptions with feature usage
- Segment users by activity (cohort analysis)
- Alert on anomalies (zero property creates in 7 days)
- Visualize user journeys (onboarding funnel)

---

## 12. Resources

### Internal Documentation
- `/docs/claude_thoughts/POSTHOG_INTEGRATION_ANALYSIS.md` - Detailed technical analysis
- `/docs/claude_thoughts/POSTHOG_QUICK_REFERENCE.md` - Developer quick reference
- `/docs/claude_thoughts/POSTHOG_ARCHITECTURE_DIAGRAM.md` - Visual architecture

### External Resources
- [PostHog Documentation](https://posthog.com/docs)
- [PostHog Ruby SDK](https://posthog.com/docs/libraries/ruby)
- [Ahoy Matey Documentation](https://github.com/ankane/ahoy)

---

## Appendix: File Reference

### Existing Analytics Files
- `/app/services/pwb/analytics_service.rb` - Ahoy query service
- `/app/controllers/concerns/trackable.rb` - Tracking helpers
- `/config/initializers/ahoy.rb` - Ahoy configuration
- `/app/views/pwb/_analytics.html.erb` - Frontend tracking

### Files to Create
- `/config/initializers/posthog.rb` - PostHog initializer
- `/app/services/pwb/posthog_service.rb` - PostHog service class

### Controllers to Modify
- `/app/controllers/application_controller.rb` - User identification
- `/app/controllers/tenant_admin/*` - Admin action tracking

---

*Last Updated: January 2026*
*Document Owner: Development Team*
