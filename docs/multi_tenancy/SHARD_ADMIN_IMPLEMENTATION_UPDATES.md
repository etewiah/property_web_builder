# Shard Admin Implementation Plan - Updates Based on Code Review

**Date:** 2026-01-08  
**Status:** Integrated into main plan  
**Purpose:** Document corrections and enhancements based on actual codebase analysis

This document contains the updates applied to `SHARD_ADMIN_IMPLEMENTATION_PLAN.md` based on the actual codebase review.

---

## Summary of Changes

1. ✅ Corrected ShardRegistry API usage
2. ✅ Fixed migrator class name (TenantShardMigrator vs ShardMigrator)
3. ✅ Added PgHero integration for health checks
4. ✅ Added Turbo/Stimulus modern UI patterns
5. ✅ Added Rake tasks for CLI access
6. ✅ Added background job for async migrations
7. ✅ Added API endpoints for monitoring
8. ✅ Added feature flags for gradual rollout
9. ✅ Added risk mitigation strategies
10. ✅ Updated routes to follow existing patterns

---

## 1. Corrected Shard Registry API

**Was:**
```ruby
Pwb::ShardRegistry.available_shards  # ❌ This method doesn't exist
```

**Now:**
```ruby
# Actual API from app/lib/pwb/shard_registry.rb
Pwb::ShardRegistry.logical_shards        # => [:default, :shard_1, :shard_2, :demo]
Pwb::ShardRegistry.configured?(:demo)     # => true/false
Pwb::ShardRegistry.describe_shard(:demo)  # => {name:, configured:, database:, host:}
```

**Updated in:**
- `Pwb::ShardService.available_shards`
- `Pwb::ShardService.valid_shard?`
- Controller implementations

---

## 2. Corrected Migrator Class Name

**Was:**
```ruby
Pwb::ShardMigrator  # ❌ Wrong class name
```

**Now:**
```ruby
Pwb::TenantShardMigrator  # ✅ Actual class
# app/services/pwb/tenant_shard_migrator.rb
```

**Usage:**
```ruby
migrator = Pwb::TenantShardMigrator.new(
  website: website,
  target_shard: 'shard_1',
  logger: Rails.logger
)
migrator.call
```

---

## 3. Enhanced Health Checks with PgHero

**Added PgHero integration for richer database metrics:**

```ruby
# app/services/pwb/shard_health_check.rb
def self.check(shard_name)
  shard_sym = shard_name.to_sym
  
  # Validate shard is configured
  unless Pwb::ShardRegistry.configured?(shard_sym)
    return HealthStatus.new(
      shard_name: shard_name,
      connection_status: false,
      error_message: "Shard not configured in database.yml"
    )
  end
  
  begin
    PwbTenant::ApplicationRecord.connected_to(shard: shard_sym) do
      HealthStatus.new(
        shard_name: shard_name,
        connection_status: test_connection,
        avg_query_ms: measure_query_time,
        
        # PgHero metrics
        active_connections: PgHero.connections.count,
        database_size: PgHero.database_size,
        slow_queries_count: PgHero.slow_queries(limit: 100).count,
        index_hit_rate: PgHero.index_hit_rate,
        table_sizes: PgHero.relation_sizes.first(10),
        cache_hit_rate: PgHero.cache_hit_rate,
        
        checked_at: Time.current,
        error_message: nil
      )
    end
  rescue => e
    # Graceful error handling
    HealthStatus.new(
      shard_name: shard_name,
      connection_status: false,
      avg_query_ms: nil,
      active_connections: 0,
      checked_at: Time.current,
      error_message: e.message
    )
  end
end
```

**Benefits:**
- Leverage existing PgHero installation
- Richer metrics (slow queries, index usage, cache hits)
- Consistent with existing monitoring tools

---

## 4. Added Turbo/Stimulus Integration

### Turbo Streams for Instant UI Updates

