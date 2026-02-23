# Security Improvement Plan

**Date:** 2026-02-21
**Status:** PLANNING
**Priority:** 🔴 High / 🟠 Medium
**Related:** [Master Plan](../planning/CODE_REVIEW_2026_02_MASTER_PLAN.md)

---

## Issue S1 — Unauthenticated Website Creation (SetupController)

### Risk Level: 🔴 High

### Description

`SetupController` has no authentication guard. Any anonymous user can POST to the setup endpoint and create a website on any unclaimed subdomain. This could be used to:
- Exhaust subdomain namespace
- Create spam/phishing tenants on the platform
- Probe the provisioning system

### Current Code

**File**: `app/controllers/pwb/setup_controller.rb`

No `before_action :authenticate_user!` or equivalent. The controller is intentionally open for new-user onboarding, but has no bot/abuse protection.

### Proposed Fix

**Option A (Recommended) — Rack-Attack rate limiting:**

Add a rule to `config/initializers/rack_attack.rb`:

```ruby
# Throttle website creation attempts per IP
Rack::Attack.throttle("setup/ip", limit: 3, period: 1.hour) do |req|
  if req.path == "/setup" && req.post?
    req.ip
  end
end

# Block repeated failures (returns 429)
Rack::Attack.throttle("setup/email", limit: 5, period: 1.day) do |req|
  if req.path == "/setup" && req.post?
    req.params["email"]&.downcase&.gsub(/\s+/, "")
  end
end
```

**Option B — Add reCAPTCHA to setup form:**

The app already has the `recaptcha` gem. Add to `SetupController`:

```ruby
before_action :verify_recaptcha, only: [:create]
```

And add `<%= recaptcha_tags %>` to the setup form view.

**Option C — Both (belt and suspenders for high-value endpoints):**

Apply rate limiting + CAPTCHA for maximum protection.

### Implementation Steps

1. Open `config/initializers/rack_attack.rb` — verify it exists and has correct middleware mounting
2. Add IP-based throttle rule for setup POST
3. Add email-based throttle rule for setup POST
4. Add test: `spec/requests/pwb/setup_controller_spec.rb` — verify 429 after threshold
5. If reCAPTCHA desired: add `verify_recaptcha` before_action and update form view
6. Document in `docs/security/` that setup throttling is intentional

### Acceptance Criteria

- [ ] POST `/setup` returns 429 after 3 attempts from same IP within 1 hour
- [ ] Test covers the throttle behavior
- [ ] No impact on legitimate first-time signups

---

## Issue S2 — `Website.first` Fallback Serves Wrong Tenant

### Risk Level: 🔴 High

### Description

**File**: `app/controllers/pwb/application_controller.rb:82`

```ruby
@current_website = current_website_from_subdomain || Pwb::Current.website || Website.first
```

If subdomain resolution fails AND `Pwb::Current.website` is nil (e.g., middleware failure, test environment, unknown subdomain), the app falls back to `Website.first` — silently serving the first tenant in the database to the wrong visitor.

This is a data exposure risk. In a multi-tenant SaaS, serving tenant A's data to tenant B's user is a breach.

### Proposed Fix

Replace the fallback chain with an explicit failure:

```ruby
# BEFORE
@current_website = current_website_from_subdomain || Pwb::Current.website || Website.first

# AFTER
@current_website = current_website_from_subdomain || Pwb::Current.website
if @current_website.nil?
  render file: "public/404.html", status: :not_found, layout: false
  return
end
```

Or, if the `Website.first` fallback serves a legitimate purpose (e.g., a canonical root domain with no subdomain), document and constrain it:

```ruby
# Only fall back to Website.first for the root domain (no subdomain)
@current_website = current_website_from_subdomain ||
                   Pwb::Current.website ||
                   (request.subdomain.blank? ? Website.find_by(is_root: true) : nil)

if @current_website.nil?
  render file: "public/404.html", status: :not_found, layout: false
  return
end
```

### Implementation Steps

1. Read `app/controllers/pwb/application_controller.rb` fully to understand context
2. Check if `Website.first` fallback is used intentionally for root-domain handling
3. If so: add an explicit `is_root` boolean column with migration and use it in the fallback
4. If not: remove the fallback entirely, render 404
5. Add test: request to unknown subdomain should return 404, not 200 with wrong tenant data
6. Run existing multi-tenancy specs to confirm no regression

### Acceptance Criteria

- [ ] Request to unknown subdomain returns 404
- [ ] `Website.first` is never called unless explicitly scoped to root domain
- [ ] Multi-tenancy isolation specs still pass
- [ ] No regressions in normal subdomain-based routing

---

## Issue S3 — `bypass_admin_auth?` Production Safety

### Risk Level: 🟠 Medium

### Description

