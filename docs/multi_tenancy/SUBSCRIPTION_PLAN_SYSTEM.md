# PropertyWebBuilder Subscription & Plan System

## Overview

PropertyWebBuilder has a comprehensive, fully-implemented subscription and plan management system built on the AASM (Any State Any Time) state machine gem. The system handles:

- **Multi-tier plans** (e.g., Starter, Professional, Enterprise)
- **Subscription lifecycle management** (trialing, active, past_due, canceled, expired)
- **Feature management** (plans can include/exclude features)
- **Resource limits** (properties, users per plan)
- **Trial periods** (configurable per plan)
- **Subscription events** (audit trail for all changes)
- **Plan downgrades** (with validation to prevent data loss)

Each website (tenant) has exactly one subscription to one plan. The relationship is stored in the `pwb_subscriptions` table with a unique index on `website_id`.

---

## Database Schema

### Pwb::Plan Model
**Table:** `pwb_plans`

```ruby
# Pricing & Billing
price_cents: integer           # Cost (in cents)
price_currency: string         # Currency (USD, EUR, GBP, etc.)
billing_interval: string       # 'month' or 'year'

# Trial Configuration
trial_days: integer            # Days in trial period (default: 14)
trial_months: integer          # Alternative: calendar months (optional)

# Resource Limits
property_limit: integer        # Max properties (nil = unlimited)
user_limit: integer            # Max users (nil = unlimited)

# Features
features: jsonb                # Array of feature keys (e.g., ['analytics', 'custom_domain'])

# Metadata
name: string                   # Internal name (e.g., 'starter')
slug: string                   # URL-friendly identifier (unique)
display_name: string           # User-facing name
description: text              # Marketing description
active: boolean                # Is this plan currently available?
public: boolean                # Show on pricing page?
position: integer              # Display order
```

**Schema Annotation:**
```
Indexes:
  - index_pwb_plans_on_slug (UNIQUE)
  - index_pwb_plans_on_active_and_position
```

### Pwb::Subscription Model
**Table:** `pwb_subscriptions`

```ruby
# Associations
website_id: bigint            # Foreign key (UNIQUE - one subscription per website)
plan_id: bigint               # Foreign key to Pwb::Plan

# Status & Lifecycle
status: string                # AASM state: trialing, active, past_due, canceled, expired
trial_ends_at: datetime       # When trial expires
current_period_starts_at: datetime
current_period_ends_at: datetime
canceled_at: datetime
cancel_at_period_end: boolean # Schedule cancellation for period end

# Payment Provider Integration
external_provider: string     # 'stripe', 'paddle', etc.
external_id: string           # Provider's subscription ID
external_customer_id: string  # Provider's customer ID

# Metadata
metadata: jsonb               # Flexible field for provider-specific data
```

**Schema Annotation:**
```
Indexes:
  - index_pwb_subscriptions_on_website_unique (UNIQUE on website_id)
  - index_pwb_subscriptions_on_status
  - index_pwb_subscriptions_on_trial_ends_at
  - index_pwb_subscriptions_on_current_period_ends_at
  - index_pwb_subscriptions_on_external_id (UNIQUE, conditional)
```

### Pwb::SubscriptionEvent Model
**Table:** `pwb_subscription_events`

An immutable audit log for all subscription changes.

```ruby
subscription_id: bigint       # Foreign key
event_type: string            # trial_started, activated, plan_changed, etc.
metadata: jsonb               # Event-specific data
created_at: datetime          # (no update - immutable)
```

**Supported Event Types:**
- `trial_started` - Trial period began
- `activated` - Subscription became active
- `trial_expired` - Trial ended without conversion
- `past_due` - Payment failed
- `canceled` - User canceled subscription
- `expired` - Subscription period ended
- `reactivated` - Subscription was reactivated
- `plan_changed` - User switched plans
- `payment_received` - Payment received from provider
- `payment_failed` - Payment failed from provider

---

## Defined Features

Plans can include any of these features (stored in `features` JSONB array):

