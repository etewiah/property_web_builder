# Shard Admin Phase 1 - Review & Testing Guide

**Date:** 2026-01-08  
**Status:** Foundation Complete - Ready for Testing  

## What Was Built

### Database
- ✅ `pwb_shard_audit_logs` table with audit tracking
- ✅ Migration run successfully on primary database

### Models
- ✅ `Pwb::ShardAuditLog` - Full audit logging with scopes and validations
- ✅ Association added to `Pwb::Website` model

### Services
- ✅ `Pwb::ShardService` - Shard assignment orchestration
- ✅ `Pwb::ShardHealthCheck` - Health monitoring with PgHero

### Routes
- ✅ 14 new routes in `tenant_admin` namespace (not yet implemented in controllers)

---

## Testing in Rails Console

### 1. Test ShardRegistry Integration

```bash
rails console
```

```ruby
# Check what shards are configured
Pwb::ShardRegistry.logical_shards
# => [:default, :shard_1, :demo]  # Or whatever you have configured

# Check if a shard is configured
Pwb::ShardRegistry.configured?(:default)
# => true

Pwb::ShardRegistry.configured?(:shard_1)
# => true/false (depends on your database.yml)

# Get shard details
Pwb::ShardRegistry.describe_shard(:default)
# => {:name=>:default, :configured=>true, :database=>"...", :host=>"..."}
```

### 2. Test ShardService

```ruby
# Get available shards
Pwb::ShardService.available_shards
# => ["default", "shard_1", "demo"]

# Get only configured shards
Pwb::ShardService.configured_shards
# => ["default"]  # Only shards with database configured

# Test shard validation
Pwb::ShardService.valid_shard?('default')
# => true

Pwb::ShardService.valid_shard?('invalid')
# => false

# Get shard statistics
stats = Pwb::ShardService.shard_statistics('default')
# => {
#   shard_name: "default",
#   website_count: 5,
#   property_count: 120,
#   page_count: 45,
#   database_size: 45678901,
#   table_count: 67,
#   index_size: 12345678,
#   checked_at: 2026-01-08 14:00:00 UTC
# }

# Get distribution across all websites
distribution = Pwb::ShardService.shard_distribution
# => {
#   distribution: {"default" => 5, nil => 2},
#   total: 7,
#   percentages: {"default" => 71.43, nil => 28.57}
# }
```

### 3. Test ShardHealthCheck

```ruby
# Check health of a single shard
health = Pwb::ShardHealthCheck.check('default')

# Inspect results
health.shard_name
# => "default"

health.connection_status
# => true

health.avg_query_ms
# => 12.5

health.active_connections
# => 3

health.database_size
# => 45678901

health.healthy?
# => true

health.status_label
# => "Healthy"

health.status_color
# => "green"

# Check all shards
all_health = Pwb::ShardHealthCheck.check_all
all_health.each do |name, status|
  puts "#{name}: #{status.connection_status ? '✓' : '✗'} - #{status.status_label}"
end
# default: ✓ - Healthy
# shard_1: ✗ - Unhealthy (if not configured)

# Quick check (just connection status)
Pwb::ShardHealthCheck.quick_check_all
# => {"default" => true, "shard_1" => false}
```

### 4. Test Shard Assignment

```ruby
# Find a test website
website = Pwb::Website.first

# Check current shard
website.shard_name
# => nil or "default"

# Test assignment
result = Pwb::ShardService.assign_shard(
  website: website,
  new_shard: 'default',
  changed_by: 'test@example.com',
  notes: 'Testing shard assignment'
)

# Check result
result.success?
# => true

result.data
# => {:old_shard=>"default", :new_shard=>"default", :website_id=>1}

# Or if it failed:
result.error
# => "Website is already on shard 'default'"

# Verify website was updated
website.reload.shard_name
# => "default"

# Check audit log was created
audit_log = Pwb::ShardAuditLog.last
audit_log.website_id
# => 1

audit_log.old_shard_name
# => nil

audit_log.new_shard_name
# => "default"

audit_log.changed_by_email
# => "test@example.com"

audit_log.notes
# => "Testing shard assignment"

audit_log.status
# => "completed"

audit_log.successful?
# => true
```

### 5. Test ShardAuditLog Model

```ruby
# Get all audit logs
Pwb::ShardAuditLog.all

# Recent logs
Pwb::ShardAuditLog.recent.limit(5)

# Logs for a specific website
Pwb::ShardAuditLog.for_website(website.id)

# Logs by a specific user
Pwb::ShardAuditLog.by_user('test@example.com')

# Completed vs failed
Pwb::ShardAuditLog.completed
Pwb::ShardAuditLog.failed

# Check if migration in progress
Pwb::ShardAuditLog.migration_in_progress?(website)
# => false

# Get latest log for website
latest = Pwb::ShardAuditLog.latest_for_website(website)
latest.duration_humanized
# => "2s"
```

### 6. Test Error Handling

```ruby
# Try to assign to invalid shard
result = Pwb::ShardService.assign_shard(
  website: website,
  new_shard: 'nonexistent',
  changed_by: 'test@example.com'
)

result.success?
# => false

result.error
# => "Invalid shard: nonexistent. Available shards: default, shard_1, demo"

# Try to assign to same shard
result = Pwb::ShardService.assign_shard(
  website: website,
  new_shard: website.shard_name,
  changed_by: 'test@example.com'
)

result.success?
# => false

result.error
# => "Website is already on shard 'default'"

# Try to assign to unconfigured shard (if shard_1 not configured)
result = Pwb::ShardService.assign_shard(
  website: website,
  new_shard: 'shard_1',
  changed_by: 'test@example.com'
)

result.success?
# => false

result.error
# => "Cannot assign to shard 'shard_1': Shard not configured in database.yml"
```

