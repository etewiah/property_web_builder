# frozen_string_literal: true

# Security Assertions
#
# Raises on boot if dangerous security settings are active in production.
# This is a belt-and-suspenders guard — the code already prevents these bypasses
# in production, but raising at startup makes misconfiguration immediately visible
# rather than silently passing.

if Rails.env.production? || Rails.env.staging?
  if ENV["BYPASS_ADMIN_AUTH"] == "true"
    raise <<~MSG
      SECURITY ERROR: BYPASS_ADMIN_AUTH=true is set in a production/staging environment.
      This disables admin authentication and must never be enabled in production.
      Remove this environment variable immediately.
    MSG
  end

  if ENV["BYPASS_API_AUTH"] == "true"
    raise <<~MSG
      SECURITY ERROR: BYPASS_API_AUTH=true is set in a production/staging environment.
      This disables API authentication and must never be enabled in production.
      Remove this environment variable immediately.
    MSG
  end
end
