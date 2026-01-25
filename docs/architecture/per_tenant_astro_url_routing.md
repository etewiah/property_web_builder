# Per-Tenant Astro Client URL Routing

**Last Updated**: 2026-01-25
**Status**: Implemented
**Related**: [Client Rendering Implementation Status](./client_rendering_implementation_status.md)

---

## Overview

This feature enables per-tenant routing to different Astro servers. Each tenant (website) can specify a custom Astro client URL in their configuration, allowing:

- Multi-region deployments with region-specific Astro servers
- Development/staging environments with isolated Astro instances
- A/B testing different Astro builds
- Enterprise tenants with dedicated Astro deployments

---

## How It Works

### Request Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         USER'S BROWSER                                   │
│   User visits: https://mysite.propertywebbuilder.com/properties         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         RAILS BACKEND                                    │
│                                                                          │
│   1. ClientProxyController receives request                              │
│   2. Calls astro_client_url method                                       │
│   3. Checks current_website.client_theme_config['astro_client_url']     │
│   4. If set → use tenant-specific URL                                   │
│   5. If not → fall back to ENV['ASTRO_CLIENT_URL']                      │
│   6. If not → fall back to http://localhost:4321                        │
│   7. Proxies request to determined URL                                  │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│   ASTRO CLIENT (Tenant-specific or default)                             │
│   https://tenant-astro.example.com  OR  http://localhost:4321           │
└─────────────────────────────────────────────────────────────────────────┘
```

### URL Resolution Priority

The `astro_client_url` method resolves URLs in this order:

1. **Per-tenant URL** from `client_theme_config['astro_client_url']` (highest priority)
2. **Environment variable** `ASTRO_CLIENT_URL`
3. **Default fallback** `http://localhost:4321` (lowest priority)

---

## Implementation Details

### Modified File

**`app/controllers/pwb/client_proxy_controller.rb`** (lines 72-80)

```ruby
# Get Astro client URL - per-tenant config takes precedence
def astro_client_url
  # Per-tenant URL from client_theme_config takes precedence
  tenant_url = current_website&.client_theme_config&.dig('astro_client_url')
  return tenant_url if tenant_url.present?

  # Fall back to environment variable or default
  ENV.fetch('ASTRO_CLIENT_URL', 'http://localhost:4321')
end
```

### Data Storage

The custom URL is stored in the `client_theme_config` JSONB column on `pwb_websites`:

```json
{
  "astro_client_url": "https://tenant-astro.example.com",
  "primary_color": "#FF6B35",
  "secondary_color": "#004E89"
}
```

This column already exists and is used for other theme configuration options, so no migration is needed.

---

## Usage

### Setting a Custom Astro URL

#### Via Rails Console

```ruby
# Find the website
website = Pwb::Website.find_by(subdomain: 'my-tenant')

# Set a custom Astro URL
website.update!(
  client_theme_config: website.client_theme_config.merge(
    'astro_client_url' => 'https://my-tenant-astro.example.com'
  )
)

# Verify
website.client_theme_config['astro_client_url']
# => "https://my-tenant-astro.example.com"
```

#### Via Admin API (if implemented)

```bash
curl -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_theme_config": {"astro_client_url": "https://my-tenant-astro.example.com"}}' \
  https://api.propertywebbuilder.com/tenant_admin/websites/123
```

### Removing a Custom Astro URL

```ruby
website = Pwb::Website.find_by(subdomain: 'my-tenant')

# Remove just the astro_client_url key
config = website.client_theme_config.except('astro_client_url')
website.update!(client_theme_config: config)

# Website will now fall back to ENV or default
```

### Verifying the Current URL

```ruby
# In Rails console, check what URL a website will use
website = Pwb::Website.find_by(subdomain: 'my-tenant')

# Direct check
website.client_theme_config['astro_client_url']

# To see the full resolution (including fallbacks), use the controller:
controller = Pwb::ClientProxyController.new
controller.instance_variable_set(:@current_website, website)
controller.send(:astro_client_url)
```

---

## Configuration Scenarios

### Scenario 1: Default Setup (No Custom URL)

**Configuration:**
```ruby
website.client_theme_config = { 'primary_color' => '#FF0000' }
# No astro_client_url key
```

**Result:** Uses `ENV['ASTRO_CLIENT_URL']` or defaults to `http://localhost:4321`

---

### Scenario 2: Tenant with Dedicated Astro Server

**Configuration:**
```ruby
website.client_theme_config = {
  'astro_client_url' => 'https://enterprise-client.example.com',
  'primary_color' => '#FF0000'
}
```

**Result:** All requests for this tenant proxy to `https://enterprise-client.example.com`

---

### Scenario 3: Regional Deployment

**Configuration:**

| Tenant Subdomain | Region | astro_client_url |
|------------------|--------|------------------|
| us-tenant | US | https://us-astro.example.com |
| eu-tenant | EU | https://eu-astro.example.com |
| apac-tenant | APAC | https://apac-astro.example.com |

**Result:** Each tenant's requests route to their regional Astro server

---

### Scenario 4: Staging/Development Testing

