# SPP Authentication for api_manage Endpoints

**Status:** Implemented
**Related:** [SPP–PWB Integration](./README.md) | [CORS](./cors.md)

---

## Summary

SPP needs authenticated access to PWB's `api_manage` namespace for publish, unpublish, and leads endpoints. This document specifies how SPP authenticates using PWB's existing API key infrastructure.

## Current Authentication in api_manage

`ApiManage::V1::BaseController` (`app/controllers/api_manage/v1/base_controller.rb`) resolves `current_user` by trying three methods in order:

1. **Session-based (Devise)** — For same-origin requests from logged-in browser users
2. **API Key (`X-API-Key` header)** — For external integrations
3. **User Email header (`X-User-Email`)** — Development/test only

For Option B (SPP as an independent deployment), **API Key authentication is the correct choice**. Session-based auth doesn't work cross-origin, and email header auth is disabled in production.

## How API Key Auth Works

### The Integration Model

API keys are managed through `Pwb::WebsiteIntegration` (`app/models/pwb/website_integration.rb`). Each integration record has:

- `website_id` — Tenant scope
- `category` — Integration type (e.g., `:ai`, `:crm`)
- `provider` — Provider name
- `credentials` — Encrypted credential storage (includes `api_key`)
- `settings` — JSONB configuration
- `enabled` — Active toggle
- Unique constraint: one provider per category per website

### Authentication Flow

When SPP sends `X-API-Key: <key>`:

```
Request with X-API-Key header
  │
  ▼
api_manage BaseController#authenticate_from_api_key
  │
  ├── Iterate: current_website.integrations.enabled.find { |i| i.credential('api_key') == key }
  │   (API keys are stored in encrypted credentials, so each must be decrypted and compared)
  │
  ├── If found: Call integration.record_usage!, return website's owner or first admin
  │
  └── If not found: Return nil (authentication fails)
```

The acting user has the permissions of the website's owner/admin, which covers all publish/unpublish/leads operations.

## Setup: Creating an SPP Integration

### New Integration Category

Add an `:spp` category to represent the SPP integration. This is cleaner than reusing an existing category and makes it easy to identify SPP-specific API keys.

In `app/models/pwb/website_integration.rb`, add `:spp` to the categories enum if not already a general-purpose field. If categories are free-form strings, use `"spp"`.

### Provisioning the API Key

Use the provisioning rake task:

```bash
rails spp:provision[my-subdomain]
```

This is idempotent — running it again for the same subdomain outputs the existing key. The task:
1. Finds the website by subdomain
2. Creates a `WebsiteIntegration` (category: `spp`, provider: `single_property_pages`) with an encrypted API key
3. Outputs the API key and environment variables for SPP

Alternatively, via Rails console:

```ruby
website = Pwb::Website.find_by(subdomain: 'my-tenant')

integration = website.integrations.create!(
  category: 'spp',
  provider: 'single_property_pages',
  credentials: { 'api_key' => SecureRandom.hex(32) },
  settings: {},
  enabled: true
)

integration.credential('api_key')
# => "a1b2c3d4e5f6..."
```

### Configuring SPP

SPP stores the API key in its environment configuration per tenant:

```bash
# In SPP's .env or deployment config:
PWB_API_KEY=a1b2c3d4e5f6...
PWB_API_URL=https://api.propertywebbuilder.com
PWB_WEBSITE_SLUG=my-tenant
```

SPP's Astro API routes include these headers on every request to PWB:

```typescript
// In SPP's proxy/fetch layer:
const headers = {
  'X-API-Key': process.env.PWB_API_KEY,
  'X-Website-Slug': process.env.PWB_WEBSITE_SLUG,
  'Content-Type': 'application/json',
};
```

## Request Flow

```
SPP Astro Server
  │
  │  POST /api_manage/v1/en/properties/:id/publish
  │  Headers:
  │    X-API-Key: a1b2c3d4e5f6...
  │    X-Website-Slug: my-tenant
  │    Content-Type: application/json
  │
  ▼
PWB Rails
  │
  ├── SubdomainTenant: Resolves website from X-Website-Slug
  ├── require_website!: Confirms website context exists
  ├── authenticate_from_api_key: Validates key against WebsiteIntegration
  ├── current_user: Returns website owner/admin
  │
  ▼
  Endpoint logic executes with full authorization
```

## Important: Server-Side Only

The API key is used **only in SPP's server-side Astro API routes**, never in client-side JavaScript. The browser never sees the key:

```
Browser ──POST /api/properties/:id/publish──▶ SPP Astro Server
                                                │
                                                │ (adds X-API-Key, X-Website-Slug)
                                                │
                                                ▼
                                              PWB Rails
```

This means:
- The API key is not exposed in browser network requests
- CORS preflight requests don't include `X-API-Key` (the browser never makes direct requests to `api_manage`)
- Only `api_public` endpoints (enquiries) are called directly from the browser

Wait — this changes the CORS picture for `api_manage`:

### Clarification: api_manage Is Server-to-Server

Since SPP's Astro server (not the browser) calls `api_manage` endpoints, **CORS is not needed for api_manage**. CORS only applies to browser-initiated cross-origin requests.

CORS is only needed for `api_public` (specifically the enquiry endpoint), which the browser calls directly. See [CORS Configuration](./cors.md).

## Security Considerations

### Key Rotation

API keys should be rotatable without downtime:

1. Generate a new key on the integration
2. Update SPP's environment with the new key
3. Both keys work during the transition (if the integration model supports multiple active keys; if not, coordinate the switchover)

### Key Scope

The API key grants the permissions of the website's owner/admin. This is appropriate for SPP because publish/unpublish/leads are admin-level operations. However, if finer-grained permissions are needed later, PWB could add a `permissions` field to the integration settings.

### Audit Trail

The `api_manage` base controller calls `integration.record_usage!` on successful API key authentication, which updates `last_used_at` on the `WebsiteIntegration` record. This is already implemented.

## Enquiry Submissions: No Auth Needed

The enquiry endpoint (`POST /api_public/v1/enquiries`) is under `api_public`, which has **no authentication requirement**. This is correct — enquiries are submitted by anonymous visitors. SPP's client-side form can POST directly to PWB with just `X-Website-Slug` (no API key).

## Implementation Checklist

- [x] `authenticate_from_api_key` iterates encrypted `WebsiteIntegration` credentials
- [x] `:spp` category added to `WebsiteIntegration::CATEGORIES`
- [x] Provisioning rake task: `rails spp:provision[subdomain]`
- [x] API key auth returns 401 without valid key, 200 with one (6 specs)
- [x] `record_usage!` updates `last_used_at` on authentication
- [x] Cross-website key isolation tested

## Reference Files

| File | Relevance |
|------|-----------|
| `app/controllers/api_manage/v1/base_controller.rb` | Authentication methods |
| `app/models/pwb/website_integration.rb` | Integration model with API key storage |
| `app/controllers/concerns/subdomain_tenant.rb` | Tenant resolution from `X-Website-Slug` |
| `app/controllers/api_public/v1/base_controller.rb` | Public API (no auth, used for enquiries) |
