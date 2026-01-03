# Limit Enforcement Implementation Guide

## Summary

PropertyWebBuilder has a **robust subscription/plan infrastructure** with **full limit enforcement implemented**. This document describes the enforcement system.

> **Status: FULLY IMPLEMENTED** (as of January 2026)

---

## What Is Implemented

### Property Limits
**Status:** ✅ FULLY ENFORCED

The system prevents users from adding more properties than their plan allows:

```ruby
# Flow:
# 1. User tries to create a property (RealtyAsset)
# 2. Validation runs: validate :within_subscription_property_limit, on: :create
# 3. Calls: website.can_add_property?
# 4. Returns error if limit exceeded

# Error message:
"Property limit reached. Your plan allows 25 properties. Please upgrade to add more."
```

**Validation Location:** `/app/models/pwb/realty_asset.rb`

### User Limits
**Status:** ✅ FULLY ENFORCED

The system prevents adding more users than the plan allows:

```ruby
# Flow:
# 1. User tries to create a new user
# 2. Validation runs: validate :within_subscription_user_limit, on: :create
# 3. Calls: website.can_add_user?
# 4. Returns error if limit exceeded
```

**Validation Location:** `/app/models/pwb/user.rb`
**Helper Methods:** `/app/models/concerns/pwb/website_subscribable.rb`

### Feature Flags
**Status:** ✅ FULLY ENFORCED

Features are gated using the `FeatureAuthorized` concern:

```ruby
# In controllers:
class SiteAdmin::AnalyticsController < SiteAdminController
  include FeatureAuthorized
  before_action -> { require_feature("analytics") }
end

class SiteAdmin::DomainsController < SiteAdminController
  include FeatureAuthorized
  before_action -> { require_feature("custom_domain") }
end
```

**Concern Location:** `/app/controllers/concerns/feature_authorized.rb`

### Subscription Status
**Status:** ✅ FULLY WORKING

The system has full lifecycle management:
- Trial → Active → Past Due → Canceled → Expired
- Proper state machine with AASM
- All transitions validated and audited
- Access control via `SiteAdminController#check_subscription_access`

### Dashboard Usage Display
**Status:** ✅ FULLY IMPLEMENTED

- Usage meters in billing page showing properties/users
- Subscription warning banners for trials, past-due, expiring
- Located in `/app/views/site_admin/shared/_usage_meters.html.erb`
- Located in `/app/views/site_admin/shared/_subscription_warning.html.erb`

### Scheduled Lifecycle Tasks
**Status:** ✅ FULLY IMPLEMENTED

Background job handles:
- Expiring ended trials
- Expiring ended subscriptions
- Sending trial-ending warnings

**Job Location:** `/app/jobs/subscription_lifecycle_job.rb`

---

## Reference: Implementation Details

### User Limit Enforcement

Validation in the User model:

```ruby
# app/models/pwb/user.rb
class User < ApplicationRecord
  belongs_to :website
  
  # Add this validation
  validate :within_subscription_user_limit, on: :create

  private

  def within_subscription_user_limit
    return unless website # Skip if no website
    
    unless website.subscription&.within_user_limit?(website.users.count + 1)
      limit = website.subscription.plan.user_limit
      errors.add(:base, "User limit reached. Your plan allows #{limit} users. Please upgrade to add more.")
    end
  end
end
```

Also add helper method to Website::Subscribable concern:

```ruby
# app/models/concerns/pwb/website_subscribable.rb
def can_add_user?
  return true unless subscription # No subscription = no limits

  subscription.within_user_limit?(users.count + 1)
end

def remaining_users
  subscription&.remaining_users
end

def user_limit
  plan&.user_limit
end
```

And add helper to Subscription model:

```ruby
# app/models/pwb/subscription.rb
def remaining_users
  return nil if plan.unlimited_users?

  current = website.users.count
  [plan.user_limit - current, 0].max
end
```

**Files to Modify:**
- `app/models/pwb/user.rb` - Add validation
- `app/models/concerns/pwb/website_subscribable.rb` - Add helper methods
- `app/models/pwb/subscription.rb` - Add remaining_users method

**Tests to Add:**
- `spec/models/pwb/user_spec.rb` - Test user limit validation
- `spec/services/pwb/subscription_service_spec.rb` - Test change_plan with user limits

---

### 2. Feature Access Control Enforcement

