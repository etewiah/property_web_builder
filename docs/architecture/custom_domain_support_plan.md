# Custom Domain Support Plan

## Overview

This document outlines the plan to support tenant deployments to custom domains in addition to the existing subdomain-based routing.

### Current State

- Tenants are identified by **subdomain only** (e.g., `tenant-a.propertywebbuilder.com`)
- Lookup happens in `SubdomainTenant` concern via `Pwb::Website.find_by_subdomain()`
- Database has `subdomain` column but no `custom_domain` column

### Target State

- Support **both** subdomain routing AND custom domain routing
- Examples:
  - `tenant-a.propertywebbuilder.com` (subdomain - existing)
  - `www.myrealestate.com` (custom domain - new)
  - `myrealestate.com` (apex domain - new)

---

## Implementation Plan

### Phase 1: Database Schema Changes

#### 1.1 Migration: Add custom_domain column

```ruby
# db/migrate/XXXXXX_add_custom_domain_to_websites.rb
class AddCustomDomainToWebsites < ActiveRecord::Migration[7.0]
  def change
    add_column :pwb_websites, :custom_domain, :string
    add_column :pwb_websites, :custom_domain_verified, :boolean, default: false
    add_column :pwb_websites, :custom_domain_verified_at, :datetime
    add_column :pwb_websites, :custom_domain_verification_token, :string

    add_index :pwb_websites, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
  end
end
```

#### 1.2 Schema Result

```
pwb_websites
├── subdomain (existing) - e.g., "tenant-a"
├── custom_domain (new) - e.g., "www.myrealestate.com" or "myrealestate.com"
├── custom_domain_verified (new) - boolean
├── custom_domain_verified_at (new) - datetime
└── custom_domain_verification_token (new) - for DNS verification
```

---

### Phase 2: Model Changes

#### 2.1 Update `Pwb::Website` model

```ruby
# app/models/pwb/website.rb

class Website < ApplicationRecord
  # Existing subdomain validations...

  # New custom domain validations
  validates :custom_domain,
            uniqueness: { case_sensitive: false, allow_blank: true },
            format: {
              with: /\A([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,}\z/i,
              message: "must be a valid domain name",
              allow_blank: true
            }

  validate :custom_domain_not_platform_domain

  # Find by custom domain (case-insensitive, handles www prefix)
  def self.find_by_custom_domain(domain)
    return nil if domain.blank?

    normalized = normalize_domain(domain)
    where("LOWER(custom_domain) = ?", normalized.downcase).first
  end

  # Find by either subdomain or custom domain
  def self.find_by_host(host)
    return nil if host.blank?

    # First try custom domain (exact match or with/without www)
    website = find_by_custom_domain(host)
    return website if website

    # Try without www if present
    if host.start_with?('www.')
      website = find_by_custom_domain(host.sub(/\Awww\./, ''))
      return website if website
    end

    # Fall back to subdomain lookup (extract first part)
    subdomain = extract_subdomain(host)
    find_by_subdomain(subdomain)
  end

  def self.normalize_domain(domain)
    domain.to_s.downcase.strip.sub(/\Awww\./, '')
  end

  def self.extract_subdomain(host)
    # For platform domains like tenant.example.com, extract "tenant"
    parts = host.split('.')
    return nil if parts.length < 3
    parts.first
  end

  # Generate DNS verification token
  def generate_domain_verification_token!
    self.custom_domain_verification_token = SecureRandom.hex(16)
    save!
  end

  # Check if domain is verified via DNS TXT record
  def verify_custom_domain!
    return false if custom_domain.blank? || custom_domain_verification_token.blank?

    begin
      resolver = Resolv::DNS.new
      txt_records = resolver.getresources(
        "_pwb-verification.#{custom_domain}",
        Resolv::DNS::Resource::IN::TXT
      )

      verified = txt_records.any? { |r| r.strings.join == custom_domain_verification_token }

      if verified
        update!(
          custom_domain_verified: true,
          custom_domain_verified_at: Time.current
        )
      end

      verified
    rescue Resolv::ResolvError
      false
    end
  end

  private

  def custom_domain_not_platform_domain
    return if custom_domain.blank?

    platform_domains = ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost').split(',')

    platform_domains.each do |pd|
      if custom_domain.end_with?(pd)
        errors.add(:custom_domain, "cannot be a platform domain")
      end
    end
  end
end
```

