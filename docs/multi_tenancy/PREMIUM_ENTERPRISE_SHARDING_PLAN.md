# Premium Enterprise Sharding Architecture

## Overview
This document outlines the architecture for introducing a "Premium Enterprise" tier to PropertyWebBuilder. This tier offers dedicated database resources (sharding) for high-value clients, ensuring their performance is isolated from the noisy neighbors on the shared platform.

## Architecture Guidelines

### Core Concept: Horizontal Sharding by Tenant
Rails generic multi-database support allows us to define "shards" in `database.yml`.
*   **Primary Shard (`:default`)**: Hosts the `pwb_websites` table (tenant registry) and the data for all "Standard" tier tenants.
*   **Dedicated Shards (`:shard_1`, `:shard_2`, etc.)**: Hosted on separate Postgres instances or separate logical databases. Each shard hosts data for one or more "Premium" tenants.

### 1. Database Configuration (`config/database.yml`)
The generic sharding configuration in Rails allows mapping abstract shard names to concrete database connections.

```yaml
production:
  primary:
    <<: *default
    database: pwb_production_primary
  shard_1:
    <<: *default
    database: pwb_production_premium_shard_1
    migrations_paths: db/migrate_tenants
  shard_2:
    <<: *default
    database: pwb_production_premium_shard_2
    migrations_paths: db/migrate_tenants
```

*   **Migration Paths**: Note the use of `migrations_paths`. We likely need to split migrations into:
    *   `db/migrate`: Global tables (e.g., `users`). Runs on `:primary` only.
    *   `db/migrate_tenants`: Tenant-specific tables (e.g., `pwb_props`, `pwb_contacts`). Runs on ALL shards.

### 2. Tenant Model Updates (`Pwb::Website`)
The tenant registry (`Pwb::Website`) needs to know which shard a tenant belongs to.

*   **New Column**: Add `shard_name` (string) to `pwb_websites`.
*   **Default**: Defaults to `default` (or `primary`).
*   **Operation**: When a customer upgrades to Enterprise, we provision a shard (or assign them to an emptier premium shard), migrate their data, and update `shard_name`.

### 3. Model Connection Handling
We leverage `PwbTenant::ApplicationRecord` as the base class for all tenant-scoped data.

```ruby
module PwbTenant
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    acts_as_tenant :website, class_name: 'Pwb::Website'

    connects_to shards: {
      default: { writing: :primary, reading: :primary },
      shard_1: { writing: :shard_1, reading: :shard_1 },
      shard_2: { writing: :shard_2, reading: :shard_2 }
    }
  end
end
```

### 4. Connection Switching Middleware
We need to switch the active database connection *before* processing the request, based on the identified tenant.

**Location**: `app/controllers/pwb/application_controller.rb`

**Logic**:
1.  **Identify Tenant**: Resolved by subdomain (existing logic).
2.  **Lookup Shard**: Read `current_website.shard_name`.
3.  **connects_to**: Wrap the request in a `connected_to` block.

```ruby
around_action :switch_tenant_shard

def switch_tenant_shard
  shard_name = current_website&.shard_name&.to_sym || :default
  # Verify shard exists in config to avoid errors
  shard = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: shard_name) ? shard_name : :default
  
  PwbTenant::ApplicationRecord.connected_to(shard: shard, role: :writing) do
    yield
  end
end
```

### 5. Data Migration Strategy (The Hard Part)
Moving a tenant from `primary` to `shard_1` is complex.

*   **Scripted Migration**: We need a service `TenantMover.new(website_id, target_shard: :shard_1).call`.
*   **Steps**:
    1.  Dump tenant data from `primary` (filtered by `website_id`).
    2.  Restore to `shard_1`.
    3.  Verify integrity.
    4.  Update `pwb_websites.shard_name` to `:shard_1`.
    5.  Delete data from `primary`.

## Testing Strategy
Testing multi-database architecture requires specific configuration in compliance with Rails recommendations.

### Unit Testing
*   **Configuration**: `config/database.yml` for tests must define `test_shard_1`.
*   **Shard Switching**: Write specs that explicitly set the tenant with a non-default shard and assert that `PwbTenant::Prop.connection.current_database` returns the expected shard database name.
*   **Isolation**: Create a record in `primary` and assert it is NOT visible when connected to `shard_1`, and vice-versa.

### Integration/E2E Testing
*   **Middleware Test**: Use a system spec (Capybara/Playwright) to visit a subdomain configured for `shard_1`. Create data via the UI and verify (via direct DB query) that it landed in the `test_shard_1` database, not `test_primary`.

## Rake Tasks
We will create a specific namespace `pwb:sharding` for management tasks.

### `rake pwb:sharding:list`
Displays a table of all shards, their database names, and the count of tenants assigned to each.

### `rake pwb:sharding:provision[tenant_id, shard_name]`
Assigns a **new, empty** tenant to a specific shard. Useful for provisioning new Enterprise clients directly onto a shard.
*   **Usage**: `rake pwb:sharding:provision[123, shard_1]`

### `rake pwb:sharding:migrate[tenant_id, target_shard]`
**DANGER**: Moves an existing tenant's data from their current shard to the target shard.
*   **Usage**: `rake pwb:sharding:migrate[123, shard_1]`
*   **Implementation Status**: ✅ Implemented via `Pwb::TenantShardMigrator`. The task copies every `PwbTenant::` model in batches, verifies there are no ID collisions on the destination, inserts the rows, and then deletes them from the source before updating `website.shard_name`.
*   **Prerequisites**:
    * Target shard must be configured in `database.yml` and up to date schema-wise.
    * Destination shard should not contain colliding primary keys for the migrating tenant tables. (The migrator aborts if conflicts are detected.)
*   **Steps**:
    1.  Acquire a lock on the website record to prevent concurrent shard changes.
    2.  Stream tenant data from the source shard in batches.
    3.  Insert batches into the target shard (raising if any ID conflict is detected).
    4.  Delete migrated rows from the source shard.
    5.  Update `website.shard_name`.
    6.  Release the lock.

## Tenant Admin UI
We will add a "Platform Operations" section to the Super Admin interface (`/admin`).

### Dashboard Features
1.  **Shard Overview**: A card view showing the health of each configured shard (Primary, Shard 1, Shard 2).
    *   **Metrics**: Connection pool usage, tenant count, database size.
2.  **Tenant Distribution**: A list of tenants with a new column "Database Shard".
    *   **Filter**: "Show only Premium Sla tenants".

### Operations Actions
1.  **Migrate Action**: On the Tenant details page, a "Migrate Database" button.
    *   **Modal**: "Select Target Shard" dropdown.
    *   **Warning**: "This will take the site offline for approximately 5 minutes."
    *   **Progress**: Shows a progress bar hooked into the background migration job.

## Benefits
*   **Performance**: Massive valid isolated IOPS for big clients.
*   **Reliability**: One bad tenant crashing a DB doesn't take down the Enterprise clients.
*   **Billing**: Easier to justify 10x pricing when infrastructure is physically dedicated.

## Risks & Complexity
*   **Migrations**: Running migrations across 50 shards takes time.
*   **Reporting**: Aggregating stats across shards (e.g., "Total Properties across platform") requires map-reduce logic or a data warehouse setup.
*   **Connection Limits**: Each Rails process holds a pool to *every* active shard it connects to. With 100 shards, this explodes. **Mitigation**: Use a localized proxy (PgBouncer) or keep the number of shards low (e.g., 10 shards, not 1 per tenant).
