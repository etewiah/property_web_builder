# Platform-Level ntfy Notifications Plan

**Purpose**: Extend ntfy notification system to support platform/tenant admin level events for monitoring user signups, website provisioning, subscription changes, and system health.

**Created**: 2026-01-09  
**Status**: Planning Phase

---

## Current State

### Existing ntfy Infrastructure (Website/Tenant Level)

The system already has a robust ntfy integration for **website-level** notifications:

- **Service**: `NtfyService` (`app/services/ntfy_service.rb`)
- **Job**: `NtfyNotificationJob` (`app/jobs/ntfy_notification_job.rb`)
- **Concern**: `NtfyListingNotifications` for automatic listing change notifications
- **Configuration**: Per-website settings stored in `pwb_websites` table
  - `ntfy_enabled`
  - `ntfy_server_url`
  - `ntfy_topic_prefix`
  - `ntfy_access_token`
  - Channel toggles: `ntfy_notify_inquiries`, `ntfy_notify_listings`, `ntfy_notify_users`, `ntfy_notify_security`

### Limitation

The current system only supports **per-tenant notifications** for events within a single website. There's no mechanism for platform administrators to receive notifications about:
- New user signups
- Website creation/provisioning
- Subscription changes (trials, activations, cancellations)
- Provisioning failures
- System-wide events

---

## Proposed Solution Architecture

### 1. Platform Configuration Model

Create a platform-level configuration (separate from website-specific settings):

**Database Migration**: `add_platform_ntfy_settings`

```ruby
# New columns for a Platform/Settings singleton or environment variables
# Option 1: Environment Variables (Simpler)
PLATFORM_NTFY_ENABLED=true
PLATFORM_NTFY_SERVER_URL=https://ntfy.sh
PLATFORM_NTFY_TOPIC_PREFIX=pwb-platform
PLATFORM_NTFY_ACCESS_TOKEN=tk_xxxxx

# Notification channels
PLATFORM_NTFY_NOTIFY_SIGNUPS=true
PLATFORM_NTFY_NOTIFY_PROVISIONING=true
PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS=true
PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH=true

# Option 2: Database Table (More Flexible)
# Create: pwb_platform_settings (singleton)
```

**Recommendation**: Start with **Option 1 (Environment Variables)** for simplicity, migrate to database if needed later.

---

### 2. Platform Ntfy Service

Create a new service class similar to existing `NtfyService` but for platform-level events.

**File**: `app/services/platform_ntfy_service.rb`

**Key Methods**:
- `notify_user_signup(user, reserved_subdomain:)` - New user registration
- `notify_email_verified(user)` - Email verification complete
- `notify_onboarding_complete(user, website)` - User finished onboarding
- `notify_provisioning_started(website)` - Website provisioning began
- `notify_provisioning_complete(website)` - Website is live
- `notify_provisioning_failed(website, error)` - Provisioning error
- `notify_trial_started(subscription)` - Trial subscription created
- `notify_subscription_activated(subscription)` - Paid subscription active
- `notify_trial_expired(subscription)` - Trial ended without conversion
- `notify_subscription_canceled(subscription, reason:)` - Subscription canceled
- `notify_payment_failed(subscription, error_details:)` - Payment issue
- `notify_plan_changed(subscription, old_plan, new_plan)` - Plan upgrade/downgrade
- `notify_system_alert(title, message, priority:)` - System health alerts
- `notify_daily_summary(metrics)` - Daily platform stats

---

### 3. Integration Points

#### A. User Signup Flow (`app/services/pwb/provisioning_service.rb`)

```ruby
# In start_signup method, after user created:
PlatformNtfyService.notify_user_signup(user, reserved_subdomain: subdomain)

# In verify_email method:
PlatformNtfyService.notify_email_verified(user)

# In provision_website method, after success:
PlatformNtfyService.notify_onboarding_complete(user, website)
```

#### B. Website Provisioning (`app/services/pwb/provisioning_service.rb`)

```ruby
# When provisioning starts:
website.update!(provisioning_state: 'provisioning')
PlatformNtfyService.notify_provisioning_started(website)

# When provisioning succeeds:
website.update!(provisioning_state: 'live')
PlatformNtfyService.notify_provisioning_complete(website)

# When provisioning fails:
website.update!(provisioning_state: 'failed')
PlatformNtfyService.notify_provisioning_failed(website, error.message)
```

#### C. Subscription Events (`app/models/pwb/subscription.rb`)

Add after_commit callbacks:

