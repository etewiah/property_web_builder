# Restrict session cookies to current subdomain
# This prevents sharing sessions between subdomains
Rails.application.config.session_store :cookie_store, key: '_pwb_session'