```ruby
FEATURES = {
  # Themes
  default_theme: 'Default theme only',
  all_themes: 'Access to all themes',
  custom_theme: 'Custom theme design',

  # Domain
  subdomain_only: 'PWB subdomain (yourname.propertywebbuilder.com)',
  custom_domain: 'Use your own custom domain',

  # Languages
  single_language: 'English only',
  multi_language_3: 'Up to 3 languages',
  multi_language_8: 'Up to 8 languages',

  # Support
  email_support: 'Email support',
  priority_support: 'Priority support',
  dedicated_support: 'Dedicated account manager',

  # Features
  ssl_included: 'SSL certificate included',
  analytics: 'Analytics dashboard',
  custom_integrations: 'Custom 3rd party integrations',
  api_access: 'API access for integrations',
  white_label: 'Remove PropertyWebBuilder branding'
}
```

---

## Subscription Lifecycle (AASM State Machine)

### Status Flow

```
trialing ──→ active ──→ past_due ──→ canceled ──→ expired
  │           ↓                         ↑
  │         active ←─────────────────┘
  │           ↑
  └─→ expired
```

### State Transitions

| Event | From | To | Conditions |
|-------|------|----|----|
| `activate` | trialing, past_due, canceled | active | Logs 'activated' event |
| `expire_trial` | trialing | expired | Guard: `trial_ended?` |
| `mark_past_due` | active | past_due | Manual (payment failure) |
| `cancel` | active, trialing, past_due | canceled | Sets `canceled_at` to now |
| `expire` | canceled, past_due | expired | Period has ended |
| `reactivate` | canceled, expired | active | Clears `canceled_at` |

---

## Limit Enforcement Mechanism

### Current Implementation

Limits are **enforced at the model level** via validation when creating properties.

#### In Pwb::RealtyAsset (property model):

```ruby
# Validation on create
validate :within_subscription_property_limit, on: :create

# Validation method
def within_subscription_property_limit
  return unless website # Skip if no website association

  unless website.can_add_property?
    limit = website.property_limit
    errors.add(:base, "Property limit reached. Your plan allows #{limit} properties. Please upgrade to add more.")
  end
end
```

#### In Pwb::WebsiteSubscribable Concern:

```ruby
# Called by validation above
def can_add_property?
  return true unless subscription # No subscription = no limits (legacy behavior)

  subscription.within_property_limit?(realty_assets.count + 1)
end

# Returns remaining property slots
def remaining_properties
  subscription&.remaining_properties
end

# Get the limit number
def property_limit
  plan&.property_limit
end
```

#### In Pwb::Subscription Model:

```ruby
# Core limit checking method
def within_property_limit?(count)
  plan.unlimited_properties? || count <= plan.property_limit
end

# Calculate remaining
def remaining_properties
  return nil if plan.unlimited_properties?

  current = website.realty_assets.count
  [plan.property_limit - current, 0].max
end
```

### Usage in Views/Controllers

The `SiteAdmin::BillingController` displays usage:

```ruby
def calculate_usage
  {
    properties: {
      current: current_website.realty_assets.count,
      limit: @plan&.property_limit,
      unlimited: @plan&.unlimited_properties?
    },
    users: {
      current: current_website.users.count,
      limit: @plan&.user_limit,
      unlimited: @plan&.unlimited_users?
    }
  }
end
```

---

## Service Layer: Pwb::SubscriptionService

The `Pwb::SubscriptionService` class provides the main API for subscription operations:

### Creating a Trial

```ruby
service = Pwb::SubscriptionService.new
result = service.create_trial(
  website: website,
  plan: plan,           # Optional, defaults to Plan.default_plan
  trial_days: 30        # Optional, uses plan.trial_days if not specified
)

# Returns: { success: true, subscription: Subscription } or
#          { success: false, errors: [...] }
```

### Activating a Subscription

```ruby
result = service.activate(
  subscription: subscription,
  external_id: 'stripe_sub_123',           # Optional
  external_provider: 'stripe',              # Optional
  external_customer_id: 'cus_456'          # Optional
)
```

### Changing Plans

```ruby
result = service.change_plan(
  subscription: subscription,
  new_plan: new_plan,
  prorate: true  # For future payment integration
)

# Validates that downgrading won't violate limits:
# - Blocks if current properties > new plan's property_limit
# - Returns clear error message
```