**Configuration:**
```ruby
# Production website uses default
prod_website.client_theme_config = {}

# Staging website uses staging Astro
staging_website.client_theme_config = {
  'astro_client_url' => 'https://staging-astro.example.com'
}
```

**Result:** Production uses the default Astro server; staging tests against a separate deployment

---

## Testing

### Automated Tests

Tests are located in `spec/controllers/pwb/client_proxy_controller_spec.rb`:

```bash
bundle exec rspec spec/controllers/pwb/client_proxy_controller_spec.rb
```

**Test cases:**

| Test | Description |
|------|-------------|
| `with tenant-specific URL in client_theme_config` | Verifies custom URL is used |
| `with empty astro_client_url in client_theme_config` | Verifies fallback when URL is blank |
| `without tenant-specific URL (empty config)` | Verifies fallback when config is empty |
| `with nil client_theme_config` | Verifies fallback when config is nil |

### Manual Testing

1. **Set up a test website:**
   ```ruby
   # In Rails console
   website = Pwb::Website.create!(
     subdomain: 'custom-astro-test',
     rendering_mode: 'client',
     client_theme_name: 'amsterdam',
     client_theme_config: {
       'astro_client_url' => 'https://httpbin.org'  # Echo service for testing
     }
   )
   ```

2. **Visit the website:**
   ```
   http://custom-astro-test.localhost:3000/test-path
   ```

3. **Check Rails logs:**
   Look for the proxied URL in the logs to confirm it's using the custom URL.

---

## Security Considerations

### Current State

The feature has no built-in URL validation. Any valid URL can be set.

### Recommendations

1. **Admin-only access:** Ensure only admins can modify `client_theme_config`
2. **HTTPS enforcement:** In production, consider validating that custom URLs use HTTPS
3. **Domain allowlist:** For high-security environments, maintain an allowlist of permitted Astro domains

### Optional URL Validation

Add to `app/models/pwb/website.rb` if stricter validation is needed:

```ruby
validate :validate_astro_client_url

private

def validate_astro_client_url
  url = client_theme_config&.dig('astro_client_url')
  return if url.blank?

  begin
    uri = URI.parse(url)

    # Must be HTTP or HTTPS
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:client_theme_config, 'astro_client_url must be a valid HTTP(S) URL')
      return
    end

    # In production, require HTTPS
    if Rails.env.production? && !uri.is_a?(URI::HTTPS)
      errors.add(:client_theme_config, 'astro_client_url must use HTTPS in production')
    end

    # Optional: Check against allowlist
    # allowed_hosts = %w[astro.example.com staging-astro.example.com]
    # unless allowed_hosts.include?(uri.host)
    #   errors.add(:client_theme_config, 'astro_client_url host not in allowlist')
    # end

  rescue URI::InvalidURIError
    errors.add(:client_theme_config, 'astro_client_url is not a valid URL')
  end
end
```

---

## Monitoring & Debugging

### Logging

The proxy controller logs errors when Astro is unavailable:

```ruby
Rails.logger.error "Astro proxy error: #{e.message}"
```

Consider adding logging for which URL is being used:

```ruby
def astro_client_url
  tenant_url = current_website&.client_theme_config&.dig('astro_client_url')

  if tenant_url.present?
    Rails.logger.debug "Using tenant-specific Astro URL: #{tenant_url}"
    return tenant_url
  end

  default_url = ENV.fetch('ASTRO_CLIENT_URL', 'http://localhost:4321')
  Rails.logger.debug "Using default Astro URL: #{default_url}"
  default_url
end
```

### Health Checks

For tenants with custom URLs, consider implementing health check monitoring:

```ruby
# Check if a tenant's Astro server is reachable
def astro_health_check(website)
  url = website.client_theme_config&.dig('astro_client_url') ||
        ENV.fetch('ASTRO_CLIENT_URL', 'http://localhost:4321')

  response = HTTP.timeout(5).get("#{url}/health")
  response.status.success?
rescue HTTP::Error, HTTP::TimeoutError
  false
end
```

---

## Troubleshooting

### Problem: Tenant getting default Astro instead of custom URL

**Possible causes:**
1. `astro_client_url` key is misspelled
2. URL value is blank/empty string
3. `client_theme_config` is nil

**Debug:**
```ruby
website = Pwb::Website.find_by(subdomain: 'tenant-name')
puts website.client_theme_config.inspect
puts website.client_theme_config&.dig('astro_client_url').inspect
```

### Problem: Custom Astro URL not responding

**Check:**
1. URL is accessible from the Rails server
2. No firewall blocking the connection
3. Astro server is running and healthy

**Test connectivity:**
```ruby
url = "https://custom-astro.example.com"
HTTP.timeout(5).get(url)
```

### Problem: SSL/Certificate errors

**Symptom:** `OpenSSL::SSL::SSLError` in logs

**Solutions:**
1. Ensure the Astro server has a valid SSL certificate
2. For self-signed certs in development, you may need to disable verification (not recommended for production)

---

## Related Documentation

- [Client Rendering Implementation Status](./client_rendering_implementation_status.md)
- [Astro Client Integration Guide](./astro_client_integration_guide.md)
- [URL Routing Quick Reference](./url_routing_quick_reference.md)
