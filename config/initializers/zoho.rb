# frozen_string_literal: true

# Zoho CRM Integration Configuration
#
# This initializer sets up the Zoho CRM integration for lead tracking.
#
# Required Environment Variables (or Rails credentials):
#   ZOHO_CLIENT_ID     - OAuth client ID from Zoho API Console
#   ZOHO_CLIENT_SECRET - OAuth client secret
#   ZOHO_REFRESH_TOKEN - Long-lived refresh token obtained during OAuth flow
#
# Optional:
#   ZOHO_API_DOMAIN    - API base URL (default: https://www.zohoapis.com)
#                        Use https://www.zohoapis.eu for EU datacenter
#   ZOHO_ACCOUNTS_URL  - Accounts URL for OAuth (default: https://accounts.zoho.com)
#                        Use https://accounts.zoho.eu for EU datacenter
#
# Setup Guide:
# 1. Create a Zoho API Console app at https://api-console.zoho.com/
# 2. Generate OAuth tokens using the rake task:
#    bundle exec rake zoho:generate_tokens
# 3. Store the refresh token in Rails credentials:
#    EDITOR=nano rails credentials:edit
#
# Example credentials format:
#   zoho:
#     client_id: "your_client_id"
#     client_secret: "your_client_secret"
#     refresh_token: "your_refresh_token"
#     api_domain: "https://www.zohoapis.com"
#     accounts_url: "https://accounts.zoho.com"
#

Rails.application.config.after_initialize do
  # Only log warning if in development and not configured
  if Rails.env.development?
    client = Pwb::Zoho::Client.instance
    unless client.configured?
      Rails.logger.info "[Zoho] CRM integration not configured. Set ZOHO_CLIENT_ID, ZOHO_CLIENT_SECRET, and ZOHO_REFRESH_TOKEN to enable."
    end
  end
end
