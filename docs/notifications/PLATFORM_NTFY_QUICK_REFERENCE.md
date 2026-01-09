# Platform ntfy Quick Reference

Quick guide for using platform-level ntfy notifications.

## Setup (5 minutes)

### 1. Environment Variables

Add to your `.env` file or environment:

```bash
# Enable platform notifications
PLATFORM_NTFY_ENABLED=true

# ntfy server (use default or self-hosted)
PLATFORM_NTFY_SERVER_URL=https://ntfy.sh

# Topic prefix (makes your topics unique)
PLATFORM_NTFY_TOPIC_PREFIX=pwb-production  # or pwb-staging, pwb-dev

# Optional: access token for private topics
# PLATFORM_NTFY_ACCESS_TOKEN=tk_xxxxxxxxxxxxx

# Platform URLs (for notification links)
PLATFORM_DOMAIN=propertywebbuilder.com
TENANT_ADMIN_DOMAIN=admin.propertywebbuilder.com
```

### 2. Mobile App Setup

1. Install **ntfy** app:
   - iOS: https://apps.apple.com/app/ntfy/id1625396347
   - Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy

2. Subscribe to topics (replace `pwb-production` with your prefix):
   - `pwb-production-signups` - User registrations
   - `pwb-production-provisioning` - Website creation
   - `pwb-production-subscriptions` - Billing events
   - `pwb-production-system` - System alerts
   - `pwb-production-test` - Test notifications

3. Configure notification priority for each topic (optional):
   - High priority → Always alert
   - Default → Normal notifications
   - Low priority → Quiet hours

## Testing

### Rails Console Test

```ruby
# Test configuration
PlatformNtfyService.test_configuration
# => {success: true, message: "Test notification sent successfully"}

# Send manual notifications
PlatformNtfyService.notify_system_alert(
  "Test Alert",
  "This is a test message",
  priority: PlatformNtfyService::PRIORITY_HIGH
)
```

### Trigger Real Events

```ruby
# User signup
service = Pwb::ProvisioningService.new
result = service.start_signup(email: "test@example.com")

# Create trial subscription
subscription = Pwb::Subscription.create!(
  website: website,
  plan: plan,
  status: 'trialing',
  trial_ends_at: 14.days.from_now
)
```

## Notification Reference

### User Lifecycle

| Event | Trigger | Priority | Channel |
|-------|---------|----------|---------|
| 🎉 User Signup | `ProvisioningService#start_signup` | HIGH | signups |
| ✅ Email Verified | `ProvisioningService#verify_email` | DEFAULT | signups |
| 🎊 Onboarding Complete | Website provisioned | HIGH | signups |

### Website Provisioning

| Event | Trigger | Priority | Channel |
|-------|---------|----------|---------|
| ⚙️ Provisioning Started | `ProvisioningService#provision_website` | DEFAULT | provisioning |
| ✅ Website Live | Provisioning complete | HIGH | provisioning |
| ❌ Provisioning Failed | Provisioning error | URGENT | provisioning |

### Subscriptions

| Event | Trigger | Priority | Channel |
|-------|---------|----------|---------|
| 🆓 Trial Started | Subscription created | DEFAULT | subscriptions |
| 💰 Subscription Activated | Status → active | HIGH | subscriptions |
| ⏱️ Trial Expired | Trial ends without payment | DEFAULT | subscriptions |
| 😢 Subscription Canceled | Status → canceled | HIGH | subscriptions |
| ⚠️ Payment Failed | Payment processing error | URGENT | subscriptions |
| 🔄 Plan Changed | Upgrade/downgrade | DEFAULT | subscriptions |

### System

| Event | Trigger | Priority | Channel |
|-------|---------|----------|---------|
| 🚨 System Alert | Manual or automated | URGENT | system |
| 📊 Daily Summary | Scheduled (9 AM) | LOW | system |

## Usage Examples

### In Services

```ruby
class MyService
  def my_method
    # Do something...
    
    # Send notification asynchronously
    PlatformNtfyNotificationJob.perform_later(
      :system_alert,
      "Important Event",
      message: "Something happened",
      priority: PlatformNtfyService::PRIORITY_HIGH
    )
  end
end
```

### In Models

```ruby
class MyModel < ApplicationRecord
  after_commit :notify_platform_event, on: :create
  
  private
  
  def notify_platform_event
    return unless PlatformNtfyService.enabled?
    
    PlatformNtfyService.notify_system_alert(
      "New Record Created",
      "#{self.class.name} ##{id} was created"
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to send notification: #{e.message}")
  end
end
```

## Disabling Notifications

### Globally

```bash
export PLATFORM_NTFY_ENABLED=false
```

### Per-Channel

```bash
export PLATFORM_NTFY_NOTIFY_SIGNUPS=false
export PLATFORM_NTFY_NOTIFY_PROVISIONING=false
export PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS=false
export PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH=false
```

### In Code

```ruby
# Check if enabled
PlatformNtfyService.enabled?

# Temporarily disable
ENV['PLATFORM_NTFY_ENABLED'] = 'false'
# ... do something ...
ENV['PLATFORM_NTFY_ENABLED'] = 'true'
```

## Troubleshooting

### No notifications received

1. Check ENV variables:
   ```ruby
   ENV['PLATFORM_NTFY_ENABLED']  # Should be 'true'
   ENV['PLATFORM_NTFY_TOPIC_PREFIX']  # Should match your subscriptions
   ```

2. Test configuration:
   ```ruby
   PlatformNtfyService.test_configuration
   ```

3. Check logs:
   ```bash
   tail -f log/production.log | grep PlatformNtfy
   ```

4. Verify topic subscription in ntfy app matches your prefix

### Notifications sent but not received

1. Check ntfy app notification settings
2. Verify topic name exactly matches (case-sensitive)
3. Check if access token is required but not set
4. Try subscribing to test topic and send test notification

### Too many notifications

1. Disable specific channels:
   ```bash
   export PLATFORM_NTFY_NOTIFY_SIGNUPS=false
   ```

2. Set quiet hours in ntfy app for low-priority topics

3. Reduce priority for less important events (future enhancement)

## Advanced Configuration

### Self-Hosted ntfy Server

```bash
# Point to your own ntfy instance
export PLATFORM_NTFY_SERVER_URL=https://ntfy.example.com

# Use access control
export PLATFORM_NTFY_ACCESS_TOKEN=tk_your_token_here
```

### Custom Actions

```ruby
PlatformNtfyService.publish(
  channel: 'system',
  title: 'Action Required',
  message: 'Click to review',
  actions: [
    { type: 'view', label: 'Review', url: 'https://...' },
    { type: 'http', label: 'Approve', url: 'https://...', method: 'POST' }
  ]
)
```

## Metrics & Monitoring

### Check notification delivery

```ruby
# In development, check logs
tail -f log/development.log | grep "PlatformNtfy"

# Look for:
# [PlatformNtfy] Notification sent to pwb-test-signups
# [PlatformNtfy] Failed: 400 - ...
```

### Monitor queue

```ruby
# Check Solid Queue dashboard at /solid_queue
# Or via console:
SolidQueue::Job.where(queue_name: 'notifications').pending.count
```

## Links

- ntfy Documentation: https://docs.ntfy.sh/
- ntfy Web Interface: https://ntfy.sh/ (or your server)
- Implementation Plan: `docs/notifications/PLATFORM_NTFY_NOTIFICATIONS_PLAN.md`
- Implementation Summary: `docs/notifications/PLATFORM_NTFY_IMPLEMENTATION_SUMMARY.md`

---

**Questions?** Check the implementation docs or search for `PlatformNtfyService` in the codebase.
