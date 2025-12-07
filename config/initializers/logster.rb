require 'logster'
require 'redis'

# Configure Logster to use Redis
# Logster requires a store to be configured.
# We use Redis as the store.

redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
Logster.store = Logster::RedisStore.new(Redis.new(url: redis_url))
