# Custom Domain SSL/TLS Setup Guide

This guide explains how to configure SSL certificates for custom domains in PropertyWebBuilder.

## Overview

When tenants use custom domains (e.g., `www.myrealestate.com`), they need valid SSL certificates. There are several approaches depending on your infrastructure.

## Option 1: Cloudflare Proxy (Recommended)

The simplest approach is to use Cloudflare as a proxy. Cloudflare provides:
- Free SSL certificates for all domains
- DDoS protection
- CDN/caching
- Easy setup

### Setup Steps

1. **Tenant adds their domain to Cloudflare** (free account works)
2. **Configure DNS in Cloudflare**:
   ```
   Type: CNAME
   Name: www (or @)
   Target: tenant-subdomain.propertywebbuilder.com
   Proxy: ON (orange cloud)
   ```
3. **SSL/TLS Settings in Cloudflare**:
   - Go to SSL/TLS > Overview
   - Set mode to "Full" (not "Full (strict)" unless you have a valid origin cert)

### Benefits
- Zero configuration on your server
- Automatic certificate renewal
- Works with any hosting provider

---

## Option 2: Reverse Proxy with On-Demand TLS

Modern reverse proxies (Caddy, Traefik, etc.) can automatically obtain and renew Let's Encrypt certificates on-demand.

### TLS Verification Endpoint

PropertyWebBuilder provides a built-in TLS verification endpoint at `/tls/check` that reverse proxies can query before issuing certificates:

```
GET /tls/check?domain=example.com

Returns:
- 200 OK: Domain is valid, proceed with certificate
- 403 Forbidden: Domain exists but is suspended/terminated
- 404 Not Found: Domain not registered in the system
```

### Configuration for On-Demand TLS

Configure your reverse proxy to query the verification endpoint before issuing certificates. Example for a generic reverse proxy:

```
on_demand_tls:
  ask: https://yourapp.com/tls/check
  interval: 5m
  burst: 10
```

### Security

You can secure the endpoint with a shared secret:

```bash
# Set environment variable
TLS_CHECK_SECRET=your-secret-token
```

Then configure your reverse proxy to send the secret:
- As header: `X-TLS-Secret: your-secret-token`
- Or as query param: `/tls/check?domain=example.com&secret=your-secret-token`

### Benefits
- Fully automatic SSL
- No manual certificate management
- Built-in HTTP/2 and HTTP/3

---

## Option 3: nginx + Let's Encrypt (certbot)

Traditional approach using nginx as reverse proxy with certbot for certificates.

### nginx Configuration

```nginx
# /etc/nginx/sites-available/pwb

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name *.propertywebbuilder.com;
    return 301 https://$host$request_uri;
}

# Platform wildcard domain
server {
    listen 443 ssl http2;
    server_name *.propertywebbuilder.com;

    ssl_certificate /etc/letsencrypt/live/propertywebbuilder.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/propertywebbuilder.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Custom domains - each needs its own certificate
# This is managed by certbot hooks
server {
    listen 443 ssl http2;
    server_name ~^(?<domain>.+)$;

    # Certificate path is determined dynamically
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Automated Certificate Provisioning

Create a script to provision certificates when domains are verified:

```bash
#!/bin/bash
# /usr/local/bin/provision_ssl.sh

DOMAIN=$1

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "Certificate already exists for $DOMAIN"
    exit 0
fi

# Obtain certificate
certbot certonly \
    --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    --email admin@propertywebbuilder.com

# Reload nginx
systemctl reload nginx
```

Call this from Rails when a domain is verified:

```ruby
# In Website model or a background job
def provision_ssl_certificate
  return unless custom_domain_verified?
  system("/usr/local/bin/provision_ssl.sh", custom_domain)
end
```

---

## Option 4: AWS CloudFront + ACM

For AWS-hosted deployments.

### Setup Steps

1. **Request Certificate in ACM**
   - Use DNS validation
   - Request certificates for custom domains as they're added

2. **Create CloudFront Distribution**
   - Origin: Your ALB or EC2 instance
   - Alternate domain names: Add custom domains
   - SSL Certificate: Select from ACM

3. **Automate with AWS SDK**

```ruby
# lib/aws_ssl_manager.rb
require 'aws-sdk-acm'
require 'aws-sdk-cloudfront'

class AwsSslManager
  def initialize
    @acm = Aws::ACM::Client.new
    @cloudfront = Aws::CloudFront::Client.new
  end

  def request_certificate(domain)
    @acm.request_certificate(
      domain_name: domain,
      validation_method: 'DNS',
      subject_alternative_names: ["www.#{domain}"]
    )
  end

  def add_domain_to_distribution(distribution_id, domain, certificate_arn)
    # Update CloudFront distribution with new domain
    # ... AWS API calls
  end
end
```

---

## Environment Variables

Add these to your production environment:

```bash
# Platform domains for subdomain routing
PLATFORM_DOMAINS=propertywebbuilder.com

# Server IP for A record instructions (apex domains)
PLATFORM_IP=123.45.67.89

# SSL provisioning method (cloudflare, reverse_proxy, nginx, aws)
SSL_PROVIDER=cloudflare

# For AWS
AWS_CLOUDFRONT_DISTRIBUTION_ID=EXAMPLEID
AWS_ACM_REGION=us-east-1
```

---

## DNS Instructions for Tenants

When tenants configure custom domains, they need to:

### For www subdomain (CNAME)
```
Type: CNAME
Name: www
Value: [subdomain].propertywebbuilder.com
```

### For apex domain (A record)
```
Type: A
Name: @
Value: [PLATFORM_IP]
```

### For verification (TXT record)
```
Type: TXT
Name: _pwb-verification
Value: [verification_token]
```

---

## Troubleshooting

### Certificate not issuing
1. Check DNS propagation: `dig +short CNAME www.customdomain.com`
2. Verify domain ownership TXT record exists
3. Check Let's Encrypt rate limits

### SSL errors in browser
1. Verify certificate covers the exact domain being accessed
2. Check certificate chain is complete
3. Ensure HTTPS redirect is working

### Mixed content warnings
1. Update all asset URLs to use HTTPS
2. Check for hardcoded HTTP URLs in database content

---

## Security Considerations

1. **Certificate Transparency**: All issued certificates are logged publicly
2. **HSTS**: Consider enabling HTTP Strict Transport Security
3. **Certificate Pinning**: Not recommended for custom domains (breaks renewals)
4. **Rate Limits**: Let's Encrypt has rate limits - plan for high-volume deployments
