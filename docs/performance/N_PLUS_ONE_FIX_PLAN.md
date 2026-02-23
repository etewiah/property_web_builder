# N+1 Query & Performance Fix Plan

**Date:** 2026-02-21
**Status:** PLANNING
**Priority:** 🟠 Medium / 🟡 Low
**Related:** [Master Plan](../planning/CODE_REVIEW_2026_02_MASTER_PLAN.md)

---

## Issue P1 — N+1: `Contact#unread_messages_count` in Dashboard

### Severity: 🟠 Medium

### Description

**File**: `app/models/pwb/contact.rb:85`

```ruby
def unread_messages_count
  messages.where(website_id: website_id, read: false).count
end
```

This method fires a `COUNT` SQL query for every contact rendered in a list. On a contacts dashboard showing 25 contacts, this means 25 + 1 = 26 queries just for unread counts.

**Symptom**: Slow contacts index page; Bullet gem will flag this in development.

### Option A — Counter Cache (Recommended)

Add a counter cache on the `Message` model that maintains `contacts.unread_messages_count` automatically.

**Step 1: Migration**

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_unread_messages_count_to_contacts.rb
class AddUnreadMessagesCountToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_contacts, :unread_messages_count, :integer, default: 0, null: false

    # Backfill existing data
    reversible do |dir|
      dir.up do
        Pwb::Contact.find_each do |contact|
          count = contact.messages.where(website_id: contact.website_id, read: false).count
          contact.update_column(:unread_messages_count, count)
        end
      end
    end
  end
end
```

**Step 2: Update Message model**

```ruby
# app/models/pwb/message.rb (or pwb_tenant/message.rb — verify correct file)
belongs_to :contact, counter_cache: :unread_messages_count
# Note: counter_cache only handles total count, not filtered count
# For filtered (unread only), use a custom callback instead:
```

**Note**: Rails `counter_cache` counts ALL associated records, not filtered. For an unread-only count, use callbacks instead:

```ruby
# app/models/pwb/message.rb
after_create_commit  :increment_unread_count_on_contact
after_update_commit  :update_unread_count_on_contact
after_destroy_commit :decrement_unread_count_on_contact

private

def increment_unread_count_on_contact
  contact&.increment!(:unread_messages_count) unless read?
end

def update_unread_count_on_contact
  return unless saved_change_to_read?

  if read?
    contact&.decrement!(:unread_messages_count)
  else
    contact&.increment!(:unread_messages_count)
  end
end

def decrement_unread_count_on_contact
  contact&.decrement!(:unread_messages_count) unless read?
end
```

**Step 3: Update Contact model**

```ruby
# app/models/pwb/contact.rb
# Replace the method:
def unread_messages_count
  # Now reads from cached column — no query
  read_attribute(:unread_messages_count)
end
```

Or simply remove the method and use the column directly as an attribute.

### Option B — Preload with GROUP BY (No Migration)

If a migration is undesirable right now, preload counts in the controller:

```ruby
# app/controllers/site_admin/contacts_controller.rb (verify file path)
def index
  @contacts = current_website.contacts.order(updated_at: :desc).page(params[:page])

  # Preload unread counts in a single query
  contact_ids = @contacts.map(&:id)
  @unread_counts = Pwb::Message
    .where(contact_id: contact_ids, website_id: current_website.id, read: false)
    .group(:contact_id)
    .count
  # => { contact_id => count, ... }
end
```

Then in views use `@unread_counts[contact.id].to_i` instead of `contact.unread_messages_count`.

### Recommended Approach

Option A (counter cache with callbacks) for permanent fix. Option B as a quick interim measure.

### Implementation Steps

1. Read `app/models/pwb/contact.rb` and `app/models/pwb/message.rb` (or tenant equivalent)
2. Verify the association between Contact and Message
3. Write and run migration adding `unread_messages_count` column
4. Add callbacks to Message model
5. Update Contact model to use cached column
6. Add spec: `spec/models/pwb/message_spec.rb` — verify counter increments/decrements correctly
7. Enable Bullet in test environment and add N+1 detection spec for contacts index
8. Test backfill is correct by comparing cached vs calculated counts in a test

### Acceptance Criteria

- [ ] Contacts dashboard makes 1 query for unread counts (not N)
- [ ] Counter stays accurate when messages are created, read, deleted
- [ ] Backfill migration works on existing data
- [ ] Bullet gem no longer flags this endpoint

---

## Issue P2 — N+1: API Auth Uses Ruby `.find` on Loaded Collection

### Severity: 🟠 Medium

### Description

**File**: `app/controllers/api_manage/v1/base_controller.rb:85`

```ruby
api_key = request.headers["X-API-Key"]
integration = current_website&.integrations&.enabled&.find do |i|
  i.credential("api_key") == api_key
end
```

**Problems:**

1. `.find { }` with a block loads ALL enabled integrations into Ruby, then iterates
2. `i.credential("api_key")` may trigger additional queries per integration (if credentials are lazily loaded or stored separately)
3. This runs on **every authenticated API request** — high frequency code path

### Proposed Fix

**Option A — SQL-level lookup (if credentials are stored in a JSONB column)**

If `credential("api_key")` reads from a JSONB column on the integration record:

```ruby
# If credentials stored as JSONB column `credentials`
integration = current_website&.integrations
  &.enabled
  &.where("credentials->>'api_key' = ?", api_key)
  &.first
```

**Option B — Separate indexed lookup table**

If credentials are stored in a separate `pwb_integration_credentials` table:

```ruby
# Add index: add_index :pwb_integration_credentials, [:key, :value, :integration_id]
integration = current_website&.integrations
  &.enabled
  &.joins(:integration_credentials)
  &.where(integration_credentials: { key: "api_key", value: api_key })
  &.first