### Canceling a Subscription

```ruby
result = service.cancel(
  subscription: subscription,
  at_period_end: true,        # Cancel at end of billing period
  reason: 'Too expensive'      # Optional
)
```

### Scheduled Tasks

```ruby
# Expire trials that have ended
service.expire_ended_trials
# Returns: { expired_count: Integer, errors: [...] }

# Expire canceled subscriptions past their period end
service.expire_ended_subscriptions
# Returns: { expired_count: Integer, errors: [...] }

# Get status summary
status = service.status_for(website)
# Returns: {
#   status: 'active',
#   has_subscription: true,
#   plan_name: 'Professional',
#   plan_slug: 'professional',
#   in_good_standing: true,
#   allows_access: true,
#   trial_days_remaining: nil,
#   trial_ending_soon: false,
#   current_period_ends_at: <DateTime>,
#   cancel_at_period_end: false,
#   property_limit: 100,
#   remaining_properties: 67,
#   features: ['analytics', 'custom_domain']
# }
```

---

## Helper Methods on Website Model

Via the `Pwb::WebsiteSubscribable` concern:

```ruby
website.plan                          # Get current plan
website.has_active_subscription?      # Is subscription active or trialing?
website.in_trial?                     # Is currently in trial?
website.trial_days_remaining          # Integer or nil
website.has_feature?(feature_key)     # Check if plan includes feature
website.can_add_property?             # Can add another property?
website.remaining_properties          # Integer or nil (nil = unlimited)
website.property_limit                # Integer or nil
```

---

## Helper Methods on Subscription Model

```ruby
subscription.in_good_standing?        # trialing? || active?
subscription.allows_access?           # trialing? || active? || past_due?
subscription.trial_ended?             # Has trial passed?
subscription.trial_days_remaining     # Integer or nil
subscription.trial_ending_soon?(days: 3)  # Approaching end?

subscription.within_property_limit?(count)   # Check if count is within limit
subscription.remaining_properties     # Integer or nil

subscription.has_feature?(feature_key) # Check if plan includes feature
subscription.change_plan(new_plan)     # Switch to different plan
subscription.start_trial(days: 30)     # Begin trial period
```

---

## Feature Checking

Plans include features as a JSON array. Check for features like this:

```ruby
# On website
website.has_feature?('analytics')
website.has_feature?(:custom_domain)

# On subscription
subscription.has_feature?('white_label')

# On plan
plan.has_feature?('api_access')

# Get all enabled features with descriptions
plan.enabled_features
# Returns: [{ key: 'analytics', description: 'Analytics dashboard' }, ...]
```

---

## Controllers

### TenantAdmin::SubscriptionsController
Located at `/app/controllers/tenant_admin/subscriptions_controller.rb`

**Actions:**
- `index` - List all subscriptions (with filters and search)
- `show` - View subscription details and events
- `new/create` - Create new subscription
- `edit/update` - Modify subscription
- `destroy` - Delete subscription
- `activate` - Manually activate a subscription
- `cancel` - Manually cancel a subscription
- `change_plan` - Change to a different plan
- `expire_trials` - Bulk expire ended trials

### SiteAdmin::BillingController
Located at `/app/controllers/site_admin/billing_controller.rb`

**Actions:**
- `show` - Display billing information and usage for current website

---

## Testing

### Models Specs
- `/spec/models/pwb/plan_spec.rb` - Plan model tests
- `/spec/models/pwb/subscription_spec.rb` - Subscription model tests
- `/spec/models/concerns/pwb/website/subscribable_spec.rb` - Website subscription methods

### Service Specs
- `/spec/services/pwb/subscription_service_spec.rb` - Service layer tests

### Controller Specs
- `/spec/controllers/tenant_admin/subscriptions_controller_spec.rb`
- `/spec/controllers/site_admin/billing_controller_spec.rb`

---

## Migrations

### Main System
`db/migrate/20251215100000_create_subscription_system.rb`
- Creates `pwb_plans`, `pwb_subscriptions`, `pwb_subscription_events` tables
- Sets up all indexes and foreign keys

