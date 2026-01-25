# Client Proxy Controller

The `ClientProxyController` handles proxying requests from Rails to an Astro.js client application for websites using client-side rendering (A themes).

## Overview

PropertyWebBuilder supports two rendering modes:

1. **Rails Mode (B Themes)** - Traditional server-side rendering with Liquid templates
2. **Client Mode (A Themes)** - Modern client-side rendering with Astro.js

When a website is configured for client rendering, requests are proxied through Rails to the Astro client server. This maintains authentication, tenant context, and allows for a unified domain experience.

## Architecture

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Browser   │ ──▶ │  Rails Server   │ ──▶ │  Astro Client    │
│             │     │  (Proxy Layer)  │     │  (CDN/Workers)   │
└─────────────┘     └─────────────────┘     └──────────────────┘
                           │
                    ┌──────┴──────┐
                    │ - Auth      │
                    │ - Tenant    │
                    │ - Headers   │
                    └─────────────┘
```

## Configuration

### Per-Tenant Astro URL

Each tenant can configure a custom Astro client URL via `client_theme_config`:

```ruby
website.client_theme_config = {
  'astro_client_url' => 'https://tenant-astro.example.com'
}
```

This allows different tenants to use different Astro deployments (e.g., Cloudflare Workers, Vercel, etc.).

### Environment Variable Fallback

If no tenant-specific URL is configured, the controller falls back to:

```bash
ASTRO_CLIENT_URL=http://localhost:4321  # Default for development
```

### URL Priority

1. `website.client_theme_config['astro_client_url']` (if present and non-blank)
2. `ENV['ASTRO_CLIENT_URL']`
3. `http://localhost:4321` (hardcoded default)

## Headers

### Forwarded Headers (All Requests)

| Header | Description |
|--------|-------------|
| `X-Forwarded-Host` | Original request host |
| `X-Forwarded-Proto` | Original protocol (http/https) |
| `X-Forwarded-For` | Client IP address |
| `X-Website-Slug` | Tenant subdomain |
| `X-Website-Id` | Tenant database ID |
| `X-Rendering-Mode` | Always "client" |
| `X-Client-Theme` | Active client theme name |
| `Accept` | Original accept header |
| `Accept-Language` | Original language preference |
| `Content-Type` | Request content type |

### Authentication Headers (Admin Routes Only)

| Header | Description |
|--------|-------------|
| `X-User-Id` | Current user's ID |
| `X-User-Email` | Current user's email |
| `X-User-Role` | User's role for this website |
| `X-Auth-Token` | Short-lived JWT token |

## SSL Handling

### The Problem

Some CDN providers (notably Cloudflare Workers) use SSL certificates that don't include CRL (Certificate Revocation List) distribution points. Ruby's OpenSSL by default attempts CRL verification, which fails with:

```
certificate verify failed (unable to get certificate CRL)
```

### The Solution

The controller uses a relaxed SSL context that:
- Still verifies peer certificates (VERIFY_PEER)
- Skips CRL checking via `V_FLAG_NO_CHECK_TIME`
- Uses system default certificate store

```ruby
def relaxed_ssl_context
  ctx = OpenSSL::SSL::SSLContext.new
  ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
  ctx.cert_store = OpenSSL::X509::Store.new.tap do |store|
    store.set_default_paths
    store.flags = OpenSSL::X509::V_FLAG_NO_CHECK_TIME
  end
  ctx
end
```

This is only applied for HTTPS URLs.

### Security Considerations

- Peer certificate verification is still enabled
- The certificate chain is still validated against system CA certificates
- Only CRL checking is disabled, not OCSP
- This is a common pattern for CDN/edge deployments

## URL Building

### Avoiding Double Slashes

The base URL is normalized to prevent double slashes:

```ruby
def build_astro_url(path)
  base_url = astro_client_url.chomp('/')
  "#{base_url}#{path}"
end
```

This handles cases where the configured URL has a trailing slash (e.g., `https://example.com/`) and the path starts with a slash (e.g., `/page`).

Without this normalization, the resulting URL would be `https://example.com//page`, which causes redirect loops on many servers.

## Error Handling

### Connection Errors

If the Astro client is unavailable:

- HTML requests: Render `pwb/errors/proxy_unavailable` view
- JSON requests: Return `{ error: 'Client application unavailable' }` with 503 status

### SSL Errors

SSL errors are caught and treated the same as connection errors.

## Routes

```ruby
# Public pages (no auth required)
get '*path', to: 'client_proxy#public_proxy', constraints: ClientRenderingConstraint.new

# Admin pages (auth required)
get 'admin/*path', to: 'client_proxy#admin_proxy', constraints: ClientRenderingConstraint.new
```

## Testing

See `spec/controllers/pwb/client_proxy_controller_spec.rb` for comprehensive tests covering:

- Routing constraints (rails vs client mode)
- Proxy functionality
- Authentication requirements
- Tenant-specific URLs
- JWT token generation
- URL building (double slash prevention)
- SSL context configuration
- Error handling

## Related Files

- `app/controllers/pwb/client_proxy_controller.rb` - Main controller
- `app/views/pwb/errors/proxy_unavailable.html.erb` - Error page
- `config/routes.rb` - Route definitions
- `app/models/pwb/website.rb` - `client_rendering?` method
