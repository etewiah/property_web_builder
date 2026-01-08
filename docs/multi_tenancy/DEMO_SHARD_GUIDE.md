# Demo Shard Operations Guide

This guide explains how to run the dedicated demo shard, provision new demo tenants, and keep those tenants up to date. Read it together with `multi_tenancy_guide.md` when you need implementation details.

## 1. Goals & Benefits

| Goal | Why it matters |
|------|----------------|
| Isolate marketing demos | Demo data never touches production tenants. |
| Provide curated experience | Each demo subdomain boots from a known seed pack. |
| Support automatic resets | Visitors always see a clean, predictable state. |
| Protect infrastructure | Destructive controller actions are blocked in demo mode. |

## 2. Architecture Overview

1. **Dedicated database connection** – `config/database.yml` defines a `demo_shard` for every environment. Its migrations live in `db/demo_shard_migrate/`.
2. **Website metadata** – `pwb_websites` now tracks `demo_mode`, `demo_seed_pack`, `demo_reset_interval`, and `demo_last_reset_at` so we can flag demo tenants and schedule resets.
3. **Shard-aware requests** – `PwbTenant::ApplicationRecord` connects to `:default`, `:shard_1`, and `:demo`. `Pwb::ApplicationController` wraps every request in `ActiveRecord::Base.connected_to(shard: current_website.database_shard)` so all Active Record classes hit the same shard.
4. **Demo helpers** – The `Pwb::DemoWebsite` concern (included in `Pwb::Website`) adds handy scopes (`.demos`, `.on_demo_shard`), the `demo?` predicate, interval parsing, and the `reset_demo_data!` workflow that clears tenant data and reapplies seed packs.
5. **Middleware & UI** – `DemoShardMiddleware` force-routes known demo subdomains to the demo shard, `_demo_banner.html.erb` surfaces a visitor-facing notice, and the `DemoRestrictions` controller concern blocks destructive actions when `current_website.demo?` evaluates true.

## 3. Preparing the Databases

Run these commands whenever you bootstrap a new environment (local, staging, production) so every shard exists and is migrated:

```bash
# Create databases
bin/rails db:create
bin/rails db:create:tenant_shard_1
bin/rails db:create:demo_shard

# Apply migrations
bin/rails db:migrate
bin/rails db:migrate:tenant_shard_1
bin/rails db:migrate:demo_shard
```

or run everything at once:

```bash
bin/rails db:shards:prepare
```

> **Tip:** `bin/rails db:prepare` will run the primary migrations automatically, but you still need the explicit `:tenant_shard_1` and `:demo_shard` tasks unless you use the helper above.

## 4. Provisioning Demo Tenants

1. **Configure reserved subdomains** in `config/initializers/demo_subdomains.rb` so each marketing URL maps to a seed pack (e.g., `demo-spain` → `spain_luxury`).
2. **Run the provisioning rake task:**
   ```bash
   bin/rails demo:provision
   ```
   This task loops over `DEMO_SUBDOMAINS`, calls `Pwb::DemoProvisioner.provision`, and ensures each website lives on the demo shard with `demo_mode` enabled.
3. **Seed packs** – Provisioner delegates to `Pwb::SeedPack` so you can reuse any existing pack. New packs can be added under `db/seeds/packs/` with no changes to the provisioning service.

## 5. Resetting Demo Data

- **Manual reset:**
  ```bash
  bin/rails demo:reset
  ```
  This iterates over `Pwb::Website.demos.on_demo_shard` and calls `reset_demo_data!`.
- **Automatic reset:** `DemoResetJob` checks each demo site, compares `demo_last_reset_at` against `demo_reset_interval`, and resets stale tenants. `config/schedule.rb` schedules the job daily at 03:00. If you deploy to a scheduler (Heroku, Render, etc.) make sure the `whenever`-generated cron or the platform-equivalent job runs `rails runner "DemoResetJob.perform_later"` every night.
- **Custom intervals:** Update `demo_reset_interval` per website (e.g., `'12 hours'`, `'2 days'`). The concern parses strings, integers (seconds), or `ActiveSupport::Duration` objects.

## 6. UX Safeguards

- `_demo_banner.html.erb` appears automatically at the top of every public theme when `current_website.demo?` is true, explaining that data resets regularly and linking to the signup page.
- `DemoRestrictions` automatically redirects destructive controller actions (`destroy`, `delete_account`, `export`, etc.) when a visitor is on a demo site.
- The initializer-driven whitelist ensures only the subdomains you specify are affected, so regular tenants never see the banner or restrictions.

## 7. Local Testing Tips

1. Create a website in the console, set `demo_mode: true`, `shard_name: 'default'` (so it stays on your local DB), and assign a `demo_seed_pack`.
2. Run `Pwb::SeedPack.find(pack).apply!(website: demo_site)` once, or call `demo_site.reset_demo_data!` to exercise the full workflow. Stubbing `Pwb::SeedPack` is also acceptable in automated tests.
3. The new automated specs (`spec/models/concerns/pwb/demo_website_spec.rb` and `spec/services/pwb/demo_provisioner_spec.rb`) show how to stub `Pwb::SeedPack`, how to assert `demo_last_reset_at` updates, and how to keep tests fast without touching the actual demo shard.

## 8. Dokku Deployment

When deploying to Dokku, use the `postgres:link` command with aliases to set up shard database URLs:

```bash
# Create the shard databases
dokku postgres:create pwb-demo-shard
dokku postgres:create pwb-shard-1  # Optional: for tenant_shard_1

# Link with aliases that match config/database.yml expectations
# The --alias flag sets the environment variable name prefix
dokku postgres:link pwb-demo-shard your-app --alias PWB_DEMO_SHARD_DATABASE
dokku postgres:link pwb-shard-1 your-app --alias PWB_TENANT_SHARD_1_DATABASE

# This automatically sets:
# - PWB_DEMO_SHARD_DATABASE_URL=postgres://...
# - PWB_TENANT_SHARD_1_DATABASE_URL=postgres://...
```

**Verify the links:**
```bash
dokku postgres:app-links your-app
# Should show: pwb-demo-shard, pwb-shard-1

dokku config:show your-app | grep SHARD
# Should show the DATABASE_URL environment variables
```

**Run migrations on shards after deploy:**
```bash
dokku run your-app bin/rails db:migrate:demo_shard
dokku run your-app bin/rails db:migrate:tenant_shard_1
```

**Troubleshooting:**
- If you see "No connection pool" errors, ensure the shard database is linked
- Check that `PWB_DEMO_SHARD_DATABASE_URL` is set (not just `DATABASE_URL`)
- The app conditionally loads shards based on env vars - see `config/database.yml`

## 9. Operations Checklist

- [ ] Ensure `PWB_DEMO_SHARD_DATABASE_URL` (or equivalent) is set in every deploy environment.
- [ ] Run the `db:create`/`db:migrate` commands for the demo shard after each release with migrations.
- [ ] Keep `DEMO_SUBDOMAINS` up to date as marketing adds or removes demo URLs.
- [ ] Confirm the nightly scheduler triggers `DemoResetJob` (check logs for `[DemoReset] Reset ...`).
- [ ] Smoke-test demo subdomains after provisioning to verify the banner, seed data, and restrictions appear.
