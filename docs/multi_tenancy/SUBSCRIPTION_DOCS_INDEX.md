# PropertyWebBuilder Subscription System Documentation Index

## Overview

This directory contains comprehensive documentation of PropertyWebBuilder's subscription and plan management system, created on December 31, 2025.

## Documents

### 1. SUBSCRIPTION_AUDIT_SUMMARY.md (Executive Summary)
**Start here if you're new to the system**

Comprehensive audit of the subscription system with:
- Executive summary of what works and what's missing
- Risk assessment (what could go wrong)
- Implementation roadmap
- File modifications needed
- Key findings and recommendations

**Key Takeaways:**
- Property limits: FULLY ENFORCED ✅
- User limits: NOT ENFORCED ❌
- Feature access: NOT ENFORCED ❌
- Subscription status checks: NOT ENFORCED ❌
- Total effort to fix all gaps: 5-6 hours

### 2. SUBSCRIPTION_PLAN_SYSTEM.md (Complete Reference)
**Start here if you want to understand the entire system**

Detailed documentation covering:
- Database schema (3 tables, 27 columns)
- Models: Plan, Subscription, SubscriptionEvent
- Subscription lifecycle (AASM state machine)
- Limit enforcement mechanism (how property limits work)
- Service layer API (Pwb::SubscriptionService)
- Controllers (admin and user-facing)
- Testing information
- Current limitations and gaps
- Recommended next steps
- Code locations

**Best For:**
- Understanding how the system works
- Finding specific implementation details
- Learning the API
- Understanding the database schema

### 3. LIMIT_ENFORCEMENT_IMPLEMENTATION.md (How to Add Missing Features)
**Start here if you want to implement missing limit enforcement**

Step-by-step implementation guide for:
- User limit enforcement (5-10 minutes)
- Feature access control (15-30 minutes)
- Payment status access control (5 minutes)
- Dashboard usage display (20-30 minutes)
- Scheduled background jobs (10-15 minutes)

Includes:
- Code examples for each implementation
- File locations to modify
- Tests to add
- Priority ranking (Critical, Important, Nice to Have)
- Testing checklist
- Complete code snippets ready to use

**Best For:**
- Implementing missing enforcement
- Adding feature controls
- Setting up background jobs
- Creating dashboard displays

### 4. SUBSCRIPTION_QUICK_REFERENCE.md (API Cheat Sheet)
**Start here if you need to use the system right now**

Quick reference for:
- All models and their key methods
- Website helper methods (usage patterns)
- Subscription methods (checking status, limits)
- Service API (how to use the main service)
- All possible features
- Status transitions (state diagram)
- Common patterns and examples
- Database queries
- Gotchas to watch out for

**Best For:**
- Quick lookups while coding
- Understanding the API surface
- Common usage patterns
- Finding methods to use

---

## Quick Start

### If You Want to...

#### Understand how subscriptions work
1. Read: SUBSCRIPTION_AUDIT_SUMMARY.md (Executive section)
2. Read: SUBSCRIPTION_PLAN_SYSTEM.md (Database Schema section)
3. Reference: SUBSCRIPTION_QUICK_REFERENCE.md

#### Implement missing enforcement
1. Read: SUBSCRIPTION_AUDIT_SUMMARY.md (Gaps section)
2. Follow: LIMIT_ENFORCEMENT_IMPLEMENTATION.md
3. Copy code examples and modify as needed
4. Add tests from the guide

#### Use the system in your code
1. Read: SUBSCRIPTION_QUICK_REFERENCE.md
2. Reference: SUBSCRIPTION_PLAN_SYSTEM.md (Helper Methods sections)
3. Look at examples in code files

#### Debug a subscription issue
1. Check: SUBSCRIPTION_PLAN_SYSTEM.md (Code Locations)
2. Read: Model and service files mentioned
3. Reference: SUBSCRIPTION_QUICK_REFERENCE.md (Database Queries)
4. Check audit trail: subscription.events