```ruby
# In Subscription model
after_commit :notify_platform_trial_started, on: :create, if: :trialing?
after_commit :notify_platform_subscription_activated, if: :just_activated?
after_commit :notify_platform_trial_expired, if: :just_expired_from_trial?
after_commit :notify_platform_canceled, if: :just_canceled?

private

def notify_platform_trial_started
  PlatformNtfyService.notify_trial_started(self)
end

def notify_platform_subscription_activated
  PlatformNtfyService.notify_subscription_activated(self)
end

def notify_platform_trial_expired
  PlatformNtfyService.notify_trial_expired(self)
end

def notify_platform_canceled
  PlatformNtfyService.notify_subscription_canceled(self)
end

def just_activated?
  saved_change_to_status? && status == 'active'
end

def just_expired_from_trial?
  saved_change_to_status? && status == 'expired' && status_before_last_save == 'trialing'
end

def just_canceled?
  saved_change_to_status? && status == 'canceled'
end
```

#### D. Subscription Service Integration (`app/services/pwb/subscription_service.rb`)

```ruby
# In activate method:
PlatformNtfyService.notify_subscription_activated(subscription)

# In change_plan method:
PlatformNtfyService.notify_plan_changed(subscription, old_plan, new_plan)

# In handle_payment_failure:
PlatformNtfyService.notify_payment_failed(subscription, error_details: details)
```

---

### 4. Background Job (Optional but Recommended)

Create an async job for platform notifications:

**File**: `app/jobs/platform_ntfy_notification_job.rb`

```ruby
# frozen_string_literal: true

# Background job for platform-level ntfy notifications
class PlatformNtfyNotificationJob < ActiveJob::Base
  queue_as :notifications

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(notification_type, *args)
    case notification_type.to_sym
    when :user_signup
      user_id, subdomain = args
      user = Pwb::User.find(user_id)
      PlatformNtfyService.notify_user_signup(user, reserved_subdomain: subdomain)
    
    when :provisioning_complete
      website_id = args.first
      website = Pwb::Website.unscoped.find(website_id)
      PlatformNtfyService.notify_provisioning_complete(website)
    
    when :subscription_activated
      subscription_id = args.first
      subscription = Pwb::Subscription.find(subscription_id)
      PlatformNtfyService.notify_subscription_activated(subscription)
    
    # ... other event types
    else
      Rails.logger.warn("[PlatformNtfyNotificationJob] Unknown type: #{notification_type}")
    end
  end
end
```

**Usage in services**:
```ruby
# Async (recommended)
PlatformNtfyNotificationJob.perform_later(:user_signup, user.id, subdomain)

# Sync (for critical events)
PlatformNtfyService.notify_user_signup(user, reserved_subdomain: subdomain)
```

---

### 5. Tenant Admin Interface

Add a test/configuration page for platform admins:

**Route**: `/tenant_admin/platform_notifications/test`

**Controller**: `app/controllers/tenant_admin/platform_notifications_controller.rb`

```ruby
module TenantAdmin
  class PlatformNotificationsController < TenantAdminController
    def test
      result = PlatformNtfyService.test_configuration
      
      if result[:success]
        redirect_to tenant_admin_settings_path, notice: result[:message]
      else
        redirect_to tenant_admin_settings_path, alert: result[:message]
      end
    end

    def metrics
      @metrics = calculate_daily_metrics
    end

    def send_daily_summary
      metrics = calculate_daily_metrics
      PlatformNtfyService.notify_daily_summary(metrics)
      redirect_to tenant_admin_platform_notifications_metrics_path, 
                  notice: 'Daily summary sent'
    end

    private

    def calculate_daily_metrics
      today = Date.current.beginning_of_day..Date.current.end_of_day
      
      {
        signups_today: Pwb::User.where(created_at: today).count,
        websites_created: Pwb::Website.unscoped.where(created_at: today).count,
        subscriptions_activated: Pwb::SubscriptionEvent.where(
          event_type: 'activated',
          created_at: today
        ).count,
        subscriptions_canceled: Pwb::SubscriptionEvent.where(
          event_type: 'canceled',
          created_at: today
        ).count,
        total_active_websites: Pwb::Website.unscoped.where(provisioning_state: 'live').count,
        total_mrr_cents: Pwb::Subscription.active.joins(:plan).sum('pwb_plans.price_cents')
      }
    end
  end
end
```

---

### 6. Scheduled Jobs (Optional)

Add daily summary notifications:

**File**: `config/recurring.yml`

```yaml
platform_daily_summary:
  class: PlatformDailySummaryJob
  schedule: "0 9 * * *"  # 9 AM daily
  queue: notifications
  description: "Send daily platform metrics summary via ntfy"
```