**Current State:**
- Features are stored in plans as a JSON array
- Can be checked with `has_feature?`
- No automatic enforcement

**To Implement:**

Create a feature authorization concern:

```ruby
# app/controllers/concerns/feature_authorized.rb
module FeatureAuthorized
  extend ActiveSupport::Concern

  class FeatureNotAuthorized < StandardError; end

  included do
    rescue_from FeatureNotAuthorized, with: :feature_not_authorized
  end

  private

  def require_feature(feature_key)
    unless current_website&.has_feature?(feature_key)
      raise FeatureNotAuthorized, 
            "This feature is not included in your plan"
    end
  end

  def feature_not_authorized
    redirect_to billing_path, 
                alert: "This feature is not available on your current plan. Please upgrade."
  end
end
```

Then use in controllers:

```ruby
# app/controllers/site_admin/analytics_controller.rb
class SiteAdmin::AnalyticsController < SiteAdminController
  include FeatureAuthorized

  before_action :require_feature_analytics

  def show
    # analytics code
  end

  private

  def require_feature_analytics
    require_feature('analytics')
  end
end
```

**Alternative: Policy Objects**

For more complex authorization logic, use Pundit:

```ruby
# Add to Gemfile
gem 'pundit', '~> 2.3'

# app/policies/analytics_policy.rb
class AnalyticsPolicy
  def initialize(user, subscription)
    @user = user
    @subscription = subscription
  end

  def view_analytics?
    @subscription&.has_feature?('analytics')
  end

  def export_analytics?
    @subscription&.has_feature?('analytics')
  end
end

# Usage in controller
authorize :analytics, :view_analytics?
```

**Files to Create/Modify:**
- Create `app/controllers/concerns/feature_authorized.rb` - Feature check helper
- Modify `app/controllers/site_admin/analytics_controller.rb` - Add feature check
- Modify `app/controllers/site_admin/domains_controller.rb` - Check custom_domain feature
- Modify any other controllers that access feature-gated functionality

**Controllers Needing Feature Checks:**

| Controller | Feature(s) |
|-----------|----------|
| `site_admin/analytics_controller.rb` | `analytics` |
| `site_admin/domains_controller.rb` | `custom_domain` |
| Theme editors | `custom_theme`, `all_themes` |
| API controllers | `api_access` |
| Media library | May need bandwidth limits based on plan |

---

### 3. Payment Status Access Control

**Current State:**
- Subscriptions have `in_good_standing?` and `allows_access?` methods
- No automatic enforcement in requests

**To Implement:**

Add before_action to protect authenticated pages:

```ruby
# app/controllers/site_admin_controller.rb
class SiteAdminController < ApplicationController
  before_action :check_subscription_access

  private

  def check_subscription_access
    # Allow access if:
    # - No subscription (legacy/free tier)
    # - Subscription is active or trialing
    # - Subscription is past_due (grace period)
    unless current_website.nil? || current_website.subscription&.allows_access?
      redirect_to billing_path, 
                  alert: "Your subscription has expired. Please upgrade to continue."
    end
  end
end
```

More strict version (block on past_due):

```ruby
def check_subscription_in_good_standing
  unless current_website.subscription&.in_good_standing?
    redirect_to billing_path,
                alert: "Your subscription requires attention. Please update your payment method."
  end
end
```

**Files to Modify:**
- `app/controllers/site_admin_controller.rb` - Add subscription check

---

### 4. Dashboard Usage Display

**Current State:**
- `SiteAdmin::BillingController` calculates usage
- No dashboard integration

**To Implement:**

Update dashboard to show usage warnings:

```erb
<!-- app/views/site_admin/dashboard/index.html.erb -->
<% if @subscription.present? %>
  <div class="subscription-status">
    <%= render 'shared/subscription_warning' %>
    <%= render 'shared/usage_meters' %>
  </div>
<% end %>
```

Create warning partial:

```erb
<!-- app/views/shared/_subscription_warning.html.erb -->
<div class="p-4 rounded-lg <%= warning_class %>">
  <h3><%= @subscription.plan.display_name %></h3>
  
  <% if @subscription.trial_ending_soon? %>
    <div class="alert alert-warning">
      Trial expires in <%= @subscription.trial_days_remaining %> days
      <%= link_to 'Upgrade', billing_path %>
    </div>
  <% end %>

  <% if @subscription.past_due? %>
    <div class="alert alert-danger">
      Payment required. Please update your billing information.
      <%= link_to 'Update', billing_path %>
    </div>
  <% end %>

  <% if @subscription.cancel_at_period_end? %>
    <div class="alert alert-info">
      Your subscription will cancel on <%= @subscription.current_period_ends_at.to_date %>
    </div>
  <% end %>
</div>

<% 
  def warning_class
    case @subscription.status
    when 'trialing' then 'bg-blue-50 border border-blue-200'
    when 'active' then 'bg-green-50 border border-green-200'
    when 'past_due' then 'bg-red-50 border border-red-200'
    when 'canceled', 'expired' then 'bg-gray-50 border border-gray-200'
    end
  end
%>
```

Create usage display partial:

```erb
<!-- app/views/shared/_usage_meters.html.erb -->
<div class="space-y-4">
  <% if @usage.dig(:properties, :limit).present? %>
    <div class="usage-meter">
      <div class="flex justify-between text-sm">
        <span>Properties</span>
        <span><%= @usage[:properties][:current] %> / <%= @usage[:properties][:limit] %></span>
      </div>
      <div class="progress">
        <div class="progress-bar" 
             style="width: <%= usage_percentage(@usage[:properties]) %>%"></div>
      </div>
      <% if usage_warning?(@usage[:properties]) %>
        <p class="text-xs text-red-600">
          <%= @usage[:properties][:limit] - @usage[:properties][:current] %> slots remaining
        </p>
      <% end %>
    </div>
  <% end %>

  <% if @usage.dig(:users, :limit).present? %>
    <div class="usage-meter">
      <div class="flex justify-between text-sm">
        <span>Team Members</span>
        <span><%= @usage[:users][:current] %> / <%= @usage[:users][:limit] %></span>
      </div>
      <div class="progress">
        <div class="progress-bar" 
             style="width: <%= usage_percentage(@usage[:users]) %>%"></div>
      </div>
    </div>
  <% end %>
</div>

<%
  def usage_percentage(usage)
    return 100 if usage[:unlimited]
    ((usage[:current].to_f / usage[:limit]) * 100).round
  end

  def usage_warning?(usage)
    return false if usage[:unlimited]
    usage_percentage(usage) >= 80
  end
%>
```

**Files to Modify:**
- `app/controllers/site_admin/dashboard_controller.rb` - Add usage data
- `app/views/site_admin/dashboard/index.html.erb` - Display usage
- Create `app/views/shared/_subscription_warning.html.erb`
- Create `app/views/shared/_usage_meters.html.erb`

---

### 5. Scheduled Tasks for Lifecycle Events

**Current State:**
- Service methods exist to expire trials and subscriptions
- No scheduled jobs running them

**To Implement:**

Create a background job (Rails 8 native with Solid Queue):

```ruby
# app/jobs/subscription_lifecycle_job.rb
class SubscriptionLifecycleJob < ApplicationJob
  queue_as :default

  def perform
    expire_trials
    expire_subscriptions
    warn_about_ending_trials
  end

  private

  def expire_trials
    result = Pwb::SubscriptionService.new.expire_ended_trials
    Rails.logger.info "[SubscriptionLifecycleJob] Expired #{result[:expired_count]} trials"
    log_errors(result[:errors])
  end

  def expire_subscriptions
    result = Pwb::SubscriptionService.new.expire_ended_subscriptions
    Rails.logger.info "[SubscriptionLifecycleJob] Expired #{result[:expired_count]} subscriptions"
    log_errors(result[:errors])
  end

  def warn_about_ending_trials
    Pwb::Subscription.expiring_soon(3).each do |subscription|
      SubscriptionMailer.trial_ending_soon(subscription).deliver_later
    end
  end

  def log_errors(errors)
    errors.each { |error| Rails.logger.error "[SubscriptionLifecycleJob] #{error}" }
  end
end
```

Schedule it in `config/recurring.yml` (Rails 8 Solid Queue):

```yaml
subscription_lifecycle:
  class: SubscriptionLifecycleJob
  schedule: every 1 hour
```

Or use a cron gem for older Rails versions:

```ruby
# Gemfile
gem 'whenever', require: false

# config/schedule.rb
every 1.hour do
  runner "SubscriptionLifecycleJob.perform_now"
end
```