**File**: `app/controllers/site_admin_controller.rb:31`
**File**: `app/controllers/concerns/admin_auth_bypass.rb`

```ruby
before_action :require_admin!, unless: :bypass_admin_auth?
```

The bypass is gated on environment variables (`BYPASS_ADMIN_AUTH=true`) and restricted to `%w[development e2e test]` environments. However:

1. It's unclear if the app fails **closed** (denies) or **open** (allows) if the env var is missing
2. No automated check verifies this is disabled in production deployments
3. If a production `.env` inadvertently sets `BYPASS_ADMIN_AUTH=true`, all admin endpoints become unprotected

### Proposed Fix

**Step 1: Audit the concern**

Read `app/controllers/concerns/admin_auth_bypass.rb` and verify:

```ruby
# Should look like this — fails CLOSED (denies) by default
def bypass_admin_auth?
  return false unless Rails.env.in?(%w[development e2e test])
  ENV["BYPASS_ADMIN_AUTH"] == "true"
end
```

**Step 2: Add production startup assertion**

In `config/initializers/` or `config/application.rb`, add a check that raises on boot if the bypass is misconfigured:

```ruby
# config/initializers/security_assertions.rb
if Rails.env.production?
  if ENV["BYPASS_ADMIN_AUTH"] == "true"
    raise "SECURITY ERROR: BYPASS_ADMIN_AUTH must not be set in production!"
  end
end
```

**Step 3: Add to CI**

Ensure `BYPASS_ADMIN_AUTH` is NOT set in production CI environment configs.

### Implementation Steps

1. Read `app/controllers/concerns/admin_auth_bypass.rb`
2. Verify the logic fails closed by default
3. Create `config/initializers/security_assertions.rb` with production guard
4. Add test: `spec/initializers/security_assertions_spec.rb` that verifies the guard raises in production
5. Document the bypass mechanism in `docs/security/`

### Acceptance Criteria

- [ ] `bypass_admin_auth?` returns `false` in production regardless of env vars
- [ ] App raises on boot if `BYPASS_ADMIN_AUTH=true` in production
- [ ] Concern is documented

---

## Issue S4 — Liquid Template Injection Risk

### Risk Level: 🟠 Medium (Unverified)

### Description

The app uses Liquid for dynamic page templating (`app/themes/`). Liquid is generally safe — it sandboxes template execution by design. However, risks arise when:

1. **User-controlled data is rendered without escaping** in template context
2. **Custom Liquid tags/filters** expose Ruby methods or system calls
3. **Admin-editable templates** allow arbitrary Liquid that runs in the server context

### Investigation Required

Before implementing any fix, audit:

**File search targets:**
```bash
grep -r "Liquid::Template" app/
grep -r "render_liquid" app/
grep -r "Liquid::Environment" app/
grep -r "drop" app/models/  # Liquid::Drop subclasses
```

**Key questions:**
- Can non-admin users edit Liquid templates? If yes, what's the injection surface?
- Are custom Liquid drops (Ruby model wrappers) exposing methods that shouldn't be public?
- Is user-supplied content passed into `assigns` hash without sanitization?

### Proposed Fix (once audit is complete)

**A — Restrict Liquid object exposure (Drops)**

Ensure all Liquid::Drop subclasses only expose safe attributes:

```ruby
class PropertyDrop < Liquid::Drop
  # Explicitly allowlist exposed attributes
  liquid_attributes :title, :price, :address

  # Do NOT expose: website_id, internal IDs, admin config
end
```

**B — Sanitize user content before passing to template context**

```ruby
assigns = {
  "property" => property_drop,
  "user_content" => Liquid::Utils.safe_value(user_input)  # sanitize before injection
}
```

**C — Restrict template editing to admins only**

Ensure template edit endpoints are gated behind admin authentication.

### Implementation Steps

1. Grep for all `Liquid::Template.parse` and `render` calls
2. Identify which template content is admin-editable vs user-editable
3. Review all `Liquid::Drop` subclasses for exposed methods
4. Document findings in `docs/security/LIQUID_TEMPLATE_AUDIT.md`
5. Implement fixes based on findings
6. Add tests for any injection vectors found

### Acceptance Criteria

- [ ] Audit document exists with findings
- [ ] User-editable content cannot break out of Liquid sandbox
- [ ] All Drop subclasses only expose safe attributes
- [ ] Template editing restricted to appropriate roles

---

## Summary Checklist

| Issue | Sprint | Owner | Status |
|-------|--------|-------|--------|
| S1 — SetupController rate limiting | Sprint 1 | - | ⬜ TODO |
| S2 — Remove `Website.first` fallback | Sprint 1 | - | ⬜ TODO |
| S3 — Audit bypass_admin_auth? | Sprint 1 | - | ⬜ TODO |
| S4 — Liquid template audit | Sprint 3 | - | ⬜ TODO |
