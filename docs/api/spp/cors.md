# SPP CORS Configuration (Option B)

**Status:** Proposed
**Related:** [SPP–PWB Integration](./README.md) | [Authentication](./authentication.md)

---

## Summary

With Option B (independent deployment), SPP makes cross-origin requests directly from the browser to PWB's API. This document specifies the CORS configuration changes needed on PWB.

## Current State

PWB already uses `rack-cors` (v3.0) with configuration in `config/initializers/cors.rb`. Three allow blocks exist:

1. **Development origins** — `localhost:4200`, `localhost:4321`, `localhost:4322`
2. **Production origins** — `*.workers.dev`, `*.propertywebbuilder.com`, specific domains
3. **Widget API** — `origins '*'` scoped to `/api_public/v1/widgets/*` and `/widget/*`

All blocks use `headers: :any`, which already permits custom headers like `X-Website-Slug` and `X-API-Key`.

## What Needs to Change

### Development: Already Covered

`localhost:4322` is already in the development origins block. If SPP runs on a different port locally, add it to the same block.

### Production: Add Per-Tenant SPP Origins

SPP origins are tenant-specific — each tenant's SPP deployment has its own domain. There are two approaches:

#### Approach A: Regex Pattern (Recommended)

If SPP deployments follow a predictable domain pattern (e.g., `*.spp.example.com`), add a regex to the production origins block:

```ruby
# In config/initializers/cors.rb, add to the production block:
allow do
  origins 'pwb-astrojs-client.etewiah.workers.dev',
          'demo.propertywebbuilder.com',
          /.*\.workers\.dev/,
          /.*\.propertywebbuilder\.com/,
          /.*\.spp\.example\.com/          # <-- Add SPP pattern
  resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
end
```

This is the simplest approach and requires no runtime database lookups.

#### Approach B: Dynamic Origins from Database

If SPP domains are fully custom (e.g., `123-main-st.com`, `luxury-villa.io`), the allowed origins need to be resolved at runtime from `client_theme_config['spp_url']`.

`rack-cors` supports a proc for origins:

```ruby
allow do
  origins do |source, env|
    # Check against known patterns first (fast path)
    next true if source.match?(/\.(workers\.dev|propertywebbuilder\.com)\z/)

    # Check against per-tenant SPP URLs (database lookup, cached)
    spp_origins = Rails.cache.fetch('spp_allowed_origins', expires_in: 5.minutes) do
      Pwb::Website.where("client_theme_config->>'spp_url' IS NOT NULL")
                  .pluck(Arel.sql("client_theme_config->>'spp_url'"))
                  .map { |url| URI.parse(url).host rescue nil }
                  .compact
    end

    spp_origins.include?(URI.parse(source).host rescue nil)
  end

  resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
end
```

**Trade-offs:**

| Concern | Approach A (Regex) | Approach B (Dynamic) |
|---------|-------------------|---------------------|
| Setup complexity | Trivial | Moderate |
| Custom domains | Not supported | Fully supported |
| Performance | No DB lookup | Cached DB lookup (5-min TTL) |
| Security | Allows all matching domains | Only allows configured domains |

**Recommendation:** Start with Approach A. Move to Approach B only if tenants need fully custom SPP domains.

### Scoping: Which Resources?

SPP needs CORS on two API namespaces:

- **`/api_public/v1/*`** — Property data, enquiry submissions (public, no auth)
- **`/api_manage/v1/*`** — Publish, unpublish, leads (authenticated)

The existing production origins block already uses `resource '*'` which covers both namespaces. No additional resource scoping is needed.

### Required Headers

SPP sends these headers on cross-origin requests:

| Header | Purpose | Already Allowed? |
|--------|---------|-----------------|
| `X-Website-Slug` | Tenant resolution | Yes (`headers: :any`) |
| `X-API-Key` | Authentication for api_manage | Yes (`headers: :any`) |
| `Content-Type` | JSON request bodies | Yes (`headers: :any`) |
| `Accept` | Response format | Yes (simple header) |

No changes needed — `headers: :any` covers all custom headers.

### Preflight Caching

The existing configuration does not set `max_age` on the production block. Adding it reduces preflight requests:

```ruby
resource '*',
  headers: :any,
  methods: [:get, :post, :put, :patch, :delete, :options, :head],
  max_age: 3600   # Cache preflight for 1 hour
```

## Credentials and Cookies

SPP uses API key authentication (not cookies), so `credentials: true` is **not needed**. This simplifies CORS — no need for `Access-Control-Allow-Credentials`.

## Implementation Checklist

1. Decide on Approach A or B based on whether tenants will have custom SPP domains
2. Update `config/initializers/cors.rb` with the chosen approach
3. Add `max_age: 3600` to the production origins block
4. Test preflight (`OPTIONS`) requests from an SPP origin to both `/api_public/v1/*` and `/api_manage/v1/*`
5. Verify `X-Website-Slug` and `X-API-Key` headers pass through

## Reference Files

| File | Relevance |
|------|-----------|
| `config/initializers/cors.rb` | CORS configuration (modify this) |
| `Gemfile:180` | `rack-cors` gem declaration |
| `app/controllers/api_public/v1/base_controller.rb` | Public API base (no CORS headers set — rack-cors handles it) |
| `app/controllers/api_manage/v1/base_controller.rb` | Manage API base (no CORS headers set — rack-cors handles it) |