```ruby
# app/controllers/tenant_admin/websites_controller.rb
def assign_shard
  result = Pwb::ShardService.assign_shard(
    website: @website,
    new_shard: params[:shard_name],
    changed_by: current_user.email,
    notes: params[:notes]
  )

  respond_to do |format|
    if result.success?
      format.turbo_stream {
        render turbo_stream: [
          # Update shard badge inline
          turbo_stream.replace(
            "shard_badge_#{@website.id}",
            partial: "shard_badge",
            locals: { website: @website }
          ),
          
          # Show success message
          turbo_stream.prepend(
            "flash_messages",
            partial: "shared/flash",
            locals: { type: :notice, message: "Assigned to #{params[:shard_name]}" }
          )
        ]
      }
      format.html { redirect_to tenant_admin_website_path(@website), notice: "..." }
    else
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "shard_form",
          partial: "shard_form",
          locals: { website: @website, error: result.error }
        )
      }
      format.html { render :shard_form, status: :unprocessable_entity }
    end
  end
end
```

### Stimulus Controller for Dynamic Forms

```javascript
// app/javascript/controllers/shard_assignment_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shardSelect", "warningMessage", "statsContainer"]
  static values = { currentShard: String }

  connect() {
    this.updateWarning()
  }

  updateWarning() {
    const selected = this.shardSelectTarget.value
    const isSameShard = selected === this.currentShardValue

    // Hide warning if same shard selected
    this.warningMessageTarget.classList.toggle("hidden", isSameShard)
  }

  async loadShardStats(event) {
    const shardName = event.target.value
    
    try {
      const response = await fetch(`/tenant_admin/shards/${shardName}/statistics.json`)
      const stats = await response.json()
      this.statsContainerTarget.innerHTML = this.renderStats(stats)
    } catch (error) {
      console.error('Failed to load shard stats:', error)
      this.statsContainerTarget.innerHTML = '<div class="alert alert-error">Failed to load statistics</div>'
    }
  }

  renderStats(stats) {
    return `
      <div class="stats stats-vertical shadow">
        <div class="stat">
          <div class="stat-title">Websites</div>
          <div class="stat-value">${stats.website_count.toLocaleString()}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Database Size</div>
          <div class="stat-value text-sm">${this.formatBytes(stats.database_size)}</div>
        </div>
        <div class="stat">
          <div class="stat-title">Capacity</div>
          <div class="stat-value text-sm">${stats.capacity_percent}%</div>
        </div>
      </div>
    `
  }

  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
}
```

---

## 5. Added Rake Tasks for CLI Management

