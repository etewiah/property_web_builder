# Subscription System Quick Reference

## Database Tables

```
pwb_plans ──┐
            ├──> pwb_subscriptions ──> pwb_subscription_events
            │                          (audit trail)
   (1:many) │
            └──> websites
               (each website has 1 subscription)
```

## Models Quick Summary

### Pwb::Plan
- Defines pricing, limits, features for a subscription tier
- Key fields: `price_cents`, `billing_interval`, `trial_days`, `property_limit`, `user_limit`, `features` (JSONB)
- Scopes: `active`, `public_plans`, `for_display`
- Methods: `has_feature?`, `unlimited_properties?`, `unlimited_users?`, `formatted_price`

### Pwb::Subscription
- Links a website to a plan
- Tracks billing status and lifecycle
- Key fields: `website_id`, `plan_id`, `status`, `trial_ends_at`, `current_period_ends_at`
- Status values: `trialing`, `active`, `past_due`, `canceled`, `expired`
- AASM State Machine: handles all transitions
- Methods: `in_good_standing?`, `allows_access?`, `within_property_limit?`, `within_user_limit?`, `has_feature?`

### Pwb::SubscriptionEvent
- Immutable audit log (created_at only, never updated)
- Logs every subscription change
- Event types: trial_started, activated, plan_changed, canceled, expired, etc.

## Website Helper Methods

Via `Pwb::WebsiteSubscribable` concern (included in Website model):

```ruby
website.subscription              # Get subscription or nil
website.plan                      # Get plan or nil
website.has_active_subscription?  # true if trialing or active
website.in_trial?                 # true if trialing
website.trial_days_remaining      # integer or nil
website.has_feature?(feature_key) # check if plan includes feature

# Property limits
website.can_add_property?         # true if under limit
website.remaining_properties      # integer or nil (nil = unlimited)
website.property_limit            # integer or nil

# User limits (after Phase 1 implementation)
website.can_add_user?             # true if under limit
website.remaining_users           # integer or nil
website.user_limit                # integer or nil
```

## Subscription Methods

```ruby
# Status checks
subscription.in_good_standing?    # active or trialing
subscription.allows_access?       # active, trialing, or past_due
subscription.trial_ended?         # trial period passed
subscription.trial_days_remaining # days left in trial

# Limit checking
subscription.within_property_limit?(count)  # true if count is within limit
subscription.remaining_properties           # integer or nil
subscription.within_user_limit?(count)      # true if count is within limit (if impl)
subscription.remaining_users                # integer or nil (if impl)

# Feature checking
subscription.has_feature?('analytics')      # true if feature in plan

# Operations
subscription.activate!            # AASM transition: any -> active
subscription.cancel!              # AASM transition: any -> canceled
subscription.expire_trial!        # AASM transition: trialing -> expired
subscription.reactivate!          # AASM transition: canceled/expired -> active

# Helper methods
subscription.start_trial(days: 30)
subscription.change_plan(new_plan)
```

## Subscription Service API

```ruby
service = Pwb::SubscriptionService.new

# Create trial
result = service.create_trial(website: website, plan: plan, trial_days: 30)
# => { success: true, subscription: ... } or { success: false, errors: [...] }

# Activate
result = service.activate(subscription: subscription, external_id: 'stripe_123')
# => { success: true, subscription: ... } or { success: false, errors: [...] }

# Cancel
result = service.cancel(subscription: subscription, at_period_end: true, reason: 'Too expensive')
# => { success: true, subscription: ... } or { success: false, errors: [...] }

# Change plan (validates no data loss on downgrade)
result = service.change_plan(subscription: subscription, new_plan: new_plan)
# => { success: true, subscription: ... } or { success: false, errors: [...] }

# Scheduled tasks
result = service.expire_ended_trials
# => { expired_count: 5, errors: [] }

result = service.expire_ended_subscriptions
# => { expired_count: 3, errors: [] }

# Get status summary
status = service.status_for(website)
# => { status: 'active', has_subscription: true, plan_name: 'Professional', ... }
```

## Plan Features (All Possible)

```ruby
# Themes
'default_theme'          # Default theme only
'all_themes'             # Access to all themes
'custom_theme'           # Custom theme design

# Domain
'subdomain_only'         # PWB subdomain
'custom_domain'          # Use your own custom domain

# Languages
'single_language'        # English only
'multi_language_3'       # Up to 3 languages
'multi_language_8'       # Up to 8 languages

# Support
'email_support'          # Email support
'priority_support'       # Priority support
'dedicated_support'      # Dedicated account manager

# Features
'ssl_included'           # SSL certificate included
'analytics'              # Analytics dashboard
'custom_integrations'    # Custom 3rd party integrations
'api_access'             # API access for integrations
'white_label'            # Remove PropertyWebBuilder branding
```

## Subscription Status Transitions (AASM)

```
┌─────────────────────────────────────────────┐
│           SUBSCRIPTION LIFECYCLE             │
└─────────────────────────────────────────────┘

  trialing ──activate──→ active
     │                    │
     │                    ├─ mark_past_due → past_due
     │                    │
     │                    └─ cancel ──→ canceled
     │
     └─ expire_trial ──→ expired
                           ↑
                    (end of period)
                           │
     canceled ────────────┘
     OR past_due ────────┘

  reactivate: canceled/expired → active
  
Key guards:
  - expire_trial: only if trial_ended? is true
  - activate: allowed from trialing, past_due, canceled
```

