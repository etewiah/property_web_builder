# PostHog Analytics Integration - Documentation Index

## Overview

This directory contains a comprehensive analysis of PropertyWebBuilder's current analytics setup and recommendations for PostHog integration.

**Total Analysis:** 1,891 lines across 3 documents + 1 index

**Exploration Date:** 2024-12-29

**Status:** Ready for implementation planning

---

## Documentation Files

### 1. **POSTHOG_INTEGRATION_ANALYSIS.md** (954 lines)

**Comprehensive Technical Analysis**

The main reference document for understanding the codebase from an analytics perspective.

**Contains:**
- Executive summary of analytics readiness
- Current Ahoy Matey setup (installed Dec 2024)
- Multi-tenant architecture deep dive
- Frontend architecture (Stimulus.js, Tailwind CSS)
- User authentication methods (Devise, OAuth, Firebase)
- Existing monitoring (Sentry, Lograge)
- Key user actions to track
- Database schema insights
- PostHog integration opportunities
- Implementation roadmap (6 phases, 4-7 weeks)
- Security & privacy considerations
- Comparison with existing tools
- Potential challenges & solutions
- Complete event taxonomy
- Sample code implementations
- File reference appendix

**Best for:**
- Understanding the full technical context
- Planning implementation phases
- Making architectural decisions
- Reviewing code examples
- Security review

---

### 2. **POSTHOG_QUICK_REFERENCE.md** (368 lines)

**At-a-Glance Quick Reference**

Condensed guide for developers implementing PostHog integration.