```ruby
# lib/tasks/shard_admin.rake
namespace :pwb do
  namespace :shards do
    desc "List all shards with status and website count"
    task status: :environment do
      puts "\n=== Shard Status ==="
      puts "%-15s %-10s %-12s %s" % ["Shard", "Status", "Websites", "Database"]
      puts "-" * 70
      
      Pwb::ShardRegistry.logical_shards.each do |shard|
        info = Pwb::ShardRegistry.describe_shard(shard)
        status = info[:configured] ? "✓ Ready" : "✗ Not Configured"
        count = Pwb::Website.unscoped.where(shard_name: shard.to_s).count
        database = info[:database] || 'N/A'
        
        puts "%-15s %-10s %-12d %s" % [shard, status, count, database]
      end
      
      puts "\n"
    end

    desc "Assign website to shard - Usage: bin/rails pwb:shards:assign[42,shard_1]"
    task :assign, [:website_id, :shard_name] => :environment do |t, args|
      unless args[:website_id] && args[:shard_name]
        puts "Usage: bin/rails pwb:shards:assign[WEBSITE_ID,SHARD_NAME]"
        puts "Example: bin/rails pwb:shards:assign[42,shard_1]"
        exit 1
      end
      
      website = Pwb::Website.unscoped.find(args[:website_id])
      
      puts "Assigning website ##{website.id} (#{website.subdomain}) to shard '#{args[:shard_name]}'..."
      
      result = Pwb::ShardService.assign_shard(
        website: website,
        new_shard: args[:shard_name],
        changed_by: "rake:#{ENV['USER']}",
        notes: "CLI assignment via rake task"
      )
      
      if result.success?
        puts "✓ Success! Website assigned to #{args[:shard_name]}"
        puts "  Old shard: #{result.data[:old_shard]}"
        puts "  New shard: #{result.data[:new_shard]}"
      else
        puts "✗ Failed: #{result.error}"
        exit 1
      end
    end

    desc "Health check all configured shards"
    task health: :environment do
      puts "\n=== Shard Health Check ==="
      puts "%-15s %-12s %-10s %-15s %s" % ["Shard", "Status", "Query MS", "Connections", "DB Size"]
      puts "-" * 80
      
      Pwb::ShardHealthCheck.check_all.each do |name, status|
        status_icon = status.connection_status ? "✓" : "✗"
        query_ms = status.avg_query_ms ? "#{status.avg_query_ms}ms" : "N/A"
        connections = status.active_connections || 0
        db_size = status.database_size ? number_to_human_size(status.database_size) : "N/A"
        
        puts "%-15s %-12s %-10s %-15d %s" % [name, status_icon, query_ms, connections, db_size]
        
        if status.error_message
          puts "  Error: #{status.error_message}"
        end
      end
      
      puts "\n"
    end
    
    desc "Show detailed statistics for a shard"
    task :stats, [:shard_name] => :environment do |t, args|
      unless args[:shard_name]
        puts "Usage: bin/rails pwb:shards:stats[SHARD_NAME]"
        puts "Example: bin/rails pwb:shards:stats[shard_1]"
        exit 1
      end
      
      stats = Pwb::ShardService.shard_statistics(args[:shard_name])
      
      if stats[:error]
        puts "Error: #{stats[:error]}"
        exit 1
      end
      
      puts "\n=== Shard: #{args[:shard_name]} ==="
      puts "Websites:     #{stats[:website_count]}"
      puts "Properties:   #{stats[:property_count]}"
      puts "Pages:        #{stats[:page_count]}"
      puts "DB Size:      #{number_to_human_size(stats[:database_size])}"
      puts "Tables:       #{stats[:table_count]}"
      puts "Index Size:   #{number_to_human_size(stats[:index_size])}"
      puts "\n"
    end
  end
end

def number_to_human_size(bytes)
  return '0 Bytes' if bytes == 0
  k = 1024
  sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB']
  i = Math.log(bytes) / Math.log(k)
  "#{(bytes / (k ** i.floor)).round(2)} #{sizes[i.floor]}"
end
```

**Usage Examples:**
```bash
# List all shards
bin/rails pwb:shards:status

# Assign website to shard
bin/rails pwb:shards:assign[42,shard_1]

# Health check
bin/rails pwb:shards:health

# Detailed stats
bin/rails pwb:shards:stats[shard_1]
```

---

## 6. Background Migration Job (Phase 3)

```ruby
# app/jobs/pwb/shard_migration_job.rb
module Pwb
  class ShardMigrationJob < ApplicationJob
    queue_as :low_priority
    
    # Track progress for long-running migrations
    include ProgressTrackable
    
    def perform(website_id:, target_shard:, initiated_by:, audit_log_id:)
      website = Pwb::Website.unscoped.find(website_id)
      audit_log = Pwb::ShardAuditLog.find(audit_log_id)

      begin
        # Update status to in_progress
        audit_log.update!(status: 'in_progress', notes: "#{audit_log.notes}\n\nMigration started at #{Time.current}")

        # Create migrator instance
        migrator = Pwb::TenantShardMigrator.new(
          website: website,
          target_shard: target_shard,
          logger: Rails.logger
        )
        
        # Perform migration
        update_progress(0, "Starting migration...")
        migrator.call
        update_progress(100, "Migration complete")

        # Mark as completed
        audit_log.update!(
          status: 'completed',
          notes: "#{audit_log.notes}\n\nCompleted at #{Time.current}"
        )
        
        # Notify admin
        ShardAdminMailer.migration_complete(
          audit_log: audit_log,
          recipient: initiated_by
        ).deliver_later

      rescue StandardError => e
        # Mark as failed
        audit_log.update!(
          status: 'failed',
          notes: "#{audit_log.notes}\n\nFailed at #{Time.current}\nError: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        )
        
        # Notify admin of failure
        ShardAdminMailer.migration_failed(
          audit_log: audit_log,
          error: e,
          recipient: initiated_by
        ).deliver_later
        
        # Re-raise to mark job as failed
        raise
      end
    end
    
    private
    
    def update_progress(percent, message)
      # Store progress in Redis/Solid Cache for UI display
      Rails.cache.write(
        "migration_progress_#{arguments.first[:audit_log_id]}",
        { percent: percent, message: message, updated_at: Time.current },
        expires_in: 1.hour
      )
    end
  end
end
```