---

### Phase 3: Routing Changes

#### 3.1 Update `SubdomainTenant` concern

```ruby
# app/controllers/concerns/subdomain_tenant.rb

module SubdomainTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_website_from_request
  end

  private

  # Resolves the current website based on the request.
  # Priority:
  # 1. X-Website-Slug header (for API/GraphQL requests)
  # 2. Custom domain match (full host)
  # 3. Subdomain match (for platform domains)
  # 4. Fallback to default website
  def set_current_website_from_request
    # First check for explicit header (useful for API clients)
    slug = request.headers["X-Website-Slug"]
    if slug.present?
      Pwb::Current.website = Pwb::Website.find_by(slug: slug)
      return if Pwb::Current.website.present?
    end

    # Try to find by host (handles both custom domains and subdomains)
    host = request.host.to_s.downcase

    if custom_domain_request?(host)
      # Custom domain lookup
      Pwb::Current.website = Pwb::Website.find_by_custom_domain(host)
    elsif platform_subdomain_request?(host)
      # Platform subdomain lookup
      subdomain = extract_tenant_subdomain(host)
      Pwb::Current.website = Pwb::Website.find_by_subdomain(subdomain) if subdomain.present?
    end

    # Fallback to default if not found
    Pwb::Current.website ||= Pwb::Website.first
  end

  # Check if this is a custom domain request (not a platform domain)
  def custom_domain_request?(host)
    platform_domains = ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost').split(',')
    !platform_domains.any? { |pd| host.end_with?(pd) }
  end

  # Check if this is a platform subdomain request
  def platform_subdomain_request?(host)
    platform_domains = ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost').split(',')
    platform_domains.any? { |pd| host.end_with?(pd) } && host.split('.').length > pd.split('.').length
  end

  # Extract tenant subdomain from platform domain
  def extract_tenant_subdomain(host)
    subdomain = request.subdomain

    # Ignore common non-tenant subdomains
    return nil if subdomain.blank?
    return nil if %w[www api admin].include?(subdomain)

    # For multi-level subdomains, take the first part
    subdomain.split(".").first
  end

  def current_website
    Pwb::Current.website
  end
end
```

---

### Phase 4: Configuration

#### 4.1 Environment Variables

```bash
# .env or environment config

# Comma-separated list of platform domains (subdomains route to tenants)
PLATFORM_DOMAINS=propertywebbuilder.com,staging.propertywebbuilder.com,pwb.localhost

# Optional: Default website slug if no match found
DEFAULT_WEBSITE_SLUG=demo
```

#### 4.2 Rails Configuration

```ruby
# config/initializers/tenant_domains.rb

Rails.application.config.tenant_domains = {
  # Platform domains where subdomains = tenants
  platform_domains: ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com').split(','),

  # Whether to allow unverified custom domains (dev only)
  allow_unverified_domains: Rails.env.development?,

  # DNS verification prefix
  verification_prefix: '_pwb-verification'
}
```

---

### Phase 5: Admin UI for Domain Management

#### 5.1 Add domain management to Site Admin

```ruby
# app/controllers/site_admin/domains_controller.rb

module SiteAdmin
  class DomainsController < SiteAdminController
    def show
      @website = current_website
    end

    def update
      @website = current_website

      if @website.update(domain_params)
        @website.generate_domain_verification_token! if @website.custom_domain_changed?
        redirect_to site_admin_domain_path, notice: 'Domain settings updated'
      else
        render :show
      end
    end

    def verify
      @website = current_website

      if @website.verify_custom_domain!
        redirect_to site_admin_domain_path, notice: 'Domain verified successfully!'
      else
        redirect_to site_admin_domain_path, alert: 'Domain verification failed. Please check your DNS settings.'
      end
    end

    private

    def domain_params
      params.require(:website).permit(:custom_domain)
    end
  end
end
```

