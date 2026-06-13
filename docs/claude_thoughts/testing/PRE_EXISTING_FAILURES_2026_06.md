# Pre-Existing RSpec Failures (as of 2026-06-12)

**STATUS: ✅ ALL FIXED (2026-06-13)**

All 18 failures documented below have been fixed and committed in commit 8edbf050.
See project memory for implementation details.

---

Context: after running `bundle update`, the full suite was run
(`bundle exec rspec`): **2157 examples, 18 failures, 14 pending**. All 18
failures were confirmed to be **pre-existing and unrelated to the gem bumps**
(reverting `Gemfile.lock` and re-running a sample of the failing specs
reproduces the same failures with the old gem versions).

This document explains the root cause of each failure and how to fix it.
The 18 failures fall into **4 distinct root causes**.

---

## 🔴 Root cause #1 (HIGH SEVERITY): `current_website` is shadowed by
`CacheHelper` / `HttpCacheable` / `SeoHelper`

**Affects 10 of the 18 failures** and is very likely a **live production bug**,
not just a test problem.

### The bug

`Pwb::ApplicationController` defines a correct, memoized `current_website`:

```ruby
# app/controllers/pwb/application_controller.rb
def current_website
  @current_website ||= current_website_from_subdomain || Pwb::Current.website
end
```

However, three concerns/helpers **also define a private `current_website`**:

- `app/controllers/concerns/http_cacheable.rb:91-94`
- `app/helpers/seo_helper.rb:361-364`
- `app/helpers/cache_helper.rb:285-290`

All three look like:

```ruby
def current_website
  return @current_website if defined?(@current_website)
  @current_website = Pwb::Current.website rescue nil
end
```

`Pwb::PagesController`, `Pwb::SearchController`, `Pwb::PropsController`, and
`Pwb::Site::ExternalListingsController` all `include` one or more of these
modules. In Ruby, **modules included into a subclass are placed in the
ancestor chain *above* the superclass**, regardless of where in the class body
the `include` appears. Confirmed empirically:

```
Pwb::PagesController.ancestors.take(5)
# => [Pwb::PagesController, CacheHelper, HttpCacheable, SeoHelper, Pwb::ApplicationController, ...]

Pwb::PagesController.instance_method(:current_website).owner
# => CacheHelper
```

So for these controllers, `current_website` **never reaches**
`ApplicationController#current_website`. It resolves to (e.g.) `CacheHelper#current_website`,
which on the very first call (before `@current_website` is set) returns
`Pwb::Current.website` — which is **`nil`** at the start of every request
(nothing sets it before `current_agency_and_website` runs for these
controllers; `SubdomainTenant`, which does set it, is only included in
`ApiManage`/GraphQL controllers, not these).

The `before_action` chain then does:

```ruby
def current_agency_and_website
  @current_website = current_website   # resolves to the shadowed nil-returning method
  ...
end

def check_unseeded_website
  return if @current_website.present?
  return if request.path.start_with?('/setup')
  redirect_to pwb_setup_path            # <-- fires, 302
end
```

Result: **every request to `PagesController`, `SearchController`,
`PropsController`, and `ExternalListingsController` redirects to `/setup`**
instead of resolving the tenant from the subdomain/custom domain.

### Why it matters beyond the tests

This is the controller that renders the public-facing site (`/buy`, `/rent`,
`/p/:slug`, CMS pages, external listing pages, sitemap). If this analysis is
correct for the deployed environment too, **tenant pages would not render**.
Recommend verifying against a real running instance (or staging) as a priority,
independent of fixing the specs.

### Fix

Do **not** delete these `current_website` definitions blindly —
`SitemapsController < ActionController::Base` (not `Pwb::ApplicationController`)
relies on `SeoHelper#current_website` as its *only* source of `current_website`,
since it doesn't inherit from `ApplicationController`.

Recommended fix:

1. Rename the private `current_website` methods in `HttpCacheable`,
   `SeoHelper`, and `CacheHelper` to a distinct name, e.g.
   `helper_current_website`, and update all internal call sites within those
   three files (`SeoHelper` has ~10 internal call sites, `CacheHelper` has ~4,
   `HttpCacheable` has ~3).
2. In `SitemapsController`, add:
   ```ruby
   private

   def current_website
     helper_current_website
   end
   ```
   so its behavior is unchanged.
3. For `Pwb::PagesController`, `Pwb::SearchController`, `Pwb::PropsController`,
   and `Pwb::Site::ExternalListingsController`, no further change is needed —
   `current_website` will now correctly resolve to
   `Pwb::ApplicationController#current_website` since the shadowing methods
   are gone.

### Failures fixed by this change

#### `spec/features/locale_url_spec.rb` (2 failures)
- `renders at /es/buy for Spanish` (line 27)
- `renders at /buy without locale` (line 32)

