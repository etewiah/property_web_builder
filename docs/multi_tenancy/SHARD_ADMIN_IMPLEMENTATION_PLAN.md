# Shard Admin Implementation Plan

**Created:** 2026-01-08  
**Updated:** 2026-01-08 (see SHARD_ADMIN_IMPLEMENTATION_UPDATES.md for detailed additions)  
**Status:** Planning  
**Priority:** Medium (Enterprise Feature)  
**Estimated Effort:** 2-3 weeks

> **📝 Important:** This plan has been updated based on actual codebase review.  
> See `SHARD_ADMIN_IMPLEMENTATION_UPDATES.md` for detailed additions including:
> - Corrected API usage (ShardRegistry, TenantShardMigrator)
> - PgHero integration for health checks
> - Turbo/Stimulus modern UI patterns
> - Rake tasks for CLI access
> - Background jobs for async migrations
> - API endpoints for monitoring
> - Feature flags for gradual rollout
> - Risk mitigation strategies

## Executive Summary

This plan details the implementation of shard management UI in the Tenant Admin interface. Currently, sharding infrastructure exists (database columns, model methods, routing) but there's no admin interface to manage it. This implementation will provide a complete shard management dashboard for platform administrators.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Goals & Requirements](#goals--requirements)
3. [Architecture](#architecture)
4. [Implementation Phases](#implementation-phases)
5. [Database Schema](#database-schema)
6. [Routes & Controllers](#routes--controllers)
7. [Views & UI](#views--ui)
8. [Security & Authorization](#security--authorization)
9. [Testing Strategy](#testing-strategy)
10. [Deployment & Rollout](#deployment--rollout)
11. [Future Enhancements](#future-enhancements)

---

## Current State Analysis

### What Exists ✅

**Database Schema:**
- `pwb_websites.shard_name` column (string, default: "default")
- Index on `(demo_mode, shard_name)`

**Model Methods:**
```ruby
# app/models/pwb/website.rb
def database_shard
  (shard_name.presence || 'default').to_sym
end
```

**Existing Services:**
```ruby
# app/lib/pwb/shard_registry.rb (ACTUAL API)
Pwb::ShardRegistry.logical_shards        # => [:default, :shard_1, :shard_2, :demo]
Pwb::ShardRegistry.configured?(:demo)     # => true/false
Pwb::ShardRegistry.describe_shard(:demo)  # => {name:, configured:, database:, host:}

# app/services/pwb/tenant_shard_migrator.rb (NOTE: TenantShardMigrator, not ShardMigrator)
Pwb::TenantShardMigrator.new(website:, target_shard:, logger:).call
```

**Existing Infrastructure:**
- PgHero integration for database stats (mounted at /pghero)
- Solid Queue for background jobs
- Turbo/Stimulus for modern UI interactions
- TenantAdminController base with authentication

**Shard Routing:**
```ruby
# app/models/pwb_tenant/application_record.rb
connects_to shards: {
  default: { writing: :primary, reading: :primary },
  shard_1: { writing: :tenant_shard_1, reading: :tenant_shard_1 },
  demo: { writing: :demo_shard, reading: :demo_shard }
}
```

**Configuration:**
```yaml
# config/database.yml
production:
  primary: ...
  tenant_shard_1: ...  # Optional
  demo_shard: ...       # Optional
```

**Documentation:**
- `docs/multi_tenancy/PREMIUM_ENTERPRISE_SHARDING_PLAN.md`
- `docs/multi_tenancy/DEMO_SHARD_GUIDE.md`
- `MULTI_TENANCY_DATABASE_REFERENCE.md`

### Dependencies on Existing Services ✅

**Required Services (Already Exist):**
- `Pwb::ShardRegistry` - Shard discovery (app/lib/pwb/shard_registry.rb)
- `Pwb::TenantShardMigrator` - Data migration (app/services/pwb/tenant_shard_migrator.rb)
- `TenantAdminController` - Auth base class (app/controllers/tenant_admin_controller.rb)
- `PgHero` - Database performance metrics (already configured)

**New Services to Create:**
- `Pwb::ShardService` - Assignment orchestration (new)
- `Pwb::ShardHealthCheck` - Health monitoring with PgHero (new)
- `Pwb::ShardAuditLog` - Audit model (new)
- `Pwb::ShardMigrationJob` - Async migration job for Phase 3 (new)

### What's Missing ❌

**Admin Interface:**
- No shard dashboard/overview
- No shard assignment UI
- No shard migration tools
- No shard health monitoring
- No capacity/statistics display

**Routes:**
- No `/tenant_admin/shards` routes
- No shard-related actions on websites

**Controllers:**
- No `TenantAdmin::ShardsController`
- No shard methods in `WebsitesController`

**Views:**
- No shard views in `app/views/tenant_admin/`
- No shard info displayed on website pages

---

## Goals & Requirements

### Functional Requirements

**Must Have (Phase 1):**
1. **Shard Dashboard**
   - View all configured shards
   - See website count per shard
   - View shard capacity/usage
   - See database connection status

2. **Website Shard Assignment**
   - View current shard for each website
   - Change website shard via UI
   - Bulk shard assignment
   - Validation before assignment

3. **Shard Health Monitoring**
   - Database connectivity check
   - Query performance metrics
   - Storage usage per shard

4. **Audit Trail**
   - Log all shard assignments
   - Track who changed what
   - Historical shard assignments

**Should Have (Phase 2):**
5. **Shard Migration Tools**
   - Automated data migration between shards
   - Progress tracking
   - Rollback capability
   - Downtime estimation

6. **Capacity Planning**
   - Shard capacity warnings
   - Rebalancing recommendations
   - Growth projections

**Nice to Have (Phase 3):**
7. **Auto-Balancing**
   - Automatic shard assignment for new websites
   - Load-based distribution
   - Geographic routing

### Non-Functional Requirements

**Performance:**
- Shard dashboard loads in <2 seconds
- Website queries across all shards optimized
- No performance impact on tenant requests

**Security:**
- Only TENANT_ADMIN_EMAILS can access
- All shard operations logged
- Prevent accidental data loss

**Reliability:**
- Atomic shard assignments
- Graceful handling of shard connection failures
- No downtime during shard operations

**Usability:**
- Clear warnings before destructive operations
- Intuitive UI matching existing tenant_admin style
- Helpful error messages

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Tenant Admin Interface                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │ Shard Dashboard │  │ Website Shard UI │  │ Shard Logs │ │
│  └────────┬────────┘  └────────┬─────────┘  └─────┬──────┘ │
│           │                    │                   │         │
│           └────────────────────┴───────────────────┘         │
│                              │                               │
│                    ┌─────────▼─────────┐                    │
│                    │ Shards Controller │                    │
│                    └─────────┬─────────┘                    │
│                              │                               │
└──────────────────────────────┼───────────────────────────────┘
                               │
              ┌────────────────┴────────────────┐
              │                                 │
     ┌────────▼──────────┐         ┌───────────▼──────────┐
     │   Shard Service   │         │  Shard Registry      │
     │                   │         │  (lib/pwb/...)       │
     │ - Assign shard    │         │                      │
     │ - Migrate data    │         │ - List shards        │
     │ - Validate        │         │ - Check health       │
     │ - Health checks   │         │ - Get statistics     │
     └────────┬──────────┘         └───────────┬──────────┘
              │                                 │
              └─────────────┬───────────────────┘
                            │
                  ┌─────────▼──────────┐
                  │   Pwb::Website     │
                  │   shard_name       │
                  │   database_shard   │
                  └────────────────────┘
```

### Service Layer

**New Services:**

1. **`Pwb::ShardService`** - Main shard operations
2. **`Pwb::ShardMigrator`** - Data migration between shards (already exists)
3. **`Pwb::ShardRegistry`** - Shard discovery & status (already exists)
4. **`Pwb::ShardHealthCheck`** - Health monitoring (new)

---

## Implementation Phases

### Phase 1: Foundation (Week 1)

**Goal:** Basic shard viewing and assignment

**Deliverables:**
- ✅ Shard dashboard showing all shards
- ✅ View shard info on website show page
- ✅ Assign website to shard (UI)
- ✅ Basic validation
- ✅ Audit logging

**Tasks:**
1. Create routes
2. Create ShardsController
3. Create shard views (index, show)
4. Add shard column to websites table view
5. Add shard assignment form to website edit
6. Add audit logging
7. Write tests

### Phase 2: Advanced Features (Week 2)

**Goal:** Health monitoring and bulk operations

**Deliverables:**
- ✅ Shard health dashboard
- ✅ Bulk shard assignment
- ✅ Shard statistics (size, count, etc.)
- ✅ Connection testing
- ✅ Warning system for capacity

**Tasks:**
1. Create ShardHealthCheck service
2. Add health check UI
3. Add bulk assignment form
4. Add statistics views
5. Add warnings/alerts
6. Write tests

### Phase 3: Migration Tools (Week 3)

**Goal:** Safe data migration between shards

**Deliverables:**
- ✅ Migration UI workflow
- ✅ Progress tracking
- ✅ Validation & verification
- ✅ Rollback capability
- ✅ Comprehensive documentation

**Tasks:**
1. Enhance ShardMigrator service
2. Create migration wizard UI
3. Add progress tracking
4. Add verification steps
5. Add rollback support
6. Write integration tests
7. Document migration process

---

## Database Schema

### Existing Schema

```ruby
# pwb_websites table (already exists)
create_table "pwb_websites" do |t|
  t.string   "shard_name", default: "default"
  # ... other columns
  t.index ["demo_mode", "shard_name"], name: "index_pwb_websites_on_demo_mode_and_shard_name"
end
```

### New Schema (Phase 1)

**Add Audit Log Table:**

```ruby
# Migration: db/migrate/YYYYMMDDHHMMSS_create_shard_audit_logs.rb
class CreateShardAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_shard_audit_logs do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :old_shard_name
      t.string :new_shard_name, null: false
      t.string :changed_by_email, null: false
      t.text :notes
      t.string :status, default: 'completed' # completed, failed, rolled_back
      t.timestamps
    end

    add_index :pwb_shard_audit_logs, :website_id
    add_index :pwb_shard_audit_logs, :changed_by_email
    add_index :pwb_shard_audit_logs, :created_at
  end
end
```

**Model:**

```ruby
# app/models/pwb/shard_audit_log.rb
module Pwb
  class ShardAuditLog < ApplicationRecord
    self.table_name = 'pwb_shard_audit_logs'
    
    belongs_to :website
    
    validates :new_shard_name, presence: true
    validates :changed_by_email, presence: true
    validates :status, inclusion: { in: %w[completed failed rolled_back pending] }
    
    scope :recent, -> { order(created_at: :desc) }
    scope :for_website, ->(website_id) { where(website_id: website_id) }
    scope :by_user, ->(email) { where(changed_by_email: email) }
  end
end
```

---

## Routes & Controllers

### Routes (Phase 1)

```ruby
# config/routes.rb

namespace :tenant_admin do
  # ... existing routes ...
  
  # Shard management
  resources :shards, only: [:index, :show] do
    member do
      get :health      # Health check for this shard
      get :websites    # List websites on this shard
      get :statistics  # Detailed stats
    end
    
    collection do
      get :health_summary  # All shards health
    end
  end
  
  # Website shard assignment
  resources :websites do
    member do
      get :shard_info     # Show current shard info
      patch :assign_shard # Assign to different shard
    end
    
    collection do
      get :shard_distribution  # Overview of shard distribution
      post :bulk_assign_shard  # Bulk assign multiple websites
    end
  end
  
  # Shard audit logs
  resources :shard_audit_logs, only: [:index, :show] do
    collection do
      get 'website/:website_id', action: :website_logs, as: :website
    end
  end
end
```

### Controller Structure

**1. ShardsController**

```ruby
# app/controllers/tenant_admin/shards_controller.rb
module TenantAdmin
  class ShardsController < TenantAdminController
    def index
      # Show all configured shards with stats
    end
    
    def show
      # Detailed view of single shard
    end
    
    def health
      # Health check for specific shard
    end
    
    def websites
      # List all websites on this shard
    end
    
    def statistics
      # Detailed statistics for shard
    end
    
    def health_summary
      # Quick health overview of all shards
    end
  end
end
```

**2. WebsitesController Updates**

```ruby
# app/controllers/tenant_admin/websites_controller.rb (additions)

def shard_info
  # Show current shard info for website
end

def assign_shard
  # Assign website to different shard
  result = Pwb::ShardService.assign_shard(
    website: @website,
    new_shard: params[:shard_name],
    changed_by: current_user.email,
    notes: params[:notes]
  )
  
  if result.success?
    flash[:notice] = "Website assigned to #{params[:shard_name]}"
  else
    flash[:alert] = result.error
  end
  
  redirect_to tenant_admin_website_path(@website)
end

def shard_distribution
  # Overview page showing distribution
end

def bulk_assign_shard
  # Bulk assign multiple websites to shard
end
```

**3. ShardAuditLogsController**

```ruby
# app/controllers/tenant_admin/shard_audit_logs_controller.rb
module TenantAdmin
  class ShardAuditLogsController < TenantAdminController
    def index
      @logs = Pwb::ShardAuditLog.recent.page(params[:page])
    end
    
    def show
      @log = Pwb::ShardAuditLog.find(params[:id])
    end
    
    def website_logs
      @website = Pwb::Website.find(params[:website_id])
      @logs = Pwb::ShardAuditLog.for_website(@website.id).recent.page(params[:page])
    end
  end
end
```

---

## Views & UI

### 1. Shard Dashboard (`app/views/tenant_admin/shards/index.html.erb`)

**Layout:**
```
┌────────────────────────────────────────────────────────┐
│ Shards Dashboard                              [Health] │
├────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Primary   │  │  Shard 1    │  │ Demo Shard  │   │
│  │   ✓ Healthy │  │  ✓ Healthy  │  │  ✓ Healthy  │   │
│  │             │  │             │  │             │   │
│  │ 245 sites   │  │  12 sites   │  │  8 sites    │   │
│  │ 12.4 GB     │  │  2.1 GB     │  │  0.8 GB     │   │
│  │ 45% full    │  │  12% full   │  │  5% full    │   │
│  │             │  │             │  │             │   │
│  │ [Details]   │  │ [Details]   │  │ [Details]   │   │
│  └─────────────┘  └─────────────┘  └─────────────┘   │
│                                                         │
│  Distribution Chart:                                    │
│  ████████████████████████░░ Primary (92%)             │
│  ███░░░░░░░░░░░░░░░░░░░░░░ Shard 1 (5%)              │
│  ██░░░░░░░░░░░░░░░░░░░░░░░ Demo (3%)                 │
│                                                         │
└────────────────────────────────────────────────────────┘
```

**Implementation:**

```erb
<%# app/views/tenant_admin/shards/index.html.erb %>
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Shards Dashboard</h1>
    <%= link_to "Health Summary", 
        health_summary_tenant_admin_shards_path, 
        class: "btn btn-primary" %>
  </div>

  <%# Shard Cards Grid %>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
    <% @shards.each do |shard| %>
      <div class="card bg-white shadow-lg">
        <div class="card-body">
          <div class="flex justify-between items-start">
            <h2 class="card-title"><%= shard.display_name %></h2>
            <%= render 'health_badge', shard: shard %>
          </div>
          
          <div class="mt-4 space-y-2">
            <div class="stat">
              <div class="stat-title">Websites</div>
              <div class="stat-value text-2xl">
                <%= number_with_delimiter(shard.website_count) %>
              </div>
            </div>
            
            <div class="stat">
              <div class="stat-title">Database Size</div>
              <div class="stat-value text-xl">
                <%= number_to_human_size(shard.database_size) %>
              </div>
            </div>
            
            <div class="stat">
              <div class="stat-title">Capacity</div>
              <div class="progress progress-primary">
                <div class="progress-bar" style="width: <%= shard.capacity_percent %>%">
                  <%= shard.capacity_percent %>%
                </div>
              </div>
            </div>
          </div>
          
          <div class="card-actions justify-end mt-4">
            <%= link_to "View Details", 
                tenant_admin_shard_path(shard.name), 
                class: "btn btn-sm btn-primary" %>
            <%= link_to "Websites", 
                websites_tenant_admin_shard_path(shard.name), 
                class: "btn btn-sm btn-ghost" %>
          </div>
        </div>
      </div>
    <% end %>
  </div>

  <%# Distribution Chart %>
  <div class="card bg-white shadow-lg">
    <div class="card-body">
      <h2 class="card-title">Website Distribution</h2>
      <%= render 'distribution_chart', shards: @shards %>
    </div>
  </div>

  <%# Recent Shard Changes %>
  <div class="card bg-white shadow-lg mt-6">
    <div class="card-body">
      <h2 class="card-title">Recent Shard Changes</h2>
      <%= render 'recent_changes', 
          logs: @recent_logs.limit(10) %>
    </div>
  </div>
</div>
```

### 2. Shard Show Page (`app/views/tenant_admin/shards/show.html.erb`)

```erb
<%# app/views/tenant_admin/shards/show.html.erb %>
<div class="container mx-auto px-4 py-8">
  <div class="breadcrumbs mb-4">
    <%= link_to "Shards", tenant_admin_shards_path %> /
    <%= @shard.display_name %>
  </div>

  <h1 class="text-3xl font-bold mb-6"><%= @shard.display_name %></h1>

  <%# Health Status Card %>
  <div class="card bg-white shadow-lg mb-6">
    <div class="card-body">
      <h2 class="card-title">Health Status</h2>
      
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mt-4">
        <div class="stat">
          <div class="stat-title">Connection</div>
          <div class="stat-value">
            <%= @health.connection_status ? "✓" : "✗" %>
            <%= @health.connection_status ? "Connected" : "Failed" %>
          </div>
        </div>
        
        <div class="stat">
          <div class="stat-title">Avg Query Time</div>
          <div class="stat-value"><%= @health.avg_query_ms %>ms</div>
        </div>
        
        <div class="stat">
          <div class="stat-title">Active Connections</div>
          <div class="stat-value"><%= @health.active_connections %></div>
        </div>
        
        <div class="stat">
          <div class="stat-title">Last Checked</div>
          <div class="stat-value text-sm">
            <%= time_ago_in_words(@health.checked_at) %> ago
          </div>
        </div>
      </div>

      <%= link_to "Refresh Health", 
          health_tenant_admin_shard_path(@shard.name), 
          method: :get,
          class: "btn btn-sm btn-primary mt-4" %>
    </div>
  </div>

  <%# Statistics Card %>
  <div class="card bg-white shadow-lg mb-6">
    <div class="card-body">
      <h2 class="card-title">Statistics</h2>
      
      <div class="overflow-x-auto mt-4">
        <table class="table table-zebra">
          <tbody>
            <tr>
              <td class="font-bold">Total Websites</td>
              <td><%= number_with_delimiter(@stats.website_count) %></td>
            </tr>
            <tr>
              <td class="font-bold">Total Properties</td>
              <td><%= number_with_delimiter(@stats.property_count) %></td>
            </tr>
            <tr>
              <td class="font-bold">Total Pages</td>
              <td><%= number_with_delimiter(@stats.page_count) %></td>
            </tr>
            <tr>
              <td class="font-bold">Database Size</td>
              <td><%= number_to_human_size(@stats.database_size) %></td>
            </tr>
            <tr>
              <td class="font-bold">Table Count</td>
              <td><%= @stats.table_count %></td>
            </tr>
            <tr>
              <td class="font-bold">Index Size</td>
              <td><%= number_to_human_size(@stats.index_size) %></td>
            </tr>
          </tbody>
        </table>
      </div>

      <%= link_to "View Websites →", 
          websites_tenant_admin_shard_path(@shard.name),
          class: "btn btn-primary mt-4" %>
    </div>
  </div>

  <%# Configuration Card %>
  <div class="card bg-white shadow-lg">
    <div class="card-body">
      <h2 class="card-title">Database Configuration</h2>
      
      <div class="mockup-code mt-4">
        <pre><code><%= JSON.pretty_generate(@shard.database_config) %></code></pre>
      </div>
    </div>
  </div>
</div>
```

### 3. Website Shard Assignment (`app/views/tenant_admin/websites/_shard_form.html.erb`)

```erb
<%# app/views/tenant_admin/websites/_shard_form.html.erb %>
<div class="card bg-white shadow-lg">
  <div class="card-body">
    <h2 class="card-title">Shard Assignment</h2>
    
    <div class="alert alert-info mb-4">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <div>
        <p>Current shard: <strong><%= website.shard_name || 'default' %></strong></p>
        <p class="text-sm">
          Last changed: 
          <%= website.shard_audit_logs.last&.created_at&.to_fs(:long) || 'Never' %>
        </p>
      </div>
    </div>

    <%= form_with model: website, 
        url: assign_shard_tenant_admin_website_path(website),
        method: :patch,
        local: true,
        class: "space-y-4" do |f| %>
      
      <div class="form-control">
        <%= f.label :shard_name, "Target Shard", class: "label" %>
        <%= f.select :shard_name, 
            options_for_select(@available_shards, website.shard_name),
            { include_blank: false },
            class: "select select-bordered w-full" %>
        <label class="label">
          <span class="label-text-alt">
            Choose the database shard for this website
          </span>
        </label>
      </div>

      <div class="form-control">
        <%= f.label :notes, "Reason for Change", class: "label" %>
        <%= f.text_area :notes, 
            rows: 3,
            placeholder: "Optional: Explain why you're changing shards",
            class: "textarea textarea-bordered w-full" %>
      </div>

      <div class="alert alert-warning">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <div>
          <p class="font-bold">Warning</p>
          <p class="text-sm">
            This only updates the shard routing. Data is NOT automatically migrated.
            Use the Migration Wizard to move data between shards.
          </p>
        </div>
      </div>

      <div class="card-actions justify-end">
        <%= f.submit "Assign to Shard", 
            class: "btn btn-primary",
            data: { confirm: "Are you sure? This will change where queries are routed." } %>
      </div>
    <% end %>
    
    <%# Migration Wizard Link %>
    <div class="divider">OR</div>
    
    <%= link_to "Use Migration Wizard →", 
        "#",  # TODO: Link to migration wizard when Phase 3 is implemented
        class: "btn btn-outline btn-block",
        disabled: true %>
    <p class="text-sm text-gray-500 text-center mt-2">
      Coming in Phase 3: Automated data migration
    </p>
  </div>
</div>

<%# Shard History %>
<div class="card bg-white shadow-lg mt-6">
  <div class="card-body">
    <h2 class="card-title">Shard Assignment History</h2>
    
    <% if website.shard_audit_logs.any? %>
      <div class="overflow-x-auto mt-4">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Date</th>
              <th>From</th>
              <th>To</th>
              <th>Changed By</th>
              <th>Notes</th>
            </tr>
          </thead>
          <tbody>
            <% website.shard_audit_logs.recent.limit(10).each do |log| %>
              <tr>
                <td><%= log.created_at.to_fs(:short) %></td>
                <td><%= log.old_shard_name || 'N/A' %></td>
                <td><%= log.new_shard_name %></td>
                <td><%= log.changed_by_email %></td>
                <td><%= log.notes %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <p class="text-gray-500 italic">No shard changes recorded</p>
    <% end %>
  </div>
</div>
```

### 4. Website Index - Add Shard Column

```erb
<%# app/views/tenant_admin/websites/index.html.erb (addition) %>

<%# In the table %>
<thead>
  <tr>
    <th>Subdomain</th>
    <th>Company</th>
    <th>Shard</th>  <%# NEW COLUMN %>
    <th>Status</th>
    <th>Created</th>
    <th>Actions</th>
  </tr>
</thead>
<tbody>
  <% @websites.each do |website| %>
    <tr>
      <td><%= website.subdomain %></td>
      <td><%= website.company_display_name %></td>
      <td>
        <%# NEW: Shard badge %>
        <%= render 'shard_badge', website: website %>
      </td>
      <td>...</td>
      <td>...</td>
      <td>...</td>
    </tr>
  <% end %>
</tbody>
```

**Shard Badge Partial:**

```erb
<%# app/views/tenant_admin/websites/_shard_badge.html.erb %>
<% shard_name = website.shard_name || 'default' %>
<% badge_class = case shard_name
   when 'default', 'primary' then 'badge-primary'
   when 'demo', 'demo_shard' then 'badge-secondary'
   else 'badge-accent'
   end %>

<span class="badge <%= badge_class %> badge-sm">
  <%= shard_name %>
</span>
```

### 5. Bulk Assignment UI

```erb
<%# app/views/tenant_admin/websites/shard_distribution.html.erb %>
<div class="container mx-auto px-4 py-8">
  <h1 class="text-3xl font-bold mb-6">Bulk Shard Assignment</h1>

  <%= form_with url: bulk_assign_shard_tenant_admin_websites_path,
      method: :post,
      local: true do |f| %>
    
    <div class="card bg-white shadow-lg mb-6">
      <div class="card-body">
        <h2 class="card-title">Select Websites</h2>
        
        <div class="form-control">
          <%= f.label :filter_type, "Filter By", class: "label" %>
          <%= f.select :filter_type,
              [
                ['All Websites', 'all'],
                ['Current Shard', 'shard'],
                ['Demo Websites', 'demo'],
                ['Subdomain Pattern', 'pattern']
              ],
              {},
              class: "select select-bordered",
              data: { action: "change->bulk-assign#updateFilter" } %>
        </div>

        <div class="form-control mt-4" data-bulk-assign-target="shardFilter">
          <%= f.label :current_shard, "Current Shard", class: "label" %>
          <%= f.select :current_shard,
              @available_shards,
              { include_blank: true },
              class: "select select-bordered" %>
        </div>

        <div class="alert alert-info mt-4">
          <p><strong>Websites to update:</strong> <span id="website-count">0</span></p>
        </div>
      </div>
    </div>

    <div class="card bg-white shadow-lg">
      <div class="card-body">
        <h2 class="card-title">Target Shard</h2>
        
        <div class="form-control">
          <%= f.label :target_shard, "Assign To", class: "label" %>
          <%= f.select :target_shard,
              @available_shards,
              {},
              class: "select select-bordered" %>
        </div>

        <div class="form-control mt-4">
          <%= f.label :notes, "Reason", class: "label" %>
          <%= f.text_area :notes,
              rows: 3,
              class: "textarea textarea-bordered" %>
        </div>

        <div class="alert alert-warning mt-4">
          <p>This is a routing-only operation. Data must be migrated separately.</p>
        </div>

        <div class="card-actions justify-end mt-4">
          <%= f.submit "Assign Websites to Shard",
              class: "btn btn-primary",
              data: { confirm: "Are you sure you want to bulk assign these websites?" } %>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

---

## Service Layer Implementation

### 1. Pwb::ShardService

```ruby
# app/services/pwb/shard_service.rb
module Pwb
  class ShardService
    class Result
      attr_reader :success, :error, :data
      
      def initialize(success:, error: nil, data: nil)
        @success = success
        @error = error
        @data = data
      end
      
      def success?
        @success
      end
    end
    
    # Assign website to a shard
    # @param website [Pwb::Website] The website to assign
    # @param new_shard [String] Target shard name
    # @param changed_by [String] Email of user making change
    # @param notes [String] Optional notes
    # @return [Result]
    def self.assign_shard(website:, new_shard:, changed_by:, notes: nil)
      old_shard = website.shard_name
      
      # Validation
      unless valid_shard?(new_shard)
        return Result.new(
          success: false,
          error: "Invalid shard: #{new_shard}. Must be one of: #{available_shards.join(', ')}"
        )
      end
      
      # Skip if already on target shard
      if old_shard == new_shard
        return Result.new(
          success: false,
          error: "Website is already on shard '#{new_shard}'"
        )
      end
      
      # Update with audit log
      ActiveRecord::Base.transaction do
        website.update!(shard_name: new_shard)
        
        Pwb::ShardAuditLog.create!(
          website: website,
          old_shard_name: old_shard,
          new_shard_name: new_shard,
          changed_by_email: changed_by,
          notes: notes,
          status: 'completed'
        )
      end
      
      Result.new(
        success: true,
        data: { old_shard: old_shard, new_shard: new_shard }
      )
    rescue StandardError => e
      Result.new(success: false, error: e.message)
    end
    
    # Get list of available shards from database.yml
    # @return [Array<String>]
    def self.available_shards
      Pwb::ShardRegistry.available_shards.keys.map(&:to_s)
    end
    
    # Validate shard name exists
    # @param shard_name [String]
    # @return [Boolean]
    def self.valid_shard?(shard_name)
      available_shards.include?(shard_name.to_s)
    end
    
    # Get statistics for a shard
    # @param shard_name [String]
    # @return [Hash]
    def self.shard_statistics(shard_name)
      shard_sym = shard_name.to_sym
      
      ActiveRecord::Base.connected_to(shard: shard_sym) do
        {
          website_count: Pwb::Website.unscoped.where(shard_name: shard_name).count,
          property_count: PwbTenant::RealtyAsset.unscoped.count,
          page_count: PwbTenant::Page.unscoped.count,
          database_size: database_size,
          table_count: table_count,
          index_size: index_size
        }
      end
    end
    
    private
    
    # Get database size in bytes
    def self.database_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database())"
      )
      result.first['pg_database_size'].to_i
    end
    
    # Get number of tables
    def self.table_count
      ActiveRecord::Base.connection.tables.count
    end
    
    # Get total index size
    def self.index_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT SUM(pg_relation_size(indexrelid)) FROM pg_index"
      )
      result.first['sum'].to_i
    end
  end
end
```

### 2. Pwb::ShardHealthCheck

```ruby
# app/services/pwb/shard_health_check.rb
module Pwb
  class ShardHealthCheck
    HealthStatus = Struct.new(
      :shard_name,
      :connection_status,
      :avg_query_ms,
      :active_connections,
      :database_size,
      :checked_at,
      :error_message,
      keyword_init: true
    )
    
    # Check health of specific shard
    # @param shard_name [String]
    # @return [HealthStatus]
    def self.check(shard_name)
      shard_sym = shard_name.to_sym
      checked_at = Time.current
      
      begin
        ActiveRecord::Base.connected_to(shard: shard_sym) do
          # Test connection
          connection_ok = test_connection
          
          # Measure query performance
          query_time = measure_query_time
          
          # Get connection pool stats
          pool = ActiveRecord::Base.connection_pool
          
          HealthStatus.new(
            shard_name: shard_name,
            connection_status: connection_ok,
            avg_query_ms: query_time,
            active_connections: pool.connections.count,
            database_size: get_database_size,
            checked_at: checked_at,
            error_message: nil
          )
        end
      rescue StandardError => e
        HealthStatus.new(
          shard_name: shard_name,
          connection_status: false,
          avg_query_ms: nil,
          active_connections: 0,
          database_size: 0,
          checked_at: checked_at,
          error_message: e.message
        )
      end
    end
    
    # Check all shards
    # @return [Hash<String, HealthStatus>]
    def self.check_all
      Pwb::ShardRegistry.available_shards.keys.each_with_object({}) do |shard_name, health|
        health[shard_name.to_s] = check(shard_name.to_s)
      end
    end
    
    private
    
    def self.test_connection
      ActiveRecord::Base.connection.execute("SELECT 1").any?
    end
    
    def self.measure_query_time
      start = Time.current
      ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM pwb_websites")
      ((Time.current - start) * 1000).round(2)
    end
    
    def self.get_database_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database())"
      )
      result.first['pg_database_size'].to_i
    rescue
      0
    end
  end
end
```

---

## Security & Authorization

### TenantAdminController Base

```ruby
# app/controllers/tenant_admin_controller.rb
class TenantAdminController < ApplicationController
  before_action :authenticate_user!
  before_action :require_tenant_admin!
  
  layout 'tenant_admin'
  
  private
  
  def require_tenant_admin!
    admin_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip)
    
    unless current_user && admin_emails.include?(current_user.email)
      flash[:alert] = "You don't have permission to access this area."
      redirect_to root_path
    end
  end
end
```

### Audit Logging

All shard operations are logged to `pwb_shard_audit_logs`:

- Who made the change (email)
- What changed (old shard → new shard)
- When (timestamp)
- Why (optional notes)
- Status (completed, failed, rolled_back)

### Permissions

**Phase 1:**
- Only users in `TENANT_ADMIN_EMAILS` can access shard admin
- All actions logged to audit trail

**Phase 2 (Future):**
- Role-based permissions (super_admin, shard_admin)
- Granular permissions (view only vs. modify)
- Two-factor authentication for shard migrations

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/pwb/shard_service_spec.rb
RSpec.describe Pwb::ShardService do
  describe '.assign_shard' do
    let(:website) { create(:website, shard_name: 'default') }
    
    it 'assigns website to new shard' do
      result = described_class.assign_shard(
        website: website,
        new_shard: 'shard_1',
        changed_by: 'admin@example.com'
      )
      
      expect(result.success?).to be true
      expect(website.reload.shard_name).to eq 'shard_1'
    end
    
    it 'creates audit log entry' do
      expect {
        described_class.assign_shard(
          website: website,
          new_shard: 'shard_1',
          changed_by: 'admin@example.com',
          notes: 'Moving to dedicated shard'
        )
      }.to change(Pwb::ShardAuditLog, :count).by(1)
      
      log = Pwb::ShardAuditLog.last
      expect(log.old_shard_name).to eq 'default'
      expect(log.new_shard_name).to eq 'shard_1'
      expect(log.changed_by_email).to eq 'admin@example.com'
      expect(log.notes).to eq 'Moving to dedicated shard'
    end
    
    it 'rejects invalid shard names' do
      result = described_class.assign_shard(
        website: website,
        new_shard: 'nonexistent_shard',
        changed_by: 'admin@example.com'
      )
      
      expect(result.success?).to be false
      expect(result.error).to include('Invalid shard')
    end
    
    it 'prevents assigning to same shard' do
      result = described_class.assign_shard(
        website: website,
        new_shard: 'default',
        changed_by: 'admin@example.com'
      )
      
      expect(result.success?).to be false
      expect(result.error).to include('already on shard')
    end
  end
end
```

```ruby
# spec/services/pwb/shard_health_check_spec.rb
RSpec.describe Pwb::ShardHealthCheck do
  describe '.check' do
    it 'returns health status for valid shard' do
      status = described_class.check('default')
      
      expect(status.shard_name).to eq 'default'
      expect(status.connection_status).to be true
      expect(status.avg_query_ms).to be_a(Float)
      expect(status.checked_at).to be_present
    end
    
    it 'handles connection failures gracefully' do
      allow(ActiveRecord::Base).to receive(:connected_to).and_raise(
        PG::ConnectionBad.new("connection failed")
      )
      
      status = described_class.check('default')
      
      expect(status.connection_status).to be false
      expect(status.error_message).to include('connection failed')
    end
  end
end
```

### Controller Tests

```ruby
# spec/controllers/tenant_admin/shards_controller_spec.rb
RSpec.describe TenantAdmin::ShardsController, type: :controller do
  let(:admin_user) { create(:user, email: 'admin@example.com') }
  
  before do
    allow(ENV).to receive(:fetch).with('TENANT_ADMIN_EMAILS', '').and_return('admin@example.com')
    sign_in admin_user
  end
  
  describe 'GET #index' do
    it 'lists all shards' do
      get :index
      expect(response).to be_successful
      expect(assigns(:shards)).to be_present
    end
  end
  
  describe 'GET #show' do
    it 'shows shard details' do
      get :show, params: { id: 'default' }
      expect(response).to be_successful
      expect(assigns(:shard)).to be_present
    end
  end
  
  describe 'GET #health' do
    it 'returns health check results' do
      get :health, params: { id: 'default' }
      expect(response).to be_successful
      expect(assigns(:health).connection_status).to be true
    end
  end
end
```

### Integration Tests (Playwright)

```javascript
// tests/e2e/shard_admin.spec.js
import { test, expect } from '@playwright/test';

test.describe('Shard Admin', () => {
  test.beforeEach(async ({ page }) => {
    // Login as tenant admin
    await page.goto('/tenant_admin/shards');
  });

  test('displays shard dashboard', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Shards Dashboard');
    
    // Check for shard cards
    const shardCards = page.locator('.shard-card');
    await expect(shardCards).toHaveCount(3); // default, shard_1, demo
  });

  test('assigns website to different shard', async ({ page }) => {
    // Navigate to website
    await page.goto('/tenant_admin/websites/1');
    
    // Click shard assignment
    await page.click('text=Assign Shard');
    
    // Select new shard
    await page.selectOption('select[name="shard_name"]', 'shard_1');
    await page.fill('textarea[name="notes"]', 'Test assignment');
    
    // Confirm
    page.on('dialog', dialog => dialog.accept());
    await page.click('button:has-text("Assign to Shard")');
    
    // Verify success
    await expect(page.locator('.flash-notice')).toContainText('assigned to shard_1');
  });

  test('shows shard health status', async ({ page }) => {
    await page.goto('/tenant_admin/shards/default/health');
    
    await expect(page.locator('.health-status')).toContainText('Connected');
    await expect(page.locator('.avg-query-time')).toBeVisible();
  });
});
```

---

## Deployment & Rollout

### Phase 1 Deployment (Week 1)

**Prerequisites:**
1. All shards configured in `database.yml`
2. Database migration run: `rails db:migrate`
3. `TENANT_ADMIN_EMAILS` environment variable set

**Steps:**

1. **Deploy Code:**
   ```bash
   git push production main
   ```

2. **Run Migration:**
   ```bash
   # On production server
   rails db:migrate
   ```

3. **Verify:**
   ```bash
   # Test shard connections
   rails runner "Pwb::ShardHealthCheck.check_all"
   ```

4. **Enable Access:**
   ```bash
   # Set admin emails
   dokku config:set pwb-2025 TENANT_ADMIN_EMAILS="admin@example.com,superadmin@example.com"
   ```

5. **Test in Browser:**
   - Navigate to `/tenant_admin/shards`
   - Verify dashboard loads
   - Check health of all shards

### Phase 2 Deployment (Week 2)

**Additional Steps:**
1. Deploy health monitoring enhancements
2. Test bulk assignment with small batch
3. Set up monitoring alerts for shard health

### Phase 3 Deployment (Week 3)

**Migration Wizard:**
1. Deploy migration tools
2. Test migration in staging first
3. Document migration procedures
4. Train admins on migration process

### Rollback Plan

**If Issues Arise:**

1. **Quick Rollback:**
   ```bash
   git revert HEAD
   git push production main
   ```

2. **Database Rollback:**
   ```bash
   rails db:rollback
   ```

3. **Manual Shard Reset:**
   ```ruby
   # If websites got assigned to wrong shards
   Pwb::Website.where(shard_name: 'problematic_shard')
     .update_all(shard_name: 'default')
   ```

---

## Monitoring & Alerts

### Metrics to Track

1. **Shard Health:**
   - Connection failures
   - Average query time
   - Active connections

2. **Website Distribution:**
   - Websites per shard
   - Imbalance warnings

3. **Shard Operations:**
   - Assignment frequency
   - Failed assignments
   - Migration progress

### Recommended Alerts

**Setup with Rails Performance or similar:**

```ruby
# config/initializers/shard_monitoring.rb
if Rails.env.production?
  # Alert if shard connection fails
  ActiveSupport::Notifications.subscribe('shard.connection.failed') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    # Send alert to Slack/email
    ShardAlertService.notify_connection_failure(event.payload)
  end
  
  # Alert if shard becomes imbalanced
  ActiveSupport::Notifications.subscribe('shard.imbalance.detected') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    ShardAlertService.notify_imbalance(event.payload)
  end
end
```

---

## Documentation Deliverables

### 1. User Guide

**File:** `docs/multi_tenancy/SHARD_ADMIN_USER_GUIDE.md`

Contents:
- How to access shard admin
- How to view shard health
- How to assign websites to shards
- How to interpret shard statistics
- Troubleshooting common issues

### 2. Technical Reference

**File:** `docs/multi_tenancy/SHARD_ADMIN_TECHNICAL_REFERENCE.md`

Contents:
- API documentation
- Service layer architecture
- Database schema
- Configuration options
- Security model

### 3. Migration Procedures

**File:** `docs/multi_tenancy/SHARD_MIGRATION_PROCEDURES.md`

Contents:
- When to migrate shards
- Step-by-step migration process
- Pre-migration checklist
- Post-migration verification
- Rollback procedures

### 4. Code Comments

All services, controllers, and models should have:
- Class-level documentation
- Method documentation with @param and @return
- Usage examples
- Security notes

---

## Future Enhancements (Phase 4+)

### Automated Rebalancing

Automatically distribute websites based on:
- Geographic location (latency optimization)
- Website size/activity
- Shard capacity
- Time of day (load balancing)

### Advanced Monitoring

- Real-time shard performance dashboard
- Query analysis and slow query detection
- Capacity forecasting
- Cost optimization recommendations

### Multi-Region Support

- Geographic shard distribution
- Cross-region replication
- Failover automation
- Disaster recovery

### API Access

REST API for:
- External monitoring tools
- Automated deployment scripts
- Third-party integrations

### Enhanced Migrations

- Zero-downtime migrations
- Incremental data syncing
- Automatic verification
- One-click rollback

---

## Success Criteria

### Phase 1 Complete When:
- ✅ Shard dashboard accessible
- ✅ Can view health of all shards
- ✅ Can assign websites to shards via UI
- ✅ Audit logs created for all changes
- ✅ All tests passing
- ✅ Documentation complete

### Phase 2 Complete When:
- ✅ Health monitoring working
- ✅ Bulk assignment functional
- ✅ Statistics accurate
- ✅ Warnings/alerts implemented

### Phase 3 Complete When:
- ✅ Migration wizard functional
- ✅ Data successfully migrated in staging
- ✅ Verification processes working
- ✅ Rollback tested
- ✅ Procedures documented

---

## Appendix

### A. Database Schema Diagrams

```
pwb_websites                 pwb_shard_audit_logs
┌──────────────┐            ┌────────────────────┐
│ id           │────────────│ website_id         │
│ subdomain    │            │ old_shard_name     │
│ shard_name   │            │ new_shard_name     │
│ ...          │            │ changed_by_email   │
└──────────────┘            │ notes              │
                            │ status             │
                            │ created_at         │
                            └────────────────────┘
```

### B. Shard Configuration Reference

```yaml
# config/database.yml
production:
  primary:
    adapter: postgresql
    database: pwb_production
    url: <%= ENV['DATABASE_URL'] %>
    
  tenant_shard_1:
    adapter: postgresql
    database: pwb_production_shard_1
    url: <%= ENV['PWB_TENANT_SHARD_1_DATABASE_URL'] %>
    migrations_paths: db/tenant_shard_1_migrate
    
  demo_shard:
    adapter: postgresql
    database: pwb_production_demo_shard
    url: <%= ENV['PWB_DEMO_SHARD_DATABASE_URL'] %>
    migrations_paths: db/demo_shard_migrate
```

### C. Environment Variables

```bash
# Required for Shard Admin
TENANT_ADMIN_EMAILS=admin@example.com,superadmin@example.com

# Optional Shard Databases
PWB_TENANT_SHARD_1_DATABASE_URL=postgresql://...
PWB_DEMO_SHARD_DATABASE_URL=postgresql://...

# Monitoring (optional)
SHARD_HEALTH_CHECK_INTERVAL=300  # seconds
SHARD_IMBALANCE_THRESHOLD=0.2    # 20% difference
```

### D. Troubleshooting Guide

**Problem:** Shard dashboard shows "Connection Failed"

**Solutions:**
1. Check database.yml configuration
2. Verify DATABASE_URL environment variable
3. Test connection: `rails dbconsole -s shard_name`
4. Check firewall/network access

**Problem:** Website assigned to shard but queries fail

**Solutions:**
1. Verify data exists on target shard
2. Check `shard_name` column value
3. Run migration if needed
4. Check PwbTenant::ApplicationRecord.connects_to configuration

**Problem:** Audit log not creating

**Solutions:**
1. Check database migration ran
2. Verify Pwb::ShardAuditLog model exists
3. Check transaction rollback in logs
4. Verify foreign key constraints

---

## Timeline Summary

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| Phase 1 | Week 1 | Shard dashboard, assignment UI, audit logs |
| Phase 2 | Week 2 | Health monitoring, bulk operations, statistics |
| Phase 3 | Week 3 | Migration wizard, verification, documentation |
| **Total** | **3 weeks** | **Complete shard admin system** |

---

## Sign-off

**Prepared by:** AI Assistant  
**Date:** 2026-01-08  
**Status:** Ready for Review  

**Reviewers:**
- [ ] Technical Lead - Architecture approval
- [ ] Product Owner - Feature approval  
- [ ] DevOps - Infrastructure approval
- [ ] Security - Security review

**Approval:**
- [ ] Approved for Phase 1 implementation
- [ ] Approved for full implementation (all phases)