## Controllers

### TenantAdmin::SubscriptionsController
- URL: `/tenant_admin/subscriptions`
- Actions: index, show, new, create, edit, update, destroy, activate, cancel, change_plan, expire_trials
- Admin interface for managing all subscriptions

### SiteAdmin::BillingController
- URL: `/site_admin/billing`
- Action: show
- Displays current subscription and usage for current website

## Validation Points

### Property Limits (ENFORCED)
- Location: `app/models/pwb/realty_asset.rb` (line 74)
- Validation: `validate :within_subscription_property_limit, on: :create`
- Check: `website.can_add_property?`

### User Limits (NOT YET ENFORCED)
- Location: (needs to be added to User model)
- Check: `subscription.within_user_limit?(count)`

### Feature Access (NOT YET ENFORCED)
- Check: `website.has_feature?('feature_key')`
- Manual checks needed in controllers

## Common Patterns

### Check if user can add property
```ruby
if current_website.can_add_property?
  # Allow property creation
else
  # Show upgrade prompt
  remaining = current_website.remaining_properties
  flash[:alert] = "Property limit reached. You can add #{remaining} more properties with an upgrade."
end
```

### Check for feature access
```ruby
if current_website.has_feature?('analytics')
  # Show analytics
else
  # Show upgrade prompt
  flash[:alert] = "Analytics requires Professional plan or higher"
end
```

### Get subscription status
```ruby
service = Pwb::SubscriptionService.new
status = service.status_for(current_website)

if status[:has_subscription]
  puts "Plan: #{status[:plan_name]}"
  puts "Status: #{status[:status]}"
  puts "Remaining properties: #{status[:remaining_properties]}"
else
  puts "No subscription"
end
```

### Create trial subscription for new website
```ruby
plan = Pwb::Plan.default_plan
service = Pwb::SubscriptionService.new

result = service.create_trial(website: website, plan: plan, trial_days: 14)
if result[:success]
  subscription = result[:subscription]
  puts "Trial created, expires at: #{subscription.trial_ends_at}"
else
  puts "Error: #{result[:errors]}"
end
```

### Change plan with validation
```ruby
new_plan = Pwb::Plan.find_by_slug('professional')
service = Pwb::SubscriptionService.new

result = service.change_plan(subscription: subscription, new_plan: new_plan)
if result[:success]
  puts "Plan changed to #{new_plan.display_name}"
else
  puts "Error: #{result[:errors]}"
end
```

## Database Queries

### Find all active subscriptions
```ruby
Pwb::Subscription.active_subscriptions
Pwb::Subscription.where(status: 'active')
```

### Find subscriptions expiring soon
```ruby
Pwb::Subscription.expiring_soon(3)  # Expiring in next 3 days
```

### Find trials that ended
```ruby
Pwb::Subscription.trial_expired
```

### Find by plan
```ruby
plan = Pwb::Plan.find_by_slug('professional')
subscriptions = plan.subscriptions
```

### Get subscription events for audit
```ruby
subscription.events.order(created_at: :desc).limit(20)
subscription.events.by_type('plan_changed')
```

## Key Files

| File | Purpose |
|------|---------|
| `app/models/pwb/plan.rb` | Plan model with features and limits |
| `app/models/pwb/subscription.rb` | Subscription model with AASM state machine |
| `app/models/pwb/subscription_event.rb` | Audit log events |
| `app/services/pwb/subscription_service.rb` | Main service API |
| `app/models/concerns/pwb/website_subscribable.rb` | Website helper methods |
| `app/models/pwb/realty_asset.rb` | Property limit validation (line 288) |
| `app/controllers/tenant_admin/subscriptions_controller.rb` | Admin subscription management |
| `app/controllers/site_admin/billing_controller.rb` | Billing display for websites |
| `db/migrate/20251215100000_create_subscription_system.rb` | Main schema |

## Gemfile Dependencies

- `aasm` (~> 5.5) - State machine for subscription status
- `money-rails` (~> 2.0) - For monetary pricing
- `pagy` (~> 43.0) - Pagination for subscription lists
- All others already in Gemfile

## Common Gotchas

1. **No subscription = no limits** - Legacy behavior allows unlimited when subscription is nil
2. **Property limit enforcement only on create** - Updating existing properties doesn't validate
3. **User limit not enforced** - Plans have the field but no validation
4. **Features aren't automatically blocked** - Manual checks needed in every feature-gated action
5. **Payment provider not integrated** - All subscription activations are manual
6. **No trial to paid conversion** - Trials expire automatically but no payment is collected

## Next Steps

1. Implement user limit enforcement (see LIMIT_ENFORCEMENT_IMPLEMENTATION.md)
2. Add feature access control (see LIMIT_ENFORCEMENT_IMPLEMENTATION.md)
3. Add scheduled background jobs for trial expiration
4. Integrate with payment provider for payment webhooks
5. Add UI for self-service plan changes