#### 5.2 Domain Management View

```erb
<%# app/views/site_admin/domains/show.html.erb %>

<h1>Domain Settings</h1>

<div class="card">
  <h2>Current Domain Configuration</h2>

  <p><strong>Subdomain:</strong> <%= @website.subdomain %>.propertywebbuilder.com</p>

  <% if @website.custom_domain.present? %>
    <p>
      <strong>Custom Domain:</strong> <%= @website.custom_domain %>
      <% if @website.custom_domain_verified? %>
        <span class="badge badge-success">Verified</span>
      <% else %>
        <span class="badge badge-warning">Pending Verification</span>
      <% end %>
    </p>
  <% end %>
</div>

<div class="card">
  <h2>Add/Update Custom Domain</h2>

  <%= form_with model: @website, url: site_admin_domain_path, method: :patch do |f| %>
    <div class="form-group">
      <%= f.label :custom_domain, 'Custom Domain' %>
      <%= f.text_field :custom_domain, placeholder: 'www.yourdomain.com', class: 'form-control' %>
      <small>Enter your domain without http:// or https://</small>
    </div>

    <%= f.submit 'Save Domain', class: 'btn btn-primary' %>
  <% end %>
</div>

<% if @website.custom_domain.present? && !@website.custom_domain_verified? %>
  <div class="card">
    <h2>Domain Verification</h2>

    <p>To verify ownership of your domain, add the following DNS TXT record:</p>

    <table class="table">
      <tr>
        <th>Type</th>
        <td>TXT</td>
      </tr>
      <tr>
        <th>Host/Name</th>
        <td><code>_pwb-verification.<%= @website.custom_domain %></code></td>
      </tr>
      <tr>
        <th>Value</th>
        <td><code><%= @website.custom_domain_verification_token %></code></td>
      </tr>
    </table>

    <p>After adding the DNS record, click the button below to verify:</p>

    <%= button_to 'Verify Domain', verify_site_admin_domain_path, method: :post, class: 'btn btn-success' %>

    <p class="text-muted">Note: DNS changes can take up to 48 hours to propagate.</p>
  </div>
<% end %>

<div class="card">
  <h2>DNS Configuration for Custom Domain</h2>

  <p>Point your custom domain to our servers using one of these methods:</p>

  <h3>Option 1: CNAME Record (Recommended for www subdomain)</h3>
  <table class="table">
    <tr>
      <th>Type</th>
      <td>CNAME</td>
    </tr>
    <tr>
      <th>Host/Name</th>
      <td>www</td>
    </tr>
    <tr>
      <th>Value/Points to</th>
      <td><code><%= @website.subdomain %>.propertywebbuilder.com</code></td>
    </tr>
  </table>

  <h3>Option 2: A Record (For apex domain)</h3>
  <table class="table">
    <tr>
      <th>Type</th>
      <td>A</td>
    </tr>
    <tr>
      <th>Host/Name</th>
      <td>@</td>
    </tr>
    <tr>
      <th>Value/Points to</th>
      <td><code><%= ENV['PLATFORM_IP'] || '(Contact support for IP address)' %></code></td>
    </tr>
  </table>
</div>
```

---

### Phase 6: SSL/TLS Certificate Handling

#### 6.1 Options for SSL

**Option A: Cloudflare Proxy (Recommended)**
- Tenant points CNAME to platform
- Cloudflare provides SSL for all domains
- Zero-config for tenants

**Option B: Reverse Proxy with On-Demand TLS**
- Auto-provision certificates per domain using `/tls/check` endpoint
- Requires wildcard cert OR per-domain certs
- Works with Caddy, Traefik, or other modern proxies

**Option C: AWS Certificate Manager + CloudFront**
- ACM for free certificates
- CloudFront as CDN with custom domain support

#### 6.2 On-Demand TLS Configuration

PropertyWebBuilder provides a TLS verification endpoint at `/tls/check` for on-demand certificate issuance:

```
GET /tls/check?domain=example.com

Returns:
- 200 OK: Proceed with certificate issuance
- 403 Forbidden: Domain suspended/terminated
- 404 Not Found: Domain not registered
```

