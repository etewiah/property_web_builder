# Restrict session cookies to current subdomain
# This prevents sharing sessions between subdomains
if Rails.env.test?
  Rails.application.config.session_store :cache_store
else
  Rails.application.config.session_store :cookie_store, key: '_pwb_session'
end
