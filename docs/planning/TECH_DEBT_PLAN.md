# Tech Debt Reduction Plan

**Date:** 2026-02-21
**Status:** PLANNING
**Priority:** 🟠 Medium / 🟡 Low
**Related:** [Master Plan](CODE_REVIEW_2026_02_MASTER_PLAN.md)

---

## Issue T1 — Tenant Scoping by Convention, Not Enforcement

### Severity: 🟠 Medium

### Description

Some models (notably `Pwb::Contact` and associated models) use comments to document that tenant scoping must be applied manually:

```ruby
# app/models/pwb/contact.rb:59
# NOTE: Tenant scoping for messages handled at query level in controllers
```

This is fragile. Any new controller action or service that queries these models and forgets the scope will silently return cross-tenant data. This becomes more likely as the codebase grows and new developers join.

### Root Cause

The `Pwb::Contact` model (and similar) appear to be in the `Pwb::` namespace (not `PwbTenant::`) but still require `website_id` scoping. They may predate the `acts_as_tenant` adoption.

### Proposed Fix

**Step 1: Audit models that use comment-based scoping**

```bash
grep -rn "Tenant scoping handled" app/models/
grep -rn "scope handled at" app/models/
grep -rn "website_id" app/models/pwb/ --include="*.rb" -l
```

**Step 2: Migrate to `acts_as_tenant` enforcement**

For each model identified:

```ruby
# BEFORE (comment-based)
class Pwb::Contact < ApplicationRecord
  belongs_to :website
  # NOTE: Always scope queries by website_id
end

# AFTER (enforced)
class Pwb::Contact < ApplicationRecord
  acts_as_tenant :website  # Enforces scoping via default_scope
  belongs_to :website
end
```

**Step 3: Or add a `default_scope` if `acts_as_tenant` is not appropriate**

```ruby
class Pwb::Contact < ApplicationRecord
  belongs_to :website

  default_scope { where(website_id: Pwb::Current.website&.id) if Pwb::Current.website }
end
```

**Step 4: Verify associations**

For `Contact.messages`, ensure the association itself is scoped:

```ruby
has_many :messages, -> { where(website_id: website_id) }, class_name: "Pwb::Message"
```

### Risk

**Medium risk** — changing scoping behavior can break existing queries. Must run full test suite after each change.

### Implementation Steps

1. Run grep to identify all models with comment-based scoping
2. For each model, read its full definition
3. Determine if `acts_as_tenant` or `default_scope` is more appropriate
4. Apply change one model at a time
5. Run `rspec spec/models/` after each change
6. Run multi-tenancy isolation specs: `rspec spec/requests/api_public/v1/cross_tenant_isolation_spec.rb`
7. Update comments/documentation

### Acceptance Criteria

- [ ] No models use `# NOTE: Tenant scoping handled manually` comments
- [ ] Scoping is enforced at the model layer
- [ ] Cross-tenant isolation specs pass
- [ ] No regression in existing specs

---

## Issue T2 — `website.rb` Needs Decomposition

### Severity: 🟡 Low

### Description

`app/models/pwb/website.rb` is 650+ lines containing:
- Core attributes and validations
- 30+ `has_many` associations
- Billing/subscription logic
- Theme/styling configuration
- Provisioning logic
- Analytics helpers
- Email configuration
- Feature flags

This makes the file hard to navigate, increases merge conflicts, and buries important logic.

### Proposed Decomposition

Extract into focused concerns:

```
app/models/pwb/website.rb              # Core: attributes, validations, key associations
app/models/concerns/pwb/
  website/
    billable.rb          # Subscription/billing logic
    themeable.rb         # Theme/styling configuration
    provisionable.rb     # (may already exist — check)
    analyticsable.rb     # Analytics helpers
    mailable.rb          # Email configuration
    feature_flaggable.rb # Feature flags
```

### Extraction Template

```ruby
# app/models/concerns/pwb/website/billable.rb
module Pwb
  module Website
    module Billable
      extend ActiveSupport::Concern

      included do
        # associations and scopes related to billing
        has_many :subscriptions, class_name: "Pwb::Subscription"
        has_many :invoices, class_name: "Pwb::Invoice"
      end

      # instance methods related to billing
      def active_subscription
        subscriptions.active.first
      end

      def subscription_expired?
        # ...
      end
    end
  end
end
```

### Implementation Steps