#### Add a new feature to the system
1. Read: SUBSCRIPTION_PLAN_SYSTEM.md (Feature Checking section)
2. Check: Plan.FEATURES for possible features
3. Reference: SUBSCRIPTION_QUICK_REFERENCE.md (Patterns)
4. Follow: LIMIT_ENFORCEMENT_IMPLEMENTATION.md if access control needed

---

## Key Components

### Models
```
Pwb::Plan           - Pricing tiers, limits, features
Pwb::Subscription   - Links website to plan, lifecycle management
Pwb::SubscriptionEvent - Audit trail of all changes
```

### Service Layer
```
Pwb::SubscriptionService - Main API for all operations
```

### Controllers
```
TenantAdmin::SubscriptionsController - Admin management
SiteAdmin::BillingController         - User billing view
```

### Concerns/Helpers
```
Pwb::WebsiteSubscribable - Website helper methods
```

---

## Current Status

### Fully Implemented
- ✅ Plan definition system
- ✅ Subscription lifecycle (AASM)
- ✅ Property limit enforcement
- ✅ Trial management
- ✅ Plan change validation
- ✅ Audit trail
- ✅ Service layer
- ✅ Admin interface

### Partially Implemented
- 🟡 Dashboard display (exists but minimal)
- 🟡 Payment provider prep (infrastructure ready, no integration)

### Not Yet Implemented
- ❌ User limit enforcement
- ❌ Feature access control
- ❌ Subscription status checks on access
- ❌ Scheduled background jobs
- ❌ Email notifications
- ❌ Payment provider integration

**Total effort to complete all:** 5-6 hours

---

## Database Schema Overview

```
Relationship Diagram:
┌──────────────┐
│  pwb_plans   │ (Pricing, limits, features)
└──────┬───────┘
       │ 1:many
       │
   ┌───▼──────────────────┐
   │ pwb_subscriptions    │ (Website → Plan binding)
   └───┬──────────────────┘ (Unique: one per website)
       │ 1:many
       │
   ┌───▼──────────────────────┐
   │ pwb_subscription_events  │ (Audit trail)
   └──────────────────────────┘ (Immutable)
```

**Tables:**
- pwb_plans (10 columns)
- pwb_subscriptions (13 columns)
- pwb_subscription_events (4 columns)

**Key Features:**
- Unique index on website_id (one subscription per website)
- Full audit trail with immutable events
- Support for external payment providers (Stripe, Paddle, etc.)
- JSONB metadata fields for extensibility

---

## Important Methods

### On Website Model
```ruby
website.subscription           # Get subscription
website.plan                   # Get plan
website.has_active_subscription?
website.in_trial?
website.trial_days_remaining
website.has_feature?(:feature_key)
website.can_add_property?      # Returns true/false
website.remaining_properties   # Returns integer or nil
website.property_limit         # Returns integer or nil
```

### On Subscription Model
```ruby
subscription.in_good_standing?
subscription.allows_access?
subscription.trial_ended?
subscription.within_property_limit?(count)
subscription.remaining_properties
subscription.has_feature?(:feature_key)
subscription.activate!
subscription.cancel!
subscription.change_plan(new_plan)
```

### Service Layer
```ruby
service = Pwb::SubscriptionService.new
service.create_trial(website:, plan:, trial_days:)
service.activate(subscription:, external_id:)
service.cancel(subscription:, reason:)
service.change_plan(subscription:, new_plan:)
service.expire_ended_trials
service.expire_ended_subscriptions
service.status_for(website)
```

---

## Files to Know

### Core Models
- `app/models/pwb/plan.rb` - Plan definition
- `app/models/pwb/subscription.rb` - Subscription with AASM
- `app/models/pwb/subscription_event.rb` - Audit events

### Service Layer
- `app/services/pwb/subscription_service.rb` - Main API

### Controllers
- `app/controllers/tenant_admin/subscriptions_controller.rb` - Admin
- `app/controllers/site_admin/billing_controller.rb` - Billing view

### Concerns
- `app/models/concerns/pwb/website_subscribable.rb` - Helpers

