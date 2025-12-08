# frozen_string_literal: true

# Configuration for multi-tenant domain routing
#
# This initializer sets up the domain routing configuration for the multi-tenant system.
# Tenants can be accessed via:
# 1. Platform subdomains (e.g., tenant-a.propertywebbuilder.com)
# 2. Custom domains (e.g., www.myrealestate.com)
#
# Environment Variables:
#   PLATFORM_DOMAINS - Comma-separated list of platform domains where subdomains route to tenants
#                      Default: 'propertywebbuilder.com'
#                      Example: 'propertywebbuilder.com,staging.propertywebbuilder.com,pwb.localhost'
#
#   ALLOW_UNVERIFIED_DOMAINS - Set to 'true' to allow custom domains without DNS verification
#                              Default: false (only true in development/test by default)
#
#   PLATFORM_IP - IP address for A record DNS configuration (for apex domains)
#                 Should be set in production to your server's IP

Rails.application.config.tenant_domains = {
  # Platform domains where subdomains are treated as tenant identifiers
  # e.g., tenant-a.propertywebbuilder.com -> tenant-a
  platform_domains: ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com').split(',').map(&:strip),

  # Whether to allow unverified custom domains (should only be true in dev/test)
  allow_unverified_domains: ENV.fetch('ALLOW_UNVERIFIED_DOMAINS', 'false') == 'true' ||
                            Rails.env.development? ||
                            Rails.env.test?,

  # DNS verification prefix for custom domain ownership verification
  # Tenants add a TXT record at: _pwb-verification.theirdomain.com
  verification_prefix: '_pwb-verification',

  # Platform IP for A record configuration (apex domains)
  platform_ip: ENV.fetch('PLATFORM_IP', nil)
}

# Log configuration in development
if Rails.env.development?
  Rails.logger.info "[TenantDomains] Platform domains: #{Rails.application.config.tenant_domains[:platform_domains].join(', ')}"
  Rails.logger.info "[TenantDomains] Allow unverified domains: #{Rails.application.config.tenant_domains[:allow_unverified_domains]}"
end