**Controller integration:**
```ruby
# app/controllers/tenant_admin/websites_controller.rb
def migrate_shard
  # Create audit log entry
  audit_log = Pwb::ShardAuditLog.create!(
    website: @website,
    old_shard_name: @website.shard_name,
    new_shard_name: params[:target_shard],
    changed_by_email: current_user.email,
    status: 'pending',
    notes: "Migration initiated via web UI"
  )
  
  # Queue background job
  Pwb::ShardMigrationJob.perform_later(
    website_id: @website.id,
    target_shard: params[:target_shard],
    initiated_by: current_user.email,
    audit_log_id: audit_log.id
  )
  
  redirect_to tenant_admin_website_path(@website),
    notice: "Migration queued. You'll receive an email when complete. Track progress in audit logs."
end
```

---

## 7. API Endpoints for Monitoring Tools

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :shards, only: [:index] do
      collection do
        get :health
        get :distribution
      end
      member do
        get :statistics
      end
    end
  end
end

# app/controllers/api/v1/shards_controller.rb
module Api
  module V1
    class ShardsController < ApiController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api_token!

      # GET /api/v1/shards
      def index
        shards = Pwb::ShardRegistry.logical_shards.map do |shard_name|
          info = Pwb::ShardRegistry.describe_shard(shard_name)
          website_count = Pwb::Website.unscoped.where(shard_name: shard_name.to_s).count
          
          info.merge(
            shard_name: shard_name.to_s,
            website_count: website_count,
            configured: info[:configured]
          )
        end
        
        render json: { shards: shards }
      end

      # GET /api/v1/shards/health
      def health
        health_checks = Pwb::ShardHealthCheck.check_all.transform_values do |status|
          {
            shard_name: status.shard_name,
            connection_status: status.connection_status,
            avg_query_ms: status.avg_query_ms,
            active_connections: status.active_connections,
            database_size: status.database_size,
            checked_at: status.checked_at,
            error_message: status.error_message
          }
        end
        
        render json: { health: health_checks, checked_at: Time.current }
      end
      
      # GET /api/v1/shards/distribution
      def distribution
        distribution = Pwb::Website.unscoped.group(:shard_name).count
        total = Pwb::Website.unscoped.count
        
        percentages = distribution.transform_values do |count|
          total > 0 ? ((count.to_f / total) * 100).round(2) : 0
        end
        
        render json: {
          distribution: distribution,
          percentages: percentages,
          total: total
        }
      end
      
      # GET /api/v1/shards/:id/statistics
      def statistics
        shard_name = params[:id]
        
        unless Pwb::ShardRegistry.configured?(shard_name.to_sym)
          return render json: { error: "Shard not configured" }, status: :not_found
        end
        
        stats = Pwb::ShardService.shard_statistics(shard_name)
        render json: { shard: shard_name, statistics: stats }
      end

      private

      def authenticate_api_token!
        token = request.headers['Authorization']&.remove('Bearer ')
        expected_token = ENV['SHARD_API_TOKEN']
        
        unless expected_token.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected_token)
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end
    end
  end
end
```

**Usage:**
```bash
# Get all shards
curl -H "Authorization: Bearer $SHARD_API_TOKEN" \
     https://app.example.com/api/v1/shards

# Health check
curl -H "Authorization: Bearer $SHARD_API_TOKEN" \
     https://app.example.com/api/v1/shards/health

# Distribution
curl -H "Authorization: Bearer $SHARD_API_TOKEN" \
     https://app.example.com/api/v1/shards/distribution