**Files to Create:**
- Create `app/jobs/subscription_lifecycle_job.rb`
- Create `app/mailers/subscription_mailer.rb` (for notifications)
- Create `config/recurring.yml` (if using Solid Queue)
- Modify `config/schedule.rb` (if using whenever)

---

## Implementation Priority

### Phase 1: Critical (Do First)
1. User limit enforcement (5-10 min)
2. Feature access control (15-30 min)
3. Subscription status checks (5 min)

### Phase 2: Important (Soon)
1. Dashboard usage display (20-30 min)
2. Trial warning emails (15 min)
3. Scheduled lifecycle tasks (10-15 min)

### Phase 3: Nice to Have (Later)
1. Pundit policy integration
2. Advanced feature controls
3. Proration support for upgrades
4. Payment processor webhooks

---

## Testing Checklist

For each enforcement point added:

- [ ] Unit test: Limit checking works correctly
- [ ] Unit test: Error messages are clear
- [ ] Integration test: Actual operation fails when limit reached
- [ ] Integration test: Operation succeeds when under limit
- [ ] View test: Usage display shows correctly
- [ ] End-to-end test: User cannot exceed limit via UI

Example test:

```ruby
# spec/models/pwb/user_spec.rb
describe 'user limit enforcement' do
  let(:plan) { Plan.create!(name: 'limited', slug: 'limited', display_name: 'Limited', user_limit: 3) }
  let(:website) { Website.create!(subdomain: 'test') }
  let(:subscription) { Subscription.create!(website: website, plan: plan, status: 'active') }

  before { subscription }

  it 'allows creating users under limit' do
    expect {
      User.create!(website: website, email: 'user1@example.com', password: 'password')
      User.create!(website: website, email: 'user2@example.com', password: 'password')
      User.create!(website: website, email: 'user3@example.com', password: 'password')
    }.to change(User, :count).by(3)
  end

  it 'prevents creating users over limit' do
    3.times { |i| User.create!(website: website, email: "user#{i}@example.com", password: 'password') }
    
    user = User.new(website: website, email: 'user4@example.com', password: 'password')
    expect(user.save).to be_falsey
    expect(user.errors[:base]).to include(/User limit reached/)
  end

  it 'allows unlimited users on unlimited plan' do
    unlimited_plan = Plan.create!(name: 'unlimited', slug: 'unlimited', display_name: 'Unlimited', user_limit: nil)
    subscription.update!(plan: unlimited_plan)

    expect {
      10.times { |i| User.create!(website: website, email: "user#{i}@example.com", password: 'password') }
    }.to change(User, :count).by(10)
  end
end
```

---

## Summary of Implementation Status

| Area | Status | Location |
|------|--------|----------|
| Property limits | ✅ Done | `app/models/pwb/realty_asset.rb` |
| User limits | ✅ Done | `app/models/pwb/user.rb` |
| Feature enforcement | ✅ Done | `app/controllers/concerns/feature_authorized.rb` |
| Subscription access | ✅ Done | `app/controllers/site_admin_controller.rb` |
| Dashboard display | ✅ Done | `app/views/site_admin/shared/_usage_meters.html.erb` |
| Scheduled tasks | ✅ Done | `app/jobs/subscription_lifecycle_job.rb` |

**All enforcement tasks are complete.**

---

## Code Examples

### Check Property Limit
```ruby
website.can_add_property?        # true/false
website.remaining_properties     # 17 (or nil if unlimited)
website.property_limit           # 50 (or nil if unlimited)
```

### Check User Limit
```ruby
website.can_add_user?            # true/false (after Phase 1)
website.remaining_users          # 2 (or nil if unlimited)
website.user_limit               # 5 (or nil if unlimited)
```

### Check Feature
```ruby
website.has_feature?('analytics') # true/false
website.has_feature?('api_access')
website.has_feature?('custom_domain')
```

### Check Subscription Status
```ruby
website.has_active_subscription?   # true if trialing or active
website.subscription.in_good_standing?  # true if trialing or active
website.subscription.allows_access?     # true if trialing, active, or past_due
```

---

## References

- AASM Gem: https://github.com/aasm/aasm
- Pundit Authorization: https://github.com/varvet/pundit
- Rails Background Jobs: https://guides.rubyonrails.org/active_job_basics.html
- Solid Queue: https://github.com/rails/solid_queue
