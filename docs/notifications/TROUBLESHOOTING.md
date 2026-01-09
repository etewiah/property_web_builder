# Platform ntfy Notifications - Troubleshooting Guide

## Common Issues and Solutions

### 1. SSL Certificate Errors

**Symptoms:**
- Error: `SSL_connect returned=1 errno=0 state=error: certificate verify failed`
- Error: `unable to get certificate CRL`
- Test notifications fail with SSL errors

**Cause:**
OpenSSL on macOS may have issues verifying ntfy.sh SSL certificates, especially in development.

**Solution:**
The service automatically handles this in development/test environments by disabling SSL verification. No action needed for development!

**For Production:**
Ensure proper SSL certificates are installed:
```bash
# macOS
brew install openssl
brew upgrade openssl

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install ca-certificates

# Set custom CA bundle if needed
export SSL_CERT_FILE=/path/to/ca-bundle.crt
```

### 2. Notifications Not Received

**Check 1: Is ntfy enabled?**
```ruby
# Rails console
PlatformNtfyService.enabled?
# Should return: true
```

**Check 2: Configuration**
```ruby
ENV['PLATFORM_NTFY_ENABLED']  # Should be 'true'
ENV['PLATFORM_NTFY_TOPIC_PREFIX']  # Should match your subscriptions
```

**Check 3: Test configuration**
```ruby
PlatformNtfyService.test_configuration
# Should return: {success: true, message: "Test notification sent successfully"}
```

**Check 4: Verify topic subscriptions**
In your ntfy app, make sure you're subscribed to the correct topics:
- `[prefix]-signups`
- `[prefix]-provisioning`
- `[prefix]-subscriptions`
- `[prefix]-system`
- `[prefix]-test`

Replace `[prefix]` with your `PLATFORM_NTFY_TOPIC_PREFIX` value.

### 3. "Platform ntfy is not enabled" Error

**Cause:**
`PLATFORM_NTFY_ENABLED` environment variable is not set to 'true'.

**Solution:**
```bash
# .env file or environment
PLATFORM_NTFY_ENABLED=true
```

Restart your Rails server after changing environment variables.

### 4. Test Notifications Work but Automatic Ones Don't

**Possible Causes:**

1. **Jobs not processing**
   ```ruby
   # Check Solid Queue
   SolidQueue::Job.where(queue_name: 'notifications').pending.count
   # Should be 0 or low
   ```

2. **Specific channel disabled**
   ```bash
   # Check channel settings
   echo $PLATFORM_NTFY_NOTIFY_SIGNUPS
   echo $PLATFORM_NTFY_NOTIFY_PROVISIONING
   echo $PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS
   ```

3. **Callbacks not firing**
   ```ruby
   # Test manually
   user = Pwb::User.first
   PlatformNtfyService.notify_user_signup(user, reserved_subdomain: 'test')
   ```

### 5. Wrong Topics Being Used

**Check:**
```ruby
# Rails console
ENV['PLATFORM_NTFY_TOPIC_PREFIX']
# Example: 'pwb-production'
```

The actual topic names will be:
- `pwb-production-signups`
- `pwb-production-provisioning`
- etc.

**Solution:**
Update your ntfy app subscriptions to match the prefix.

### 6. Network/Firewall Issues

**Test direct connection:**
```bash
curl -d "Test message" https://ntfy.sh/pwb-test
```

If this fails, you may have firewall/proxy issues blocking ntfy.sh.

**Solutions:**
- Check corporate firewall settings
- Use a self-hosted ntfy server
- Configure proxy if needed

### 7. Notifications Delayed

**Cause:**
Solid Queue backlog or job processing delays.

**Check:**
```ruby
SolidQueue::Job.where(queue_name: 'notifications').count
```

**Solution:**
- Ensure Solid Queue workers are running
- Check for failed jobs: `SolidQueue::Job.failed.count`
- Retry failed jobs if needed