```

**Option C — Cache the API key lookup**

Since API keys don't change often, cache the integration_id lookup:

```ruby
def find_integration_by_api_key(api_key)
  cache_key = "api_key_lookup:#{current_website.id}:#{Digest::SHA256.hexdigest(api_key)}"

  integration_id = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    # Only loaded once per cache TTL
    current_website.integrations.enabled.find { |i|
      i.credential("api_key") == api_key
    }&.id
  end

  integration_id ? current_website.integrations.find_by(id: integration_id) : nil
end
```

### Investigation Required First

Before implementing, read:
1. `app/models/pwb/integration.rb` — how `credential()` works
2. `db/schema.rb` — how credentials are stored (column type, separate table?)
3. Determine if a SQL-level query is possible

### Implementation Steps

1. Read `app/models/pwb/integration.rb` to understand credential storage
2. Check schema for `pwb_integrations` table structure
3. Choose Option A, B, or C based on storage structure
4. Implement the fix
5. Add index if needed (migration)
6. Add spec verifying API auth works correctly
7. Add performance spec or note in Bullet config

### Acceptance Criteria

- [ ] API authentication does not load all integrations into memory
- [ ] Single SQL query (or cached lookup) used for API key verification
- [ ] No regression in API authentication behavior
- [ ] Response time improves for authenticated API endpoints

---

## Issue P3 — Missing Composite Indexes

### Severity: 🟡 Low

### Description

The schema has 378 indexes (well-covered), but EXPLAIN ANALYZE on key queries may reveal missing composite indexes for common filter patterns.

### Suspected Missing Indexes

These are candidates — **verify with EXPLAIN ANALYZE before adding**:

| Table | Columns | Reason |
|-------|---------|--------|
| `pwb_realty_assets` | `(website_id, created_at)` | "Latest listings" queries |
| `pwb_contacts` | `(website_id, updated_at)` | Dashboard ordering |
| `pwb_props` | `(website_id, visible, for_sale)` | Filtered property search |
| `pwb_props` | `(website_id, visible, for_rent)` | Filtered rental search |
| `pwb_messages` | `(contact_id, read, website_id)` | Unread count queries |

### Investigation Process

Run EXPLAIN ANALYZE on the key queries in development:

```sql
-- Contacts dashboard query
EXPLAIN ANALYZE SELECT * FROM pwb_contacts
WHERE website_id = 1 ORDER BY updated_at DESC LIMIT 25;

-- Property search query
EXPLAIN ANALYZE SELECT * FROM pwb_props
WHERE website_id = 1 AND visible = true AND for_sale = true
ORDER BY created_at DESC LIMIT 12;
```

Look for `Seq Scan` on large tables. If found, add the missing index.

### Migration Template

```ruby
class AddMissingCompositeIndexes < ActiveRecord::Migration[8.1]
  def change
    # Add only indexes confirmed needed by EXPLAIN ANALYZE
    add_index :pwb_contacts, [:website_id, :updated_at],
              name: "idx_pwb_contacts_website_updated_at"

    add_index :pwb_realty_assets, [:website_id, :created_at],
              name: "idx_pwb_realty_assets_website_created_at"

    add_index :pwb_props, [:website_id, :visible, :for_sale],
              name: "idx_pwb_props_website_visible_for_sale"
  end
end
```

### Implementation Steps

1. Set up local database with representative data volume (or use staging)
2. Run EXPLAIN ANALYZE on contacts index, property search, rental search queries
3. Identify Seq Scans on large tables
4. Create migration for only the indexes that show a need
5. Re-run EXPLAIN ANALYZE to confirm improvement
6. Deploy migration (low risk — additive only)

### Acceptance Criteria

- [ ] EXPLAIN ANALYZE shows Index Scan (not Seq Scan) on key queries
- [ ] No redundant indexes added
- [ ] Migration is reversible

---

## Issue P4 — Missing API Cache-Control Headers

### Severity: 🟡 Low

### Description

Public API endpoints that return static or slowly-changing data (property listings, search results) should set `Cache-Control` headers so CDNs and clients can cache responses.

A spec file exists (`spec/requests/api_public/v1/cache_headers_spec.rb`) — verify it's actually asserting headers, not just testing that the endpoint returns 200.

### Investigation Required

1. Read `spec/requests/api_public/v1/cache_headers_spec.rb` — check what it actually asserts
2. Read `app/controllers/api_public/v1/` — check for `expires_in`, `fresh_when`, `stale?` usage

### Proposed Fix

For read-only, public API endpoints:

```ruby
# app/controllers/api_public/v1/properties_controller.rb (example)
def index
  @properties = current_website.listed_properties.page(params[:page])

  # Allow CDN/browser to cache for 5 minutes
  expires_in 5.minutes, public: true

  # Or use ETags for conditional GET support
  fresh_when @properties, public: true

  render json: @properties
end
```

### Acceptance Criteria

- [ ] Read endpoints on `api_public/v1` return `Cache-Control: public, max-age=300`
- [ ] ETag or Last-Modified header set for conditional GET support
- [ ] Existing cache_headers_spec actually asserts header values

---

## Summary Checklist

| Issue | Sprint | Status |
|-------|--------|--------|
| P1 — Contact unread_messages_count N+1 | Sprint 2 | ⬜ TODO |
| P2 — API auth Ruby `.find` N+1 | Sprint 2 | ⬜ TODO |
| P3 — Missing composite indexes | Sprint 5 | ⬜ TODO |
| P4 — API cache-control headers | Sprint 3 | ⬜ TODO |