**Job**: `app/jobs/platform_daily_summary_job.rb`

```ruby
class PlatformDailySummaryJob < ActiveJob::Base
  queue_as :notifications

  def perform
    return unless PlatformNtfyService.send(:platform_ntfy_enabled?)

    metrics = calculate_metrics
    PlatformNtfyService.notify_daily_summary(metrics)
  end

  private

  def calculate_metrics
    # Same as controller metrics method
    # Could extract to a service
  end
end
```

---

## Notification Events Summary

### User Lifecycle
1. **User Signup** (🎉 Priority: HIGH)
   - Triggered: When new user registers
   - Info: Email, reserved subdomain, timestamp
   - Link: Tenant admin user page

2. **Email Verified** (✅ Priority: DEFAULT)
   - Triggered: User clicks verification link
   - Info: Email address
   - Link: Tenant admin user page

3. **Onboarding Complete** (🎊 Priority: HIGH)
   - Triggered: User finishes setup wizard
   - Info: Email, website subdomain
   - Link: New website

### Website Provisioning
4. **Provisioning Started** (⚙️ Priority: DEFAULT)
   - Triggered: Website creation begins
   - Info: Subdomain, state, timestamp
   - Link: Tenant admin website page

5. **Website Live** (✅ Priority: HIGH)
   - Triggered: Provisioning succeeds
   - Info: Subdomain, owner, type, URL
   - Actions: Visit Site, Admin Panel
   - Link: New website

6. **Provisioning Failed** (❌ Priority: URGENT)
   - Triggered: Provisioning error
   - Info: Subdomain, error details
   - Link: Tenant admin website page

### Subscription Lifecycle
7. **Trial Started** (🆓 Priority: DEFAULT)
   - Triggered: New trial subscription created
   - Info: Website, owner, plan, trial end date
   - Link: Tenant admin website page

8. **Subscription Activated** (💰 Priority: HIGH)
   - Triggered: Trial converts or new paid subscription
   - Info: Website, owner, plan, MRR
   - Link: Tenant admin website page

9. **Trial Expired** (⏱️ Priority: DEFAULT)
   - Triggered: Trial ends without conversion
   - Info: Website, owner, plan
   - Link: Tenant admin website page

10. **Subscription Canceled** (😢 Priority: HIGH)
    - Triggered: User cancels subscription
    - Info: Website, owner, plan, lost MRR, reason
    - Link: Tenant admin website page

11. **Payment Failed** (⚠️ Priority: URGENT)
    - Triggered: Payment processing error
    - Info: Website, owner, plan, error details
    - Link: Tenant admin website page

12. **Plan Changed** (🔄 Priority: DEFAULT)
    - Triggered: User upgrades/downgrades
    - Info: Website, owner, old→new plan, MRR change
    - Link: Tenant admin website page

### System Health
13. **System Alert** (🚨 Priority: URGENT)
    - Triggered: Critical system event
    - Info: Custom title and message
    - Link: Optional

14. **Daily Summary** (📊 Priority: LOW)
    - Triggered: Scheduled (9 AM daily)
    - Info: Signups, websites, subscriptions, churn, MRR
    - Link: Tenant admin dashboard

---

## Implementation Checklist

### Phase 1: Core Service (Week 1)
- [ ] Create `PlatformNtfyService` class
- [ ] Add environment variable configuration
- [ ] Implement core publish method and message builders
- [ ] Write RSpec tests for service
- [ ] Add test endpoint in tenant admin

### Phase 2: User Signup Integration (Week 2)
- [ ] Integrate with `ProvisioningService#start_signup`
- [ ] Integrate with `ProvisioningService#verify_email`
- [ ] Integrate with `ProvisioningService#provision_website`
- [ ] Test signup flow end-to-end

### Phase 3: Subscription Integration (Week 2-3)
- [ ] Add callbacks to `Subscription` model
- [ ] Integrate with `SubscriptionService`
- [ ] Add plan change notifications
- [ ] Add payment failure notifications
- [ ] Test subscription lifecycle

### Phase 4: Provisioning Integration (Week 3)
- [ ] Add provisioning state change notifications
- [ ] Add provisioning failure alerts
- [ ] Test provisioning flows

### Phase 5: System Health & Metrics (Week 4)
- [ ] Create daily summary job
- [ ] Add metrics calculation service
- [ ] Create tenant admin metrics dashboard
- [ ] Add system alert capability

### Phase 6: Polish & Documentation (Week 4)
- [ ] Add comprehensive RSpec tests
- [ ] Document all notification types
- [ ] Create setup guide for platform admins
- [ ] Add configuration examples