1. Read `app/models/pwb/website.rb` in full
2. Categorize every method/association by domain
3. Check which concerns already exist (`app/models/concerns/pwb/`)
4. Extract one concern at a time (billing first — most isolated)
5. Include the concern in `website.rb`: `include Pwb::Website::Billable`
6. Run `rspec spec/models/pwb/website_spec.rb` after each extraction
7. Run full spec suite after all extractions

### Acceptance Criteria

- [ ] `website.rb` is under 200 lines
- [ ] Each concern is under 100 lines and focused on one responsibility
- [ ] Full spec suite passes
- [ ] No behavioural changes

---

## Issue T3 — Deprecated Directories Still Present

### Severity: 🟡 Low

### Description

Two directories exist with `DEPRECATED.md` files indicating they should not be used:

- `app/frontend/` — Vue.js application (replaced by Stimulus.js)
- `app/graphql/` — GraphQL API (replaced by REST API)

These directories:
- Confuse new contributors about the current architecture
- May contain dead code that gets accidentally maintained
- Increase codebase size without benefit

### Investigation Required

Before removing, determine:
1. Is any code in `app/frontend/` still being served or built?
2. Is any code in `app/graphql/` still referenced anywhere?
3. Are there any routes pointing to GraphQL endpoints?

```bash
grep -r "graphql" config/routes.rb
grep -r "require.*frontend" app/assets/
grep -r "graphql" app/controllers/ --include="*.rb"
```

### Proposed Fix

**If confirmed unused:**

```bash
# Remove Vue.js app
rm -rf app/frontend/

# Remove GraphQL
rm -rf app/graphql/
```

Also check and remove from Gemfile:
```ruby
# Remove if present and unused
gem "graphql"
gem "graphql-rails"
```

**If partially used (e.g., some Vue components still embedded):**

Document what's still active in a migration plan before removal.

### Implementation Steps

1. Grep for any references to `app/frontend` and `app/graphql` outside those directories
2. Check `config/routes.rb` for GraphQL route mounting
3. Check `app/assets/config/manifest.js` for frontend asset references
4. If confirmed unused, remove directories and update Gemfile
5. Run `rspec` to confirm no breakage
6. Commit separately with clear message: "Remove deprecated Vue.js and GraphQL code"

### Acceptance Criteria

- [ ] No references to removed directories remain in active code
- [ ] `config/routes.rb` has no GraphQL route
- [ ] Gemfile has no unused graphql gems
- [ ] Full spec suite passes

---

## Issue T4 — Optional `belongs_to :website` Creates Scoping Risk

### Severity: 🟡 Low

### Description

Many models use:

```ruby
belongs_to :website, optional: true
```

This was likely added to avoid validation failures in edge cases (cross-tenant operations, seeds, tests). However, it means that any code calling `Model.all` without a website scope won't raise an error — it silently returns all records across all tenants.

### Investigation Required

```bash
grep -rn "belongs_to :website, optional: true" app/models/
```

Determine which models have optional website associations and WHY they're optional.

### Proposed Fix

**Case 1: Optional because of seeds/test data**
Fix seeds and factories to always provide a website. Remove `optional: true`.

**Case 2: Optional because of cross-tenant operations (super admin)**
Keep `optional: true` but add a validation for non-admin contexts:

```ruby
# Still allows nil in certain contexts but requires website in normal use
validates :website, presence: true, unless: :cross_tenant_operation?
```

**Case 3: Optional because model truly isn't scoped to a website**
Document this explicitly:

```ruby
# This model is platform-wide, not website-scoped (e.g., SystemConfig)
belongs_to :website, optional: true  # Intentionally not tenant-scoped
```

### Implementation Steps

1. Run grep to list all models with `optional: true` on website
2. For each: read the model, understand why it's optional
3. Categorize each as Case 1, 2, or 3
4. Fix Case 1 models by updating seeds/factories
5. For Case 2: add contextual validation
6. For Case 3: add explanatory comment

### Acceptance Criteria

- [ ] All `belongs_to :website, optional: true` usages are explicitly justified
- [ ] Models that should always have a website have it enforced
- [ ] Spec suite passes

---

## Summary Checklist

| Issue | Sprint | Status |
|-------|--------|--------|
| T1 — Enforce tenant scoping | Sprint 4 | ⬜ TODO |
| T2 — Decompose website.rb | Sprint 4 | ⬜ TODO |
| T3 — Remove deprecated directories | Sprint 4 | ⬜ TODO |
| T4 — Audit optional belongs_to :website | Sprint 4 | ⬜ TODO |