### Features
`db/migrate/20251216220000_add_analytics_feature_to_plans.rb`
- Adds analytics feature to professional and enterprise plans

### Trial Configuration
`db/migrate/20251231160000_add_trial_months_to_pwb_plans.rb`
- Adds `trial_months` column (allows calendar month trials instead of just days)

---

## Current Limitations & Gaps

### 1. User Limit Enforcement
**Status:** NOT ENFORCED
- User limits are defined in plans (`user_limit`)
- Methods exist to check limits (`subscription.within_user_limit?`)
- BUT: No validation exists on user creation to enforce this limit
- **Recommendation:** Add validation to User model similar to property enforcement

### 2. Feature Access Control
**Status:** NOT ENFORCED AT THE FEATURE LEVEL
- Features are stored and can be checked via `has_feature?`
- BUT: No automatic access control based on features
- Controllers/views must manually check features before allowing access
- **Recommendation:** Create a concern or policy system for feature-based access control

### 3. Payment Provider Integration
**Status:** PREPARED BUT NOT ACTIVE
- Tables have `external_id`, `external_provider`, `external_customer_id` fields
- BUT: No actual Stripe/Paddle integration code
- Only manual subscription activation is supported
- **Recommendation:** Implement webhook handlers for payment events

### 4. Trial to Paid Conversion
**Status:** MANUAL ONLY
- Trials are created and expire automatically
- BUT: No automatic payment collection at trial end
- **Recommendation:** Integrate with payment provider when implementing paid features

### 5. Proration
**Status:** PREPARED BUT NOT ACTIVE
- `change_plan` service has a `prorate` parameter
- BUT: No actual proration calculation or refund processing
- **Recommendation:** Implement when connecting to payment processor

### 6. Grace Period for Past Due
**Status:** IMPLEMENTED PARTIALLY
- `allows_access?` includes `past_due?` (grace period exists)
- BUT: No automatic expiration/lock after grace period
- **Recommendation:** Implement scheduled task to expire subscriptions in past_due state after N days

### 7. Subscription Upgrades/Downgrades
**Status:** BASIC IMPLEMENTATION
- Downgrade is validated (prevents data loss)
- BUT: Upgrade doesn't have special handling
- No UI for in-app plan switching yet
- **Recommendation:** Add controllers/views for self-service plan changes

---

## Recommended Next Steps

### High Priority
1. **Enforce user limits** - Add validation to User model
2. **Feature access control** - Create system to block access to feature-gated functionality
3. **Payment integration** - Add Stripe webhook handlers (if planning paid plans)

### Medium Priority
1. **Past due auto-expiration** - Lock out accounts after grace period
2. **Self-service plan switching** - UI for users to change plans
3. **Email notifications** - Warn before trial ends, notify of payment failures

### Low Priority (Future)
1. Proration calculation and refunds
2. Advanced analytics on subscription conversions
3. Custom pricing/discounts for accounts

---

## Code Locations

| Component | Location |
|-----------|----------|
| Plan Model | `app/models/pwb/plan.rb` |
| Subscription Model | `app/models/pwb/subscription.rb` |
| Subscription Event Model | `app/models/pwb/subscription_event.rb` |
| Subscription Service | `app/services/pwb/subscription_service.rb` |
| Website Subscribable Concern | `app/models/concerns/pwb/website_subscribable.rb` |
| TenantAdmin Controller | `app/controllers/tenant_admin/subscriptions_controller.rb` |
| SiteAdmin Billing Controller | `app/controllers/site_admin/billing_controller.rb` |
| Property Limit Validation | `app/models/pwb/realty_asset.rb` (line 288) |
| Migrations | `db/migrate/202512*_*.rb` |
| Plan Tests | `spec/models/pwb/plan_spec.rb` |
| Subscription Tests | `spec/models/pwb/subscription_spec.rb` |

---

## Additional Resources

- **AASM Documentation:** https://github.com/aasm/aasm
- **Migration Files:** See `db/migrate/` for schema details
- **Service Layer:** `Pwb::SubscriptionService` is the main API for subscription operations
- **Audit Trail:** All changes are logged in `pwb_subscription_events` table