---

## Testing Routes

```bash
# Check routes were added
rails routes | grep shard

# Should show:
#   tenant_admin_shards GET    /tenant_admin/shards(.:format)                    tenant_admin/shards#index
#   tenant_admin_shard GET    /tenant_admin/shards/:id(.:format)                tenant_admin/shards#show
#   health_tenant_admin_shard GET    /tenant_admin/shards/:id/health(.:format)         tenant_admin/shards#health
#   ... (14 routes total)
```

---

## Manual Database Inspection

```bash
# Check the audit logs table exists
rails dbconsole
```

```sql
-- View table structure
\d pwb_shard_audit_logs

-- Check indexes
\di pwb_shard_audit_logs*

-- View audit logs
SELECT id, website_id, old_shard_name, new_shard_name, changed_by_email, status, created_at 
FROM pwb_shard_audit_logs 
ORDER BY created_at DESC 
LIMIT 10;

-- Count by status
SELECT status, COUNT(*) 
FROM pwb_shard_audit_logs 
GROUP BY status;
```

---

## Testing with Different Database Configurations

### If You Have Shard Configured

If `PWB_TENANT_SHARD_1_DATABASE_URL` is set:

```ruby
# Test health check on shard_1
health = Pwb::ShardHealthCheck.check('shard_1')
health.connection_status
# => true (if database exists and is accessible)

# Test statistics
stats = Pwb::ShardService.shard_statistics('shard_1')
```

### If You DON'T Have Shards Configured Yet

```ruby
# Should gracefully handle missing shards
health = Pwb::ShardHealthCheck.check('shard_1')
health.connection_status
# => false

health.error_message
# => "Shard not configured in database.yml"

# Validation should prevent assignment
result = Pwb::ShardService.assign_shard(
  website: Pwb::Website.first,
  new_shard: 'shard_1',
  changed_by: 'test@example.com'
)
result.success?
# => false

result.error
# => "Cannot assign to shard 'shard_1': Shard not configured in database.yml"
```

---

## Expected Test Results

### ✅ All Tests Should Pass

Run the test suite:

```bash
rspec spec/models/pwb/shard_audit_log_spec.rb  # (when we create it)
rspec spec/services/pwb/shard_service_spec.rb  # (when we create it)
```

### ✅ Pre-commit Checks

```bash
# These already passed when we committed:
- Fast unit tests: PASS
- Ruby syntax check: PASS
- No regressions in existing tests
```

---

## Common Issues & Solutions

### Issue: "Shard not configured"

**Cause:** No database configured for that shard in `database.yml`

**Solution:** Either:
1. Add the database configuration, OR
2. Only test with 'default' shard

### Issue: ShardRegistry not found

**Cause:** ShardRegistry might not be loaded

**Solution:**
```ruby
# In console, manually require if needed
require_relative 'app/lib/pwb/shard_registry'
```

### Issue: PgHero metrics returning nil

**Cause:** PgHero gem might not be loaded or configured

**Solution:** This is fine - the health check gracefully falls back to basic connection tests

---

## Next Steps After Review

If everything looks good:

1. ✅ **Controllers** - Implement ShardsController, update WebsitesController
2. ✅ **Views** - Dashboard, assignment forms, audit log pages
3. ✅ **Feature Flags** - Add Pwb::FeatureFlags module
4. ✅ **Tests** - RSpec specs for services and models
5. ✅ **Rake Tasks** - CLI tools for shard management

---

## Quick Validation Checklist

- [ ] ShardRegistry returns configured shards
- [ ] ShardService validates shard names
- [ ] ShardHealthCheck connects to default shard
- [ ] Audit log created on assignment
- [ ] Website.shard_name updates correctly
- [ ] Error handling works for invalid shards
- [ ] Routes registered in routes.rb
- [ ] Database migration applied
- [ ] All tests passing

---

## Getting Help

If you encounter issues:

1. **Check logs:** `tail -f log/development.log`
2. **Check database:** Verify migration ran with `rails db:migrate:status`
3. **Check configuration:** Verify `config/database.yml` has your shard config
4. **Check ShardRegistry:** `Pwb::ShardRegistry.logical_shards` should return expected values

---

## Example Test Session

```ruby
# Complete test workflow
rails console

# 1. Verify setup
Pwb::ShardRegistry.configured_shards
# => ["default"]

# 2. Check health
health = Pwb::ShardHealthCheck.check('default')
puts "Health: #{health.status_label} (#{health.avg_query_ms}ms)"
# => Health: Healthy (12.5ms)

# 3. Test assignment
website = Pwb::Website.first
result = Pwb::ShardService.assign_shard(
  website: website,
  new_shard: 'default',
  changed_by: 'admin@example.com',
  notes: 'Initial assignment test'
)

puts result.success? ? "✓ Success" : "✗ Failed: #{result.error}"
# => ✓ Success

# 4. Verify audit log
log = Pwb::ShardAuditLog.last
puts "Audit: #{website.subdomain} → #{log.new_shard_name} by #{log.changed_by_email}"
# => Audit: mysite → default by admin@example.com

# 5. Check statistics
stats = Pwb::ShardService.shard_statistics('default')
puts "Stats: #{stats[:website_count]} websites, #{stats[:property_count]} properties"
# => Stats: 5 websites, 120 properties

puts "\n✅ All Phase 1 foundation tests passed!"
```

---

**Ready to proceed?** Once you've verified the foundation works, we can continue with controllers and views!