# Shard statistics
curl -H "Authorization: Bearer $SHARD_API_TOKEN" \
     https://app.example.com/api/v1/shards/shard_1/statistics
```

---

## 8. Feature Flags for Gradual Rollout

```ruby
# app/models/pwb/feature_flags.rb
module Pwb
  module FeatureFlags
    # Shard admin viewing/read-only access
    def self.shard_admin_enabled?
      ENV.fetch('SHARD_ADMIN_ENABLED', 'false') == 'true'
    end
    
    # Shard assignment (write operations)
    def self.shard_assignment_enabled?
      shard_admin_enabled? && ENV.fetch('SHARD_ASSIGNMENT_ENABLED', 'false') == 'true'
    end
    
    # Data migrations between shards (Phase 3)
    def self.shard_migrations_enabled?
      shard_assignment_enabled? && ENV.fetch('SHARD_MIGRATIONS_ENABLED', 'false') == 'true'
    end
    
    # Bulk operations
    def self.shard_bulk_operations_enabled?
      shard_assignment_enabled? && ENV.fetch('SHARD_BULK_OPS_ENABLED', 'false') == 'true'
    end
  end
end

# app/controllers/tenant_admin/shards_controller.rb
class ShardsController < TenantAdminController
  before_action :require_feature_enabled!

  private

  def require_feature_enabled!
    unless Pwb::FeatureFlags.shard_admin_enabled?
      redirect_to tenant_admin_root_path, 
        alert: "Shard admin is not yet enabled. Contact system administrator."
    end
  end
end

# app/controllers/tenant_admin/websites_controller.rb
def assign_shard
  unless Pwb::FeatureFlags.shard_assignment_enabled?
    return redirect_to tenant_admin_website_path(@website),
      alert: "Shard assignment is not enabled"
  end
  
  # ... assignment logic
end

def migrate_shard
  unless Pwb::FeatureFlags.shard_migrations_enabled?
    return redirect_to tenant_admin_website_path(@website),
      alert: "Shard migrations are not enabled"
  end
  
  # ... migration logic
end
```

**Rollout Strategy:**
```bash
# Stage 1: Enable read-only viewing (Week 1)
dokku config:set app SHARD_ADMIN_ENABLED=true

# Stage 2: Enable shard assignment after testing (Week 2)
dokku config:set app SHARD_ASSIGNMENT_ENABLED=true

# Stage 3: Enable migrations after successful assignments (Week 3)
dokku config:set app SHARD_MIGRATIONS_ENABLED=true

# Stage 4: Enable bulk operations (optional)
dokku config:set app SHARD_BULK_OPS_ENABLED=true
```

---

## 9. Risk Mitigation Strategies

### Risk Assessment Matrix

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Assigning to unconfigured shard | Critical | Medium | Validate with `ShardRegistry.configured?` before assignment |
| Data loss during migration | Critical | Low | Transactions, verification, keep source until confirmed |
| Permission escalation | High | Low | Double-check `TENANT_ADMIN_EMAILS`, audit all operations |
| Concurrent migrations | High | Medium | Use `with_lock`, queue single migration at a time |
| Production misconfiguration | High | Medium | Confirmation dialogs, feature flags, dry-run mode |
| Shard connection failure | Medium | Low | Graceful degradation, health monitoring, alerts |
| Accidental bulk assignment | High | Medium | Preview before action, explicit confirmation required |

### Mitigation Implementations

**1. Pre-Assignment Validation:**
```ruby
def self.assign_shard(website:, new_shard:, changed_by:, notes: nil)
  # Validate shard exists and is configured
  unless Pwb::ShardRegistry.configured?(new_shard.to_sym)
    available = Pwb::ShardRegistry.logical_shards
      .select { |s| Pwb::ShardRegistry.configured?(s) }
      .map(&:to_s)
      .join(', ')
      
    return Result.new(
      success: false,
      error: "Shard '#{new_shard}' is not configured. Available shards: #{available}"
    )
  end
  
  # Warn if shard has connection issues
  health = Pwb::ShardHealthCheck.check(new_shard)
  unless health.connection_status
    return Result.new(
      success: false,
      error: "Shard '#{new_shard}' is not accessible: #{health.error_message}"
    )
  end
  
  # ... proceed with assignment