---

## Configuration Example

**Production `.env` file**:

```bash
# Platform Ntfy Configuration
PLATFORM_NTFY_ENABLED=true
PLATFORM_NTFY_SERVER_URL=https://ntfy.sh
PLATFORM_NTFY_TOPIC_PREFIX=pwb-production
PLATFORM_NTFY_ACCESS_TOKEN=tk_xxxxxxxxxxxxx

# Notification Channels (all enabled by default)
PLATFORM_NTFY_NOTIFY_SIGNUPS=true
PLATFORM_NTFY_NOTIFY_PROVISIONING=true
PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS=true
PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH=true

# Platform URLs
PLATFORM_DOMAIN=propertywebbuilder.com
TENANT_ADMIN_DOMAIN=admin.propertywebbuilder.com
```

**Development `.env` file**:

```bash
# Platform Ntfy Configuration (optional in dev)
PLATFORM_NTFY_ENABLED=false
```

---

## Notification Topics

With prefix `pwb-platform`:

- `pwb-platform-signups` - User registration events
- `pwb-platform-provisioning` - Website creation/deployment events
- `pwb-platform-subscriptions` - Subscription lifecycle events
- `pwb-platform-system` - System health and daily summaries
- `pwb-platform-test` - Test notifications

---

## Mobile App Setup (For Platform Admins)

1. Install ntfy app on phone (iOS/Android)
2. Subscribe to topics:
   - `pwb-platform-signups`
   - `pwb-platform-provisioning`
   - `pwb-platform-subscriptions`
   - `pwb-platform-system`
3. Optional: Set different notification priorities for different topics
4. Optional: Set quiet hours for low-priority notifications

---

## Metrics Dashboard (Future Enhancement)

Create a real-time dashboard showing:
- Signups today/week/month
- Websites created (with status breakdown)
- Trial conversions
- Churn rate
- MRR growth
- Recent notifications (last 24h)

---

## Security Considerations

1. **Access Token**: Store `PLATFORM_NTFY_ACCESS_TOKEN` securely in environment variables
2. **Topic Privacy**: Use authenticated topics (require access token)
3. **Data Sensitivity**: Avoid including sensitive data (passwords, payment details) in notifications
4. **Rate Limiting**: ntfy.sh has rate limits - use batching for high-volume events
5. **Fallback**: Log all notification attempts even if sending fails

---

## Testing Strategy

### Unit Tests
- Test each notification method in isolation
- Mock HTTP requests
- Verify message formatting
- Test priority and tag assignment

### Integration Tests
- Test full flow from model change to notification
- Verify async job execution
- Test retry logic

### Manual Testing
- Test with real ntfy.sh server
- Subscribe on mobile device
- Trigger each event type
- Verify formatting and links

---

## Future Enhancements

1. **Platform Admin Dashboard**: Real-time notification feed in web UI
2. **Notification History**: Store sent notifications in database
3. **Batch Notifications**: Aggregate similar events (e.g., "5 signups in last hour")
4. **Custom Actions**: Add action buttons for quick admin tasks
5. **Webhooks**: Allow platform admins to configure custom webhooks
6. **Slack/Discord Integration**: Alternative notification channels
7. **Filtering**: Allow admins to configure which events to receive
8. **A/B Testing Alerts**: Notify when conversion rates change significantly
9. **Error Aggregation**: Batch similar errors instead of spamming

---

## Success Metrics

After implementation, measure:
- Platform admin response time to critical events (provisioning failures)
- Time-to-awareness for subscription changes
- Reduction in manual platform monitoring time
- Notification reliability (success rate)
- False positive rate (noisy notifications)

---

## Questions to Resolve

1. **Async vs Sync**: Should all notifications be async (via job) or sync for critical events?
2. **Database Storage**: Should we store notification history in DB or rely on ntfy retention?
3. **Batching Strategy**: How to batch similar events (e.g., multiple signups within minutes)?
4. **Rate Limiting**: What's the expected notification volume? Need custom server?
5. **Multi-Admin**: How to handle multiple platform admins with different notification preferences?

---

## Resources

- ntfy.sh Documentation: https://docs.ntfy.sh/
- ntfy API Reference: https://docs.ntfy.sh/publish/
- Existing `NtfyService`: `app/services/ntfy_service.rb`
- Subscription Events: `app/models/pwb/subscription_event.rb`
- Provisioning Service: `app/services/pwb/provisioning_service.rb`

---

**Next Steps**: Review plan, get approval, and start Phase 1 implementation.