### 8. Priority Levels Not Working

**Note:**
Priority only affects mobile notification behavior, not delivery.

**Priority Levels:**
- 1 = Min (silent)
- 2 = Low (quiet)
- 3 = Default (normal)
- 4 = High (important)
- 5 = Urgent (critical)

Configure per-topic priority in your ntfy mobile app settings.

### 9. Access Token Not Working

**If using private topics:**

```bash
PLATFORM_NTFY_ACCESS_TOKEN=tk_your_token_here
```

**Verify token:**
```bash
curl -H "Authorization: Bearer tk_your_token_here" \
     -d "Test" \
     https://ntfy.sh/your-private-topic
```

### 10. Tenant Admin UI Not Accessible

**Symptoms:**
- 404 error on `/tenant_admin/platform_notifications`
- "Unauthorized" error

**Solutions:**

1. **Check you're logged in as tenant admin:**
   ```ruby
   # Rails console
   user = Pwb::User.find_by(email: 'your@email.com')
   ENV['TENANT_ADMIN_EMAILS'].split(',').include?(user.email)
   # Should return true
   ```

2. **Verify routes:**
   ```bash
   bundle exec rails routes | grep platform_notifications
   ```

3. **Check TENANT_ADMIN_EMAILS:**
   ```bash
   echo $TENANT_ADMIN_EMAILS
   # Should include your email
   ```

## Quick Diagnostic Script

Run this in Rails console to diagnose issues:

```ruby
puts "=== Platform ntfy Diagnostics ==="
puts ""
puts "Configuration:"
puts "  Enabled: #{PlatformNtfyService.enabled?}"
puts "  Server: #{ENV.fetch('PLATFORM_NTFY_SERVER_URL', 'https://ntfy.sh')}"
puts "  Prefix: #{ENV.fetch('PLATFORM_NTFY_TOPIC_PREFIX', 'pwb-platform')}"
puts "  Token: #{ENV['PLATFORM_NTFY_ACCESS_TOKEN'].present? ? 'Set' : 'Not set'}"
puts ""
puts "Channels:"
puts "  Signups: #{ENV.fetch('PLATFORM_NTFY_NOTIFY_SIGNUPS', 'true')}"
puts "  Provisioning: #{ENV.fetch('PLATFORM_NTFY_NOTIFY_PROVISIONING', 'true')}"
puts "  Subscriptions: #{ENV.fetch('PLATFORM_NTFY_NOTIFY_SUBSCRIPTIONS', 'true')}"
puts "  System Health: #{ENV.fetch('PLATFORM_NTFY_NOTIFY_SYSTEM_HEALTH', 'true')}"
puts ""
puts "Testing configuration..."
result = PlatformNtfyService.test_configuration
puts "  Result: #{result[:success] ? '✅ SUCCESS' : '❌ FAILED'}"
puts "  Message: #{result[:message]}"
puts ""
puts "Jobs:"
puts "  Pending: #{SolidQueue::Job.where(queue_name: 'notifications').pending.count}"
puts "  Failed: #{SolidQueue::Job.failed.count}"
```

## Getting Help

1. **Check logs:**
   ```bash
   tail -f log/development.log | grep PlatformNtfy
   ```

2. **Enable debug logging:**
   ```ruby
   Rails.logger.level = :debug
   ```

3. **Test manually:**
   ```ruby
   PlatformNtfyService.publish(
     channel: 'test',
     title: 'Manual Test',
     message: 'Testing from console',
     priority: 3
   )
   ```

4. **Review documentation:**
   - See `docs/notifications/README.md` for overview
   - See `docs/notifications/PLATFORM_NTFY_QUICK_REFERENCE.md` for setup

## Still Having Issues?

Check the implementation for known limitations in:
`docs/notifications/TENANT_ADMIN_UI_SUMMARY.md`

The most common issue is SSL certificates in development, which is automatically handled by the service!