Configure your reverse proxy to query this endpoint before issuing certificates.

#### 6.3 nginx + certbot Configuration

```nginx
# /etc/nginx/sites-available/pwb

# Platform domains
server {
    listen 443 ssl http2;
    server_name *.propertywebbuilder.com;

    ssl_certificate /etc/letsencrypt/live/propertywebbuilder.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/propertywebbuilder.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Custom domains - certificates managed by certbot
server {
    listen 443 ssl http2;
    server_name ~^(?<domain>.+)$;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

### Phase 7: Routes Update

```ruby
# config/routes.rb

# Add domain management routes to site_admin
namespace :site_admin do
  resource :domain, only: [:show, :update] do
    post :verify
  end
end
```

---

## Request Flow Diagrams

### Subdomain Request Flow
```
Request: tenant-a.propertywebbuilder.com
    │
    ▼
SubdomainTenant#set_current_website_from_request
    │
    ├── platform_subdomain_request?("tenant-a.propertywebbuilder.com") → true
    │
    ▼
extract_tenant_subdomain → "tenant-a"
    │
    ▼
Website.find_by_subdomain("tenant-a")
    │
    ▼
Pwb::Current.website = <Website id=1>
```

### Custom Domain Request Flow
```
Request: www.myrealestate.com
    │
    ▼
SubdomainTenant#set_current_website_from_request
    │
    ├── custom_domain_request?("www.myrealestate.com") → true
    │
    ▼
Website.find_by_custom_domain("www.myrealestate.com")
    │
    ├── normalize_domain → "myrealestate.com"
    │
    ▼
SELECT * FROM pwb_websites WHERE LOWER(custom_domain) = 'myrealestate.com'
    │
    ▼
Pwb::Current.website = <Website id=5>
```

---

## Implementation Checklist

### Database
- [ ] Create migration for `custom_domain` columns
- [ ] Run migration on all environments
- [ ] Add unique index on `custom_domain`

### Models
- [ ] Add validations to `Website` model
- [ ] Add `find_by_custom_domain` method
- [ ] Add `find_by_host` method
- [ ] Add domain verification methods

### Controllers
- [ ] Update `SubdomainTenant` concern
- [ ] Create `SiteAdmin::DomainsController`
- [ ] Add routes

### Views
- [ ] Domain management UI in site admin
- [ ] DNS instruction display
- [ ] Verification status badges

### Infrastructure
- [ ] Configure SSL solution (Cloudflare/reverse proxy/nginx)
- [ ] Set `PLATFORM_DOMAINS` environment variable
- [ ] Document DNS setup for tenants

### Testing
- [ ] Unit tests for domain lookup methods
- [ ] Integration tests for routing
- [ ] Test both subdomain and custom domain paths

---

## Security Considerations

1. **Domain Verification**: Require DNS TXT verification before activating custom domains to prevent domain hijacking.

2. **SSL/TLS**: Ensure all custom domains have valid SSL certificates.

3. **Rate Limiting**: Limit domain verification attempts to prevent abuse.

4. **Reserved Domains**: Block platform domains from being added as custom domains.

5. **Subdomain Takeover**: Keep subdomain validation to prevent conflicts.

---

## Migration Path

### For Existing Tenants
1. Existing subdomain routing continues to work unchanged
2. Custom domain is optional and additive
3. Both can work simultaneously (subdomain as fallback)

### For New Tenants
1. Subdomain assigned automatically on creation
2. Custom domain can be added later via admin UI

---

## Estimated Effort

| Phase | Effort | Priority |
|-------|--------|----------|
| Phase 1: Database | 1 hour | High |
| Phase 2: Model | 2-3 hours | High |
| Phase 3: Routing | 2 hours | High |
| Phase 4: Config | 30 min | High |
| Phase 5: Admin UI | 3-4 hours | Medium |
| Phase 6: SSL | 2-4 hours | High |
| Phase 7: Routes | 30 min | High |
| Testing | 2-3 hours | High |

**Total: ~15-20 hours**
