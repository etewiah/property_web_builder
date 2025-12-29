# Session Store Configuration
#
# Production: Uses :cache_store (backed by Redis) for server-side sessions
# - Enables larger session data (cookies limited to 4KB)
# - Allows server-side session invalidation
# - Sessions shared across multiple web processes/servers
#
# Development: Uses :cookie_store for simplicity (no Redis required)
# Test: Uses :cache_store (null_store) to avoid persistence between tests
#
# Environment Variables:
#   REDIS_SESSION_URL - Dedicated Redis URL for sessions (optional)
#                       Falls back to REDIS_URL if not set
#
if Rails.env.production?
  # Use cache_store which is backed by Redis in production
  # Sessions expire after 2 weeks of inactivity
  Rails.application.config.session_store :cache_store,
    key: '_pwb_session',
    expire_after: 14.days,
    secure: true,
    same_site: :lax
elsif Rails.env.test?
  # Use cache_store (null_store in test) to avoid session persistence
  Rails.application.config.session_store :cache_store
else
  # Development: simple cookie store (no Redis required)
  Rails.application.config.session_store :cookie_store,
    key: '_pwb_session',
    same_site: :lax
end
