# Platform ntfy Notifications - Simplified Configuration

**Date**: 2026-01-09  
**Status**: ✅ Complete

## Summary of Changes

Platform ntfy notifications have been simplified to use:
1. **Single topic** instead of multiple channels with prefix
2. **Rails credentials** instead of environment variables  
3. **Automatic enabling** based on topic presence

## Old vs New Configuration

### Before (Complex)
```bash
# .env
PLATFORM_NTFY_ENABLED=true
PLATFORM_NTFY_SERVER_URL=https://ntfy.sh
PLATFORM_NTFY_TOPIC_PREFIX=pwb-production
PLATFORM_NTFY_ACCESS_TOKEN=tk_xxxxx
PLATFORM_NTFY_NOTIFY_SIGNUPS=true
PLATFORM_NTFY_NOTIFY_PROVISIONING=true
PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS=true
PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH=true
```

**Subscribes to**: `pwb-production-signups`, `pwb-production-provisioning`, `pwb-production-subscriptions`, `pwb-production-system`, `pwb-production-test`

### After (Simplified)
```bash
# config/credentials/development.yml.enc
rails credentials:edit --environment development
```

```yaml
platform_ntfy:
  topic: pwb-dev-alerts
  # server_url: https://ntfy.sh   # optional, defaults to https://ntfy.sh
  # access_token: tk_xxxxx         # optional, for private topics
```

**Subscribes to**: `pwb-dev-alerts` (single topic)

## Migration Guide

### For Development

1. Edit credentials:
   ```bash
   rails credentials:edit --environment development
   ```

2. Add:
   ```yaml
   platform_ntfy:
     topic: pwb-dev-alerts
   ```

3. Remove old ENV variables from `.env` (optional cleanup):
   ```bash
   # Remove these lines:
   # PLATFORM_NTFY_ENABLED=true
   # PLATFORM_NTFY_TOPIC_PREFIX=pwb-dev
   # PLATFORM_NTFY_NOTIFY_*=true
   ```

4. Subscribe to new topic in ntfy app:
   - Remove old subscriptions: `pwb-dev-signups`, `pwb-dev-provisioning`, etc.
   - Add new subscription: `pwb-dev-alerts`

### For Production

1. Edit production credentials:
   ```bash
   rails credentials:edit --environment production
   ```

2. Add:
   ```yaml
   platform_ntfy:
     topic: pwb-production-alerts
     access_token: tk_your_production_token  # recommended for production
   ```

3. Update deployment config to remove old ENV variables

4. Subscribe to new topic: `pwb-production-alerts`

## Benefits

### Simpler Configuration
- One topic instead of 5+
- One place to configure (credentials) instead of multiple ENV vars
- Automatic enable/disable based on topic presence

### Better Security
- Credentials are encrypted at rest
- No environment variables to leak
- Per-environment configuration built-in

### Easier Management
- Single ntfy subscription instead of 5
- All notifications in one place
- Easier to share access (just share one topic)

### Cleaner Code
- Removed channel constants
- Removed per-channel enable/disable logic
- Simpler publish method signature

## Code Changes

### Service Changes
- Removed `CHANNEL_*` constants
- Removed `enabled_for?(channel)` method
- Simplified `publish()` to not require `channel:` parameter
- Changed `enabled?` to check `topic.present?`
- Configuration now reads from `Rails.application.credentials`

### Test Changes
- Specs now stub credentials instead of ENV
- Tests still pass (8/8 examples)

### Controller Changes
- `check_configuration` method simplified
- Removed per-channel status

### View Changes
- Shows single topic instead of multiple
- Displays credentials configuration status
- Simplified UI (no channel toggles)

## Testing

```ruby
# Rails console
PlatformNtfyService.enabled?
# => true (if topic is configured)

PlatformNtfyService.test_configuration
# => {success: true, message: "Test notification sent successfully"}

# Check current topic
Rails.application.credentials.dig(:platform_ntfy, :topic)
# => "pwb-dev-alerts"
```

## API Compatibility

All public methods remain the same:
```ruby
# These still work exactly as before
PlatformNtfyService.notify_user_signup(user, reserved_subdomain: 'test')
PlatformNtfyService.notify_provisioning_complete(website)
PlatformNtfyService.notify_subscription_activated(subscription)
PlatformNtfyService.notify_system_alert('Title', 'Message')
```

The only difference is they all go to the same topic now.

## Notifications Still Sent

All 14 notification types still work:
1. User signup
2. Email verified
3. Onboarding complete
4. Provisioning started
5. Website live
6. Provisioning failed
7. Trial started
8. Subscription activated
9. Trial expired
10. Subscription canceled
11. Payment failed
12. Plan changed
13. System alert
14. Daily summary

They just all go to one topic instead of being split across channels.

## Rollback Plan

If needed, restore from backup:
```bash
cp app/services/platform_ntfy_service.rb.backup app/services/platform_ntfy_service.rb
```

And revert spec changes.

## Files Modified

- `app/services/platform_ntfy_service.rb` (simplified configuration)
- `spec/services/platform_ntfy_service_spec.rb` (updated to stub credentials)
- `app/controllers/tenant_admin/platform_notifications_controller.rb` (simplified config check)
- `app/views/tenant_admin/platform_notifications/index.html.erb` (updated UI)
- `config/credentials/development.yml.enc` (added platform_ntfy config)

---

**Status**: ✅ Simplified and Working

The platform ntfy notification system is now simpler, more secure, and easier to manage!