Both hit `SearchController#buy`, which includes `HttpCacheable`/`SeoHelper`,
and both currently 302 to `/setup?locale=en` instead of rendering. The spec
also stubs `allow_any_instance_of(ActionController::Base).to
receive(:current_website)`, but that stub is ineffective for the same reason
(the subclass's included module wins over the stub target). Once the shadowing
is removed, `current_website` resolves correctly via `current_website_from_subdomain`
and the stub becomes unnecessary (it can be left in place harmlessly, or removed
for clarity).

#### `spec/requests/controller_multi_tenancy_spec.rb` (8 failures)
- `SearchController #buy` — both tenant tests (lines 101, 111)
- `SearchController #rent` — both tenant tests (lines 123, 133)
- `PropsController #show_for_sale` — both tenant tests (lines 155, 174)
- `PagesController` — both tenant tests (lines 197, 205)

(`WelcomeController`'s tests in the same file already pass — it does **not**
include any of the three shadowing modules, which is the key supporting
evidence for this root cause.)

All 8 fail with a 302 to `/setup` for the same reason as above. No spec
changes should be needed once the helper rename lands — `host!` is already
set correctly to each tenant's subdomain in this spec.

---

## 🟡 Root cause #2: `spec/requests/pwb/reports/public_cma_spec.rb` (3 failures)

- `with non-shared report returns not found for draft reports` (line 51) — expects 404, gets 302
- `with valid share token returns the shared report as JSON` (line 17) — expects 200, gets 302
- `with valid share token increments the view count` (line 27) — view_count stays 0

`Pwb::Reports::PublicCmaController < Pwb::ApplicationController` and does
**not** include `HttpCacheable`/`SeoHelper`/`CacheHelper`, so root cause #1
does not apply here.

The spec never calls `host!`, so requests go to the default test host
(`www.example.com`). `extract_subdomain_from_host('www.example.com')` returns
`"www"`, which is in `RESERVED_SUBDOMAINS`/not a real tenant, so
`current_website_from_subdomain` returns `nil`, `Pwb::Current.website` is also
`nil`, and `check_unseeded_website` redirects to `/setup` before the
controller action ever runs — hence the 302s and the report's `view_count`
never being incremented.

### Fix

Add a `before` hook (or per-`describe`/`it` `host!` call) to set the request
host to the `website`'s subdomain, e.g.:

```ruby
before do
  host! "#{website.subdomain}.example.com"
end
```

(`example.com` is already registered as a platform domain in
`spec/rails_helper.rb` for exactly this purpose.) This is independent of and
does not require the root cause #1 fix.

---

## 🟡 Root cause #3: `spec/models/pwb/website_custom_domain_spec.rb` (2 failures)

- `allows valid custom domains` (line 12) — sets `custom_domain = 'example.com'`, expects valid
- `allows www subdomain` (line 17) — sets `custom_domain = 'www.example.com'`, expects valid

`spec/rails_helper.rb` adds `"example.com"` to `PLATFORM_DOMAINS` (via
`ENV["PLATFORM_DOMAINS"] ||= "...,example.com"`) so that request specs using
`host! "subdomain.example.com"` resolve correctly. But `Website#custom_domain_not_platform_domain`
checks the custom domain against `Website.platform_domains`, and now rejects
`'example.com'`/`'www.example.com'` as "cannot be a platform domain
(example.com)" — which is in fact *correct* validator behavior given the
env var, but conflicts with this spec's test data.

### Fix

These two tests are using `example.com` as a stand-in for "some valid
external domain" — that's now a poisoned choice given the `PLATFORM_DOMAINS`
override. Change the test domains to a domain that is not a platform domain,
e.g.:

```ruby
it 'allows valid custom domains' do
  website.custom_domain = 'myotherrealestate.com'
  expect(website).to be_valid
end

it 'allows www subdomain' do
  website.custom_domain = 'www.myotherrealestate.com'
  expect(website).to be_valid
end
```

(`'shop.example.co.uk'` is already used a few lines below for the
multi-level-subdomain test and passes today, since `example.co.uk` ≠
`example.com`.)

---

## 🟢 Root cause #4: `spec/requests/api_manage/v1/cross_tenant_isolation_spec.rb` (3 failures)

All 3 are in the `Website Context Requirement` block and expect `:ok` (200)
but get `:bad_request` (400) from `ApiManage::V1::BaseController#require_website!`:

```ruby
# app/controllers/api_manage/v1/base_controller.rb
def require_website!
  return if current_website.present?
  render json: { error: 'Website context required', ... }, status: :bad_request
end
```

This guard was **intentionally added in commit #173** ("Fix unauthenticated
api_manage and legacy api/v1 write endpoints") to close a security hole where
requests with no resolvable tenant used to silently fall back to "the first
website in the database". These 3 tests describe and assert that **old,
intentionally-removed** fallback behavior.

### Test 1 & 2 — stale expectations, update them

- `without website context` → `falls back to a default website (current
  behavior)` (line 19/25): `GET /api_manage/v1/en/pages` with `HTTP_HOST:
  localhost` and no tenant-identifying header.
- `with X-Website-Slug header` → `falls back when website slug not found
  (current behavior)` (line 42/50): `X-Website-Slug: 'nonexistent-slug'`.

Both of these *should* now return 400 per the new (correct) security
behavior. Fix: update both tests to expect `:bad_request`, and rename them to
drop "(current behavior)"/"falls back", e.g.:

```ruby
it 'returns 400 when no tenant context can be resolved' do
  get '/api_manage/v1/en/pages', headers: { 'HTTP_HOST' => 'localhost' }
  expect(response).to have_http_status(:bad_request)
end
```

```ruby
it 'returns 400 when X-Website-Slug does not match any website' do
  get '/api_manage/v1/en/pages',
      headers: { 'HTTP_HOST' => 'localhost', 'X-Website-Slug' => 'nonexistent-slug' }
  expect(response).to have_http_status(:bad_request)
end
```

### Test 3 — `accepts request with valid website slug` (line 30/37) — genuine bug in the test

```ruby
get '/api_manage/v1/en/pages',
    headers: { 'HTTP_HOST' => 'localhost', 'X-Website-Slug' => website_a.slug }
expect(response).to have_http_status(:ok)
```

`SubdomainTenant#website_from_slug_header` does:

```ruby
def website_from_slug_header
  slug = request.headers["X-Website-Slug"]
  return nil if slug.blank?
  Pwb::Website.find_by(slug: slug) || Pwb::Website.find_by_subdomain(slug)
end
```

The problem: `Pwb::Website#slug` is **overridden as an instance method**
(`app/models/pwb/website.rb:252-254`):

```ruby
def slug
  "website"
end
```

This shadows the `slug` *database column* (which does exist — see
`db/schema.rb` / the `index_pwb_websites_on_slug` index — but is never read
via this method). So `website_a.slug` is **always the literal string
`"website"`** for every `Pwb::Website` instance, regardless of its actual
`slug` column value or `subdomain`.

As a result: `X-Website-Slug: "website"` →
`Pwb::Website.find_by(slug: "website")` finds nothing (no row has that in its
`slug` column) → `find_by_subdomain("website")` also finds nothing → falls
through to `website_from_host("localhost")` → `nil` → `require_website!`
returns 400.

#### Fix options

1. **(Lowest risk, recommended for this spec)** — Fix the test to send a
   header value that `website_from_slug_header` can actually resolve, e.g.
   `website_a.subdomain` (which *is* checked via `find_by_subdomain` as a
   fallback):
   ```ruby
   get '/api_manage/v1/en/pages',
       headers: { 'HTTP_HOST' => 'localhost', 'X-Website-Slug' => website_a.subdomain }
   expect(response).to have_http_status(:ok)
   ```

2. **(Separate, larger investigation — do not bundle with this fix)** —
   `Pwb::Website#slug` hard-coding `"website"` looks like it may itself be a
   latent bug: it permanently shadows the `slug` *column* for all instances.
   `app/models/pwb/website.rb:227` and `:398` also reference `slug`/`"website"`
   in ways that suggest this was deliberate (e.g. for `PagePart` lookups keyed
   by `page_slug: 'website'`), so this needs its own investigation into
   whether the `slug` column is used/populated anywhere and what the intended
   contract is before touching it. Recommend a follow-up
   `docs/claude_thoughts/` note specifically on `Pwb::Website#slug` vs. the
   `slug` column if this is pursued.

---

## Summary table

| Spec file | # failures | Root cause | Fix complexity |
|---|---|---|---|
| `spec/features/locale_url_spec.rb` | 2 | #1 (current_website shadowing) | Shared fix across controllers |
| `spec/requests/controller_multi_tenancy_spec.rb` | 8 | #1 (current_website shadowing) | Shared fix across controllers |
| `spec/requests/pwb/reports/public_cma_spec.rb` | 3 | #2 (missing `host!`) | Spec-only, add `before { host! ... }` |
| `spec/models/pwb/website_custom_domain_spec.rb` | 2 | #3 (test data collides with PLATFORM_DOMAINS) | Spec-only, change test domains |
| `spec/requests/api_manage/v1/cross_tenant_isolation_spec.rb` | 3 | #4 (2 stale tests + 1 test bug from `Website#slug` override) | 2 spec updates + 1 spec fix |

**Suggested priority**: investigate root cause #1 first and confirm/deny
whether it affects the deployed app — if it does, it's the most urgent item
in this list by far, independent of the test suite.
