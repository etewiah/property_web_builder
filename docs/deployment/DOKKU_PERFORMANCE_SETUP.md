# Dokku Performance Setup

This guide covers setting up Redis and PgBouncer for improved performance in Dokku deployments.

## Prerequisites

- Dokku server with your app deployed
- SSH access to Dokku server

## 1. Redis Setup

Redis is used for caching and session storage.

### Install Redis Plugin

```bash
# On Dokku server
sudo dokku plugin:install https://github.com/dokku/dokku-redis.git redis
```

### Create Redis Service

```bash
# Create Redis service
dokku redis:create pwb-redis

# Link to your app (creates REDIS_URL environment variable)
dokku redis:link pwb-redis pwb-2025
```

### Verify Connection

```bash
# Check Redis is linked
dokku config:show pwb-2025 | grep REDIS

# Should show something like:
# REDIS_URL: redis://pwb-redis:6379
```

## 2. PgBouncer Setup

PgBouncer provides connection pooling, reducing PostgreSQL connection overhead.

### Install PgBouncer Plugin

```bash
# On Dokku server
sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git postgres
```

### Enable PgBouncer for Existing Database

If you already have a Postgres service:

```bash
# Check current database link
dokku postgres:info pwb-database

# Enable connection pooling
dokku postgres:connect-pool:create pwb-database pwb-2025

# Or manually set DATABASE_URL with pgbouncer settings
```

### Alternative: Manual PgBouncer Configuration

For more control, you can run PgBouncer as a separate service:

```bash
# Create pgbouncer.ini config
cat > /var/lib/dokku/services/postgres/pwb-database/pgbouncer.ini << 'EOF'
[databases]
pwb_production = host=localhost port=5432 dbname=pwb_production

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 100
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
server_lifetime = 3600
server_idle_timeout = 600
EOF
```

### Configure App for PgBouncer

Add to your app's environment:

```bash
# Disable prepared statements (required for transaction pooling)
dokku config:set pwb-2025 DATABASE_PREPARED_STATEMENTS=false

# If using separate pgbouncer, update DATABASE_URL
# dokku config:set pwb-2025 DATABASE_URL=postgres://user:pass@localhost:6432/pwb_production
```

## 3. Environment Variables

Set all required environment variables:

```bash
# Redis URLs (automatically set by redis:link, but can override)
dokku config:set pwb-2025 \
  REDIS_URL=redis://pwb-redis:6379/0 \
  REDIS_CACHE_URL=redis://pwb-redis:6379/1 \
  REDIS_SESSION_URL=redis://pwb-redis:6379/2

# Database performance settings
dokku config:set pwb-2025 \
  RAILS_MAX_THREADS=5 \
  DATABASE_PREPARED_STATEMENTS=false

# Enable database warmup
dokku config:set pwb-2025 WARMUP_DB=true
```

## 4. Verify Setup

### Check Redis Connection

```bash
dokku run pwb-2025 rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
# Should output: PONG
```

### Check Cache Store

```bash
dokku run pwb-2025 rails runner "Rails.cache.write('test', 'value'); puts Rails.cache.read('test')"
# Should output: value
```

### Check Database Connections

```bash
dokku run pwb-2025 rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
# Should output: {"?column?"=>1}
```

## 5. Monitoring

### Redis Stats

```bash
dokku redis:info pwb-redis
```

### PostgreSQL Connections

```bash
dokku postgres:connect pwb-database -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'pwb_production';"
```

## 6. Scaling

For multi-process deployments:

```bash
# Scale web processes
dokku ps:scale pwb-2025 web=2 worker=1

# With Redis caching, multiple web processes share the same cache
```

## Troubleshooting

### Redis Connection Issues

```bash
# Check Redis logs
dokku redis:logs pwb-redis

# Restart Redis
dokku redis:restart pwb-redis
```

### Database Connection Pool Exhaustion

If you see "could not obtain a connection from the pool":

```bash
# Increase pool size
dokku config:set pwb-2025 RAILS_MAX_THREADS=10

# Or enable PgBouncer transaction pooling
```

### Cache Not Working

```bash
# Verify Redis is linked
dokku redis:linked pwb-2025 pwb-redis

# Check cache store in Rails
dokku run pwb-2025 rails runner "puts Rails.cache.class"
# Should output: ActiveSupport::Cache::RedisCacheStore
```