end
```

**2. Migration with Verification:**
```ruby
class Pwb::TenantShardMigrator
  def call
    website.with_lock do
      # Count records in source
      source_counts = count_all_tables(source_shard)
      
      # Perform migration
      migrate_all_data
      
      # Count records in target
      target_counts = count_all_tables(target_shard)
      
      # Verify counts match
      unless counts_match?(source_counts, target_counts)
        raise MigrationVerificationError, "Record counts don't match!\nSource: #{source_counts}\nTarget: #{target_counts}"
      end
      
      # Update website shard_name only after verification
      website.update!(shard_name: target_shard)
    end
  end
  
  private
  
  def counts_match?(source, target)
    source.keys.all? do |table|
      source[table] == target[table]
    end
  end
end
```

**3. Production Safety Confirmation:**
```ruby
# app/controllers/tenant_admin/websites_controller.rb
def assign_shard
  # Require explicit confirmation in production
  if Rails.env.production? && params[:confirm] != calculate_confirmation_token
    @confirmation_token = calculate_confirmation_token
    render :confirm_shard_assignment
    return
  end
  
  # Proceed with assignment
  result = Pwb::ShardService.assign_shard(...)
  # ...
end

private

def calculate_confirmation_token
  # Generate token based on operation details
  Digest::SHA256.hexdigest(
    "#{@website.id}:#{params[:shard_name]}:#{Date.current}"
  )[0..7]
end
```

**4. Concurrent Operation Prevention:**
```ruby
# app/models/pwb/shard_audit_log.rb
class ShardAuditLog < ApplicationRecord
  scope :in_progress, -> { where(status: ['pending', 'in_progress']) }
  
  def self.migration_in_progress?(website)
    where(website: website, status: ['pending', 'in_progress']).exists?
  end
end

# In controller
def migrate_shard
  if Pwb::ShardAuditLog.migration_in_progress?(@website)
    return redirect_to tenant_admin_website_path(@website),
      alert: "A migration is already in progress for this website"
  end
  
  # ... proceed
end
```

---

## 10. Updated Routes (Following Existing Patterns)

```ruby
# config/routes.rb
namespace :tenant_admin do
  resources :websites do
    member do
      # Existing actions
      get :seed, action: :seed_form
      post :seed
      post :retry_provisioning
      
      # NEW: Shard management (follows seed pattern)
      get :shard, action: :shard_form      # Show shard assignment form
      patch :assign_shard                   # Perform assignment
      post :migrate_shard                   # Trigger migration (Phase 3 only)
      get :shard_history                    # View assignment history
    end
    
    collection do
      get :shard_distribution               # Overview of all shards
      post :bulk_assign_shard               # Bulk assignment (if feature enabled)
    end
  end
  
  # Standalone shard management dashboard
  resources :shards, only: [:index, :show] do
    member do
      get :health                           # Health check details
      get :websites                         # Websites on this shard
      get :statistics                       # Detailed stats
    end
    
    collection do
      get :health_summary                   # Quick health of all shards
    end
  end
  
  # Shard audit logs
  resources :shard_audit_logs, only: [:index, :show] do
    collection do
      get 'website/:website_id', action: :website_logs, as: :website
      get 'user/:email', action: :user_logs, as: :user
    end
  end
end
```

---

## Environment Variables Reference

```bash
# Required
TENANT_ADMIN_EMAILS=admin@example.com,superadmin@example.com

# Optional Shard Databases
PWB_TENANT_SHARD_1_DATABASE_URL=postgresql://user:pass@host:5432/db_shard_1
PWB_DEMO_SHARD_DATABASE_URL=postgresql://user:pass@host:5432/db_demo

# Feature Flags (Progressive Rollout)
SHARD_ADMIN_ENABLED=true              # View shards
SHARD_ASSIGNMENT_ENABLED=true         # Assign websites to shards
SHARD_MIGRATIONS_ENABLED=true         # Data migration (Phase 3)
SHARD_BULK_OPS_ENABLED=true          # Bulk operations