### Enforcement (Example)
- `app/models/pwb/realty_asset.rb` - Property limit validation (line 288)

### Database
- `db/migrate/20251215100000_create_subscription_system.rb` - Schema
- `db/migrate/20251216220000_add_analytics_feature_to_plans.rb` - Features
- `db/migrate/20251231160000_add_trial_months_to_pwb_plans.rb` - Trial config

### Tests
- `spec/models/pwb/plan_spec.rb`
- `spec/models/pwb/subscription_spec.rb`
- `spec/services/pwb/subscription_service_spec.rb`
- `spec/controllers/tenant_admin/subscriptions_controller_spec.rb`

---

## Implementation Checklist

### Phase 1: Security (Critical - Do Now)
- [ ] Add user limit validation
- [ ] Add subscription status check to SiteAdminController
- [ ] Add feature access control framework
- [ ] Add tests for above

### Phase 2: Operations (Important - This Week)
- [ ] Create SubscriptionLifecycleJob
- [ ] Schedule background job
- [ ] Add trial warning emails
- [ ] Dashboard usage display

### Phase 3: Monetization (When Needed)
- [ ] Payment provider integration (Stripe/Paddle)
- [ ] Webhook handlers
- [ ] Billing UI for customers
- [ ] Plan upgrade/downgrade UI

### Phase 4: Polish (Later)
- [ ] Proration support
- [ ] Advanced analytics
- [ ] Discount/coupon system
- [ ] Usage notifications

---

## Common Questions

**Q: Is the subscription system production-ready?**
A: Mostly yes. Property limits work perfectly. User limits and feature access need enforcement (5-6 hours of work).

**Q: How do I check if a user has a feature?**
A: `website.has_feature?('analytics')` or `subscription.has_feature?(:custom_domain)`

**Q: How do I prevent users from exceeding the property limit?**
A: Already done! Check `website.can_add_property?` before creating.

**Q: How do I prevent users from exceeding the user limit?**
A: Not yet done. Add validation to User model per LIMIT_ENFORCEMENT_IMPLEMENTATION.md

**Q: How do I block access to a feature?**
A: Add before_action per LIMIT_ENFORCEMENT_IMPLEMENTATION.md (Feature Access Control section)

**Q: What payment providers are supported?**
A: Infrastructure ready for any provider. No active integrations yet.

**Q: How are subscriptions managed?**
A: Via Pwb::SubscriptionService. Use `create_trial`, `activate`, `cancel`, `change_plan` methods.

**Q: Where's the audit trail?**
A: In pwb_subscription_events table. Access via `subscription.events`

---

## Document Statistics

| Document | Size | Topics | Code Examples |
|----------|------|--------|---|
| SUBSCRIPTION_AUDIT_SUMMARY.md | 13 KB | 20+ | 5 |
| SUBSCRIPTION_PLAN_SYSTEM.md | 17 KB | 25+ | 20+ |
| LIMIT_ENFORCEMENT_IMPLEMENTATION.md | 15 KB | 20+ | 30+ |
| SUBSCRIPTION_QUICK_REFERENCE.md | 11 KB | 30+ | 15+ |
| **Total** | **56 KB** | **95+** | **70+** |

---

## Next Steps

1. **Read** SUBSCRIPTION_AUDIT_SUMMARY.md to understand what's missing
2. **Identify** which enforcement features you need
3. **Follow** LIMIT_ENFORCEMENT_IMPLEMENTATION.md for implementation
4. **Reference** SUBSCRIPTION_QUICK_REFERENCE.md while coding
5. **Test** using the provided test examples

---

## Support

These documents were created December 31, 2025 as a comprehensive guide to the PropertyWebBuilder subscription system.

For questions or updates:
1. Check the relevant document sections
2. Search SUBSCRIPTION_QUICK_REFERENCE.md for API details
3. Review code examples in LIMIT_ENFORCEMENT_IMPLEMENTATION.md
4. Examine existing tests in spec/ directory

---

**Happy coding! The foundation is solid. You're just adding the enforcement layer.**