**Contains:**
- Architecture at-a-glance diagrams
- Multi-tenant isolation guarantees
- Current event types (what's tracked by Ahoy)
- Database table schema
- User model summary
- Website model summary
- Stimulus.js controller list
- Current analytics service methods
- Conversion funnel visualization
- Property event properties
- Search event properties
- Inquiry event properties
- Existing monitoring services
- Controller concerns ready to use
- Integration point options
- Common PostHog property patterns
- High-value tracking ideas (ranked)
- Environment variables needed
- Privacy & compliance checklist

**Best for:**
- Quick lookups during implementation
- Onboarding new developers
- Event property reference
- Integration checklist

---

### 3. **POSTHOG_ARCHITECTURE_DIAGRAM.md** (569 lines)

**Visual Architecture & Data Flow Diagrams**

Detailed ASCII architecture diagrams showing data flow and system interactions.

**Contains:**
- Current analytics architecture (ASCII diagram)
- Proposed PostHog architecture
- Multi-tenant event flow (detailed walkthrough)
- Admin action tracking examples
- Event data structure comparison
- Dashboard data flow
- Conversion funnel flow with metrics
- Service architecture pattern
- Multi-tenant data isolation guarantee
- Async event processing flow
- Scoping enforcement patterns
- Integration point details

**Best for:**
- Understanding data flow visually
- Explaining architecture to stakeholders
- Reviewing isolation/security
- Identifying integration points

---

## Quick Start Guide

### For Executives / Product Managers

1. Read **POSTHOG_INTEGRATION_ANALYSIS.md** sections 1-7
2. Review "Key User Actions to Track" section
3. Check the "Conversion Funnel Analysis" section
4. Timeline: 4-7 weeks for full implementation

### For Developers (Implementation)

1. Start with **POSTHOG_QUICK_REFERENCE.md**
2. Review **POSTHOG_ARCHITECTURE_DIAGRAM.md** sections 4-9
3. Read **POSTHOG_INTEGRATION_ANALYSIS.md** sections 12-13
4. Follow the implementation roadmap (section 8)

### For DevOps / Infrastructure

1. Review **POSTHOG_INTEGRATION_ANALYSIS.md** sections 9 (Security & Privacy)
2. Check environment variables (POSTHOG_QUICK_REFERENCE.md)
3. Plan self-hosted vs cloud PostHog (both supported)
4. Review data retention and compliance requirements

---

## Key Findings Summary

### Current State

✅ **Ahoy Matey** - Fully implemented visitor analytics (Dec 2024)
✅ **Multi-tenant** - Properly isolated by website_id
✅ **Comprehensive** - 8 tracked event types
✅ **Infrastructure** - Sentry + Lograge already integrated
✅ **Modern stack** - Rails 8.1, Stimulus.js, Tailwind CSS

### Analytics Gap

❌ **Admin actions** - Currently excluded from tracking
❌ **Feature adoption** - No metric collection
❌ **User journeys** - No visualization
❌ **Cohort analysis** - Manual queries only
❌ **Churn prediction** - Not possible with current setup

### Recommended Solution

**Hybrid Approach:**
- Keep **Ahoy** for visitor analytics (cost-effective)
- Add **PostHog** for product analytics (admin actions, journeys)
- Keep **Sentry** for error tracking (no conflict)

---

## Critical Concept: Multi-Tenant Scoping

### The Golden Rule

**All PostHog events MUST include `website_id` in properties**

```ruby
posthog.capture(
  distinct_id: "#{user.id}_#{website.id}",  # Scoped to tenant
  properties: {
    website_id: website.id,  # Always include
    # ... other properties
  }
)
```

### Why It Matters

- PropertyWebBuilder is multi-tenant (user can manage 10+ websites)
- Each website has separate analytics
- One user shouldn't see other website's data
- Data isolation is enforced at 3 levels:
  1. App-level: `Pwb::Current.website` context
  2. Service-level: Scoped distinct_id
  3. Query-level: WHERE website_id = X

See **POSTHOG_ARCHITECTURE_DIAGRAM.md** section 10 for detailed isolation guarantee.

---

## Event Categories

### Visitor Events (Track with Ahoy)
- page_viewed
- property_viewed
- property_searched
- inquiry_submitted
- contact_form_opened
- gallery_viewed
- property_shared
- property_favorited

### Admin Events (Track with PostHog)
- property_created
- property_updated
- settings_updated
- theme_customized
- user_invited
- subscription_upgraded

### Platform Events (Track with PostHog)
- signup_started
- email_verified
- onboarding_completed
- trial_created
- trial_converted
- payment_failed

---

## Implementation Timeline

| Phase | Duration | Tasks | Effort |
|-------|----------|-------|--------|
| 1 | 1-2 weeks | SDK setup, initializer, env vars | Low |
| 2 | 1 week | User identification, scoping | Low |
| 3 | 2-3 weeks | Admin action tracking (property CRUD, settings) | Medium |
| 4 | 1 week | Onboarding flow tracking | Low |
| 5 | 1 week | Subscription/billing events | Low |
| 6 | 1-2 weeks | Dashboards, alerts, exports | Medium |
| **Total** | **4-7 weeks** | Full analytics coverage | **Medium** |

---

## File Structure Reference

```
PropertyWebBuilder/
├── docs/claude_thoughts/
│   ├── POSTHOG_INDEX.md (this file)
│   ├── POSTHOG_INTEGRATION_ANALYSIS.md (954 lines)
│   ├── POSTHOG_QUICK_REFERENCE.md (368 lines)
│   └── POSTHOG_ARCHITECTURE_DIAGRAM.md (569 lines)
│
├── app/
│   ├── models/
│   │   ├── pwb/website.rb (Tenant model)
│   │   ├── pwb/user.rb (Authentication)
│   │   ├── ahoy/visit.rb (Analytics)
│   │   └── ahoy/event.rb (Analytics)
│   │
│   ├── services/
│   │   ├── pwb/analytics_service.rb (Query interface)
│   │   └── pwb/posthog_service.rb (NEW - to implement)
│   │
│   ├── controllers/
│   │   ├── concerns/trackable.rb (Ready to use)
│   │   ├── tenant_admin/* (Where to add PostHog)
│   │   └── application_controller.rb (Where to add identify)
│   │
│   ├── views/
│   │   └── pwb/_analytics.html.erb (Frontend tracking)
│   │
│   └── javascript/controllers/ (Stimulus.js)
│
├── config/
│   ├── initializers/
│   │   ├── ahoy.rb (Current setup)
│   │   ├── sentry.rb (Error tracking)
│   │   ├── lograge.rb (Structured logging)
│   │   └── posthog.rb (NEW - to create)
│   │
│   └── importmap.rb (Frontend assets)
│
└── db/
    └── migrate/
        └── 20251216210000_create_ahoy_visits_and_events.rb
```

---

## Database Tables

### Ahoy Tables (Multi-tenant)
- `ahoy_visits` - Visitor sessions (website_id scoped)
- `ahoy_events` - Events (website_id scoped)

### Core Tables
- `pwb_websites` - Tenants (primary identifier)
- `pwb_users` - Platform users (cross-tenant)
- `pwb_user_memberships` - Access control

### Related Tables
- `pwb_listed_property` - Denormalized properties
- `pwb_subscriptions` - Billing status
- `pwb_subscription_events` - Plan changes

**Key Insight:** All Ahoy tables have `website_id` foreign key = automatic tenant isolation

---

## Controllers to Modify

### For User Identification (Add in ApplicationController)

```ruby
before_action :identify_user_to_posthog

def identify_user_to_posthog
  return unless current_user && current_website
  posthog_client.identify(distinct_id: current_user.id, ...)
end
```

### For Admin Action Tracking (Add in TenantAdminController)

```ruby
after_action :track_admin_action, if: :admin_tracking_enabled?

def track_admin_action
  Pwb::PostHogService.new(current_user, current_website)
    .capture_admin_action(event_name, properties)
end
```

### For Form Tracking (Use Trackable concern)

```ruby
class PublicPropsController < ApplicationController
  include Trackable
  
  def show
    @property = Pwb::ListedProperty.find(params[:id])
    track_property_view(@property)
  end
end
```

---

## Configuration Checklist

- [ ] Add `posthog-ruby` gem to Gemfile
- [ ] Create `/config/initializers/posthog.rb`
- [ ] Add environment variables:
  - [ ] `POSTHOG_API_KEY`
  - [ ] `POSTHOG_PERSONAL_API_KEY` (optional)
  - [ ] `POSTHOG_HOST` (default: posthog.com)
- [ ] Create `Pwb::PostHogService` class
- [ ] Add user identification in ApplicationController
- [ ] Create event tracking in tenant_admin controllers
- [ ] Set up multi-tenant scoping
- [ ] Create integration tests
- [ ] Validate data isolation
- [ ] Set up PostHog dashboards
- [ ] Configure alerts and exports

---

## Security & Privacy Checklist

- [ ] Use numeric user_id, not email, as distinct_id
- [ ] Always include website_id in properties
- [ ] Never track passwords or API keys
- [ ] Never track credit card details
- [ ] Implement data retention policy
- [ ] Consider self-hosted PostHog for GDPR
- [ ] Test cross-tenant data isolation
- [ ] Enable IP masking in Ahoy (already enabled)
- [ ] Review PII handling with legal/privacy

---

## Questions to Answer Before Implementation

1. **Hosting:** Self-hosted PostHog or cloud (posthog.com)?
2. **Compliance:** GDPR, CCPA, or other data residency requirements?
3. **Budget:** Any cost constraints?
4. **Volume:** Estimated events/month from admin actions?
5. **Access:** Who should have dashboard access?
6. **Retention:** How long to keep analytics data?
7. **Integration:** Need to sync with CRM/email?
8. **Features:** Priority use case (dashboards, alerts, feature flags)?

---

## Integration with Existing Services

### Sentry (Error Tracking)
- No conflict with PostHog
- Already configured with tenant context
- Continue using for exceptions

### Lograge (Structured Logging)
- No conflict with PostHog
- Already configured with JSON output
- Use for server-side request logging

### Ahoy (Visitor Analytics)
- Keep for public site analytics
- PostHog complements (not replaces)
- Both can coexist

### Redis
- Can be used for PostHog event batching
- Session storage independent

---

## Success Metrics

Once PostHog is integrated, you'll be able to:

✅ Track which admin users create properties (activation)
✅ See how long it takes first property upload (time-to-value)
✅ Identify unused features (adoption)
✅ Predict churn (trial → paid conversion)
✅ Correlate subscriptions with feature usage
✅ Segment users by activity (cohorts)
✅ Alert on anomalies (zero property creates in 7 days)

---

## Related Documentation

**In this project:**
- `/CLAUDE.md` - Claude instructions for project
- `/docs/architecture/` - Architecture documentation
- `/docs/deployment/` - Deployment guides
- `/docs/seeding/` - Seed data documentation

**External:**
- [Ahoy Matey Docs](https://github.com/ahoy-rb/ahoy)
- [PostHog Docs](https://posthog.com/docs)
- [Rails 8.1 Guide](https://guides.rubyonrails.org)

---

## Questions or Issues

**During Analysis:**
This analysis was completed by Claude Code on 2024-12-29.

**During Implementation:**
Refer to the specific analysis documents above. Each has a detailed section on your topic.

**For Code Examples:**
See POSTHOG_INTEGRATION_ANALYSIS.md section 13 for sample implementations.

**For Architecture Review:**
See POSTHOG_ARCHITECTURE_DIAGRAM.md for visual data flows.

---

## Summary

PropertyWebBuilder is **well-positioned** for PostHog integration:

- ✅ Solid Ahoy foundation exists
- ✅ Clean multi-tenant architecture
- ✅ Modern tech stack
- ✅ Existing monitoring infrastructure
- ✅ Clear admin vs public separation

**Effort: 4-7 weeks for full implementation**

**ROI: High** (product insights, churn prediction, feature adoption)

Start with Phase 1 (Setup) and progress through the 6-phase roadmap.

---

**Last Updated:** 2024-12-29  
**Analysis Completeness:** 100%  
**Code Examples:** 40+  
**Architecture Diagrams:** 20+  
**Event Types Identified:** 25+