# Monitoring API
SHARD_API_TOKEN=your-secure-token-here

# Optional Monitoring
SHARD_HEALTH_CHECK_INTERVAL=300       # seconds
SHARD_IMBALANCE_THRESHOLD=0.2         # 20% difference triggers alert
```

---

## Testing Additions

### Integration Test with Actual ShardRegistry

```ruby
# spec/services/pwb/shard_service_spec.rb
RSpec.describe Pwb::ShardService do
  describe '.available_shards' do
    it 'uses ShardRegistry API' do
      expect(Pwb::ShardRegistry).to receive(:logical_shards).and_return([:default, :shard_1])
      
      shards = described_class.available_shards
      expect(shards).to eq(['default', 'shard_1'])
    end
  end
  
  describe '.valid_shard?' do
    it 'validates using ShardRegistry.configured?' do
      expect(Pwb::ShardRegistry).to receive(:configured?).with(:shard_1).and_return(true)
      
      expect(described_class.valid_shard?('shard_1')).to be true
    end
    
    it 'rejects unconfigured shards' do
      expect(Pwb::ShardRegistry).to receive(:configured?).with(:invalid).and_return(false)
      
      expect(described_class.valid_shard?('invalid')).to be false
    end
  end
end
```

---

## Documentation Additions

### Quick Reference Card

Create `docs/multi_tenancy/SHARD_ADMIN_QUICK_REFERENCE.md`:

```markdown
# Shard Admin Quick Reference

## CLI Commands

```bash
# Status check
bin/rails pwb:shards:status

# Assign website to shard
bin/rails pwb:shards:assign[WEBSITE_ID,SHARD_NAME]

# Health check
bin/rails pwb:shards:health

# Statistics
bin/rails pwb:shards:stats[SHARD_NAME]
```

## Web UI URLs

- Dashboard: `/tenant_admin/shards`
- Health Check: `/tenant_admin/shards/health_summary`
- Website Shard Form: `/tenant_admin/websites/:id/shard`
- Audit Logs: `/tenant_admin/shard_audit_logs`

## API Endpoints

```bash
# Authentication required: Authorization: Bearer $SHARD_API_TOKEN

GET  /api/v1/shards               # List all shards
GET  /api/v1/shards/health        # Health check
GET  /api/v1/shards/distribution  # Distribution stats
GET  /api/v1/shards/:id/statistics # Shard details
```

## Feature Flags

Enable progressively for safety:

1. `SHARD_ADMIN_ENABLED=true` - View only
2. `SHARD_ASSIGNMENT_ENABLED=true` - Assign websites
3. `SHARD_MIGRATIONS_ENABLED=true` - Data migration
4. `SHARD_BULK_OPS_ENABLED=true` - Bulk operations

## Emergency Procedures

### Rollback Shard Assignment
```ruby
# Rails console
website = Pwb::Website.find(ID)
Pwb::ShardService.assign_shard(
  website: website,
  new_shard: 'default',  # or previous shard
  changed_by: 'emergency@example.com',
  notes: 'Emergency rollback'
)
```

### Check Shard Health
```bash
bin/rails pwb:shards:health
```

### View Recent Changes
```bash
# In Rails console
Pwb::ShardAuditLog.recent.limit(10).each do |log|
  puts "#{log.created_at}: #{log.website.subdomain} → #{log.new_shard_name} (#{log.changed_by_email})"
end
```
```

---

## Summary

All updates have been incorporated to align the implementation plan with:

✅ Actual codebase APIs (ShardRegistry, TenantShardMigrator)  
✅ Existing infrastructure (PgHero, Turbo, Stimulus, Solid Queue)  
✅ Existing patterns (seed_form/seed action structure)  
✅ Modern Rails practices (Turbo Streams, Stimulus controllers)  
✅ Safety measures (feature flags, confirmations, validation)  
✅ Operational needs (Rake tasks, API endpoints, monitoring)  

The plan is now production-ready and accurately reflects the codebase structure.
