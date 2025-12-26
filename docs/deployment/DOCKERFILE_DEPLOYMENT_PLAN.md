# Dockerfile Deployment Plan for PropertyWebBuilder

This document outlines the deployment configuration requirements for creating a production Dockerfile for PropertyWebBuilder.

## 1. Language & Runtime Versions

### Ruby
- **Version**: 3.4.7 (from `.tool-versions`)
- **Gemfile requirement**: `ruby "~> 3.4.0"`
- **Implications**: 
  - Use Ruby 3.4.x base image
  - Consider using `ruby:3.4-slim-bookworm` or similar lightweight image
  - Ruby 3.4 includes better performance and security features

### Node.js
- **Version**: 22.16.0 (from `.tool-versions`)
- **Package.json requirement**: `"node": "22.x"`
- **Implications**:
  - Multi-stage build recommended: Node stage for assets, Ruby stage for app
  - Node.js 22.x is a stable LTS version
  - Consider `node:22-alpine` or `node:22-bookworm` for asset compilation

## 2. Database Configuration

### PostgreSQL
- **Database adapter**: PostgreSQL (gem: `pg`)
- **Production config** (`config/database.yml`):
  - Database name: `pwb_production`
  - Username: `pwb`
  - Password via env var: `PWB_DATABASE_PASSWORD`
  - Connection pooling: `RAILS_MAX_THREADS` (default 5)
  - Prepared statements disabled: `prepared_statements: false`
- **Deployment requirements**:
  - Docker: Connect to external PostgreSQL container/service
  - Environment variables:
    - `PWB_DATABASE_PASSWORD` - Database password
    - `DATABASE_URL` - Alternative connection string (if not using host/port)
    - `RAILS_MAX_THREADS` - Thread pool size (should match with Puma threads)
  - Database migrations: `bin/rails db:migrate` (called in Procfile release task)

## 3. Background Job Processing

### Solid Queue (Rails 8 Native)
- **Gem versions**:
  - `solid_queue ~> 1.0`
  - `mission_control-jobs ~> 0.3`
- **Procfile configuration**:
  ```
  web: bundle exec puma -C config/puma.rb
  worker: bundle exec bin/jobs
  release: bundle exec rake db:migrate
  ```
- **Production queue configuration** (`config/solid_queue.yml`):
  - **Dispatchers**: 1 instance, polling interval 1s, batch size 500
  - **Workers**: 4 separate queue workers:
    - `mailers`: 2 threads (high priority email delivery)
    - `notifications`: 2 threads
    - `default`: 3 threads
    - `low`: 1 thread (batch operations)
  - Database storage: Uses same database as app (simpler deployment)
- **Puma plugin integration** (`config/puma.rb`):
  - Can embed Solid Queue in Puma for single-process deployments
  - Enabled via env var: `SOLID_QUEUE_IN_PUMA`
- **Deployment strategy**:
  - Option 1: Run separate worker process (`bundle exec bin/jobs`)
  - Option 2: Embed in Puma via `SOLID_QUEUE_IN_PUMA=true` (simpler, limited to 1 worker)
  - Option 3: Multiple worker containers for high throughput

## 4. Asset Pipeline & Frontend

### CSS Compilation (Tailwind)
- **Framework**: Tailwind CSS 4.1.17 (npm package)
- **Build process** (`package.json` scripts):
  - Development: `npm run tailwind:watch:*` (watch mode for hot reload)
  - Production: `npm run tailwind:build:prod` (minified CSS)
  - Compiles three theme variants:
    - `tailwind:default:prod` → `app/assets/builds/tailwind-default.css`
    - `tailwind:bologna:prod` → `app/assets/builds/tailwind-bologna.css`
    - `tailwind:brisbane:prod` → `app/assets/builds/tailwind-brisbane.css`
- **Configuration**: `config/initializers/dartsass.rb` (Sass integration)

### JavaScript
- **Framework**: No bundler (importmap-rails)
- **Libraries**:
  - `stimulus-rails ~> 1.3` (JavaScript interactions)
  - `importmap-rails ~> 2.0` (modern Rails JS without bundler)
  - Playwright `^1.57.0` (dev dependency, E2E testing)
- **Asset serving**:
  - Static file server: Enabled via `RAILS_SERVE_STATIC_FILES` env var
  - Asset host (CDN): Configured via `ASSET_HOST` env var
- **Deprecations**:
  - Vue.js is deprecated (see `app/frontend/DEPRECATED.md`)
  - Bootstrap CSS is deprecated (using Tailwind instead)

### Asset Precompilation
- **Build process**:
  1. Install Node.js dependencies: `npm install`
  2. Compile Tailwind CSS: `npm run tailwind:build:prod`
  3. Precompile Rails assets: `bundle exec rake assets:precompile`
  4. Clean up temporary files
- **Sprockets configuration**: `sprockets-rails` gem
- **Output directory**: `public/assets/` (digest stamped files)
- **Production settings** (`config/environments/production.rb`):
  - Static file caching: `cache-control: public, max-age=1.year`
  - Digest stamping: Automatic via Sprockets
  - CDN support: Via `ASSET_HOST` env var

## 5. Storage Configuration

### Cloudflare R2 (Primary)
- **Service**: R2 (S3-compatible object storage)
- **Gem**: `aws-sdk-s3` (already included)
- **Configuration** (`config/storage.yml`):
  ```yaml
  cloudflare_r2:
    service: R2
    access_key_id: <%= ENV['R2_ACCESS_KEY_ID'] %>
    secret_access_key: <%= ENV['R2_SECRET_ACCESS_KEY'] %>
    region: auto
    bucket: <%= ENV['R2_BUCKET'] %>
    endpoint: <%= "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com" %>
    force_path_style: true
    public: true
    public_url: <%= ENV['R2_PUBLIC_URL'] %>
  ```
- **Production setup** (`config/environments/production.rb`):
  - Default service: `config.active_storage.service = :cloudflare_r2`
- **Environment variables required**:
  - `R2_ACCESS_KEY_ID` - Cloudflare R2 access key
  - `R2_SECRET_ACCESS_KEY` - Cloudflare R2 secret
  - `R2_BUCKET` - R2 bucket name
  - `R2_ACCOUNT_ID` - Cloudflare account ID
  - `R2_PUBLIC_URL` - Public CDN URL (optional, for custom domains)

### Fallback Options
- **Local disk** (`config/storage.yml`):
  - Development: `storage/` directory
  - Test: `tmp/storage/` directory
- **S3** (commented out but available):
  - Supports standard AWS S3 with custom credentials

## 6. Caching & Session Storage

### Redis Configuration
- **Gem**: `redis ~> 5.0`
- **Purpose**: Distributed caching (multi-server), Solid Queue storage, rails_performance data
- **Cache configuration** (`config/initializers/caching.rb`):
  - Production: Redis cache store with namespacing
  - Namespace: `pwb:` (all keys prefixed)
  - Tenant scoping: `pwb:w{website_id}:...`
  - Locale awareness: `pwb:w{website_id}:l{locale}:...`
  - Connection pooling: Based on `RAILS_MAX_THREADS`
  - Compression: Enabled for values > 1KB
  - Error handling: Logs errors but doesn't crash
  - Default expiry: 1 hour
- **Environment variables**:
  - `REDIS_URL` - Redis connection URL (default: `redis://localhost:6379/1`)
  - `REDIS_CACHE_URL` - Separate Redis for caching (optional)

## 7. Email Delivery

### SMTP Configuration (Flexible)
- **Configuration** (`config/environments/production.rb`):
  - Async delivery via Active Job (Solid Queue)
  - Queue name: `:mailers` (high priority, 2 threads)
  - Raise delivery errors: Enabled for production debugging
- **SMTP Environment Variables**:
  - `SMTP_ADDRESS` - SMTP server address (e.g., `smtp.sendgrid.net`)
  - `SMTP_PORT` - SMTP port (default: 587)
  - `SMTP_USERNAME` - SMTP username/API key
  - `SMTP_PASSWORD` - SMTP password/API secret
  - `SMTP_DOMAIN` - HELO domain (optional, falls back to MAILER_HOST)
  - `SMTP_AUTH` - Authentication type (default: `:plain`)
  - `MAILER_HOST` - Host for email links (e.g., `example.com`)
  - `APP_HOST` - Fallback host (default: `example.com`)

### Email Tracking
- **Gem**: AWS SES v2 support via `aws-sdk-sesv2`
- **Custom initializer**: `config/initializers/mail_delivery_observer.rb`
- **Note**: If SMTP not configured, falls back to test delivery (logs only)

## 8. Monitoring & Observability

### Error Tracking (Sentry)
- **Gems**:
  - `sentry-ruby`
  - `sentry-rails`
- **Environment variable**: `SENTRY_DSN` (implicit requirement)

### Structured Logging
- **Gems**:
  - `lograge` - Structured request logging
  - `logstash-event` - Logstash compatible format
- **Production settings**:
  - Log to STDOUT with request ID tags
  - Log level: Controlled by `RAILS_LOG_LEVEL` (default: `info`)
  - Health checks silenced: `/up` endpoint excluded from logs

### Performance Monitoring (Self-Hosted)
- **Gem**: `rails_performance`
- **Dashboard**: Available at `/rails/performance`
- **Data storage**: Redis (never sent externally)
- **Optional resource monitoring**:
  - `sys-cpu` - CPU usage tracking
  - `sys-filesystem` - Disk usage tracking
  - `get_process_mem` - Memory usage tracking
  - Enabled via env var: `RAILS_PERFORMANCE_RESOURCE_MONITOR=true`

### Analytics
- **Gems**:
  - `ahoy_matey ~> 5.0` - Visit and event tracking
  - `chartkick ~> 5.0` - Chart visualization
  - `groupdate ~> 6.0` - Time-based grouping

## 9. Security

### Middleware & Protection
- **Gems**:
  - `rack-cors ~> 3.0` - CORS handling
  - `rack-attack ~> 6.7` - Rate limiting and DDoS protection
- **Configuration** (`config/initializers/rack_attack.rb`):
  - Protects against brute force attacks
- **SSL/HTTPS**:
  - `config.assume_ssl = true` - Assume reverse proxy handles SSL
  - `config.force_ssl = true` - Force HTTPS redirects
  - Strict-Transport-Security headers enabled

### Profanity Filter
- **Gem**: `obscenity ~> 1.0`
- **Purpose**: Subdomain validation to prevent inappropriate domains

## 10. System Dependencies

### Build-Time Dependencies
- **C/C++ build tools** (for native gems):
  - `build-essential` (Debian/Ubuntu)
  - Needed for:
    - `pg` gem (PostgreSQL)
    - `image_processing` (image manipulation)
    - `sys-cpu`, `sys-filesystem` (system monitoring)
- **Development headers**:
  - PostgreSQL: `libpq-dev`
  - Image libraries: `libvips`, `libvips-dev` (for sharp/image_processing)

### Runtime Dependencies
- **PostgreSQL client**: `libpq5` (minimal, for pg gem)
- **Image processing**: `libvips` (for ActiveStorage image processing)
- **Standard utilities**:
  - `curl` (health checks, debugging)
  - `ca-certificates` (SSL/TLS)

## 11. Image Processing

### Configuration
- **Gem**: `image_processing ~> 1.2`
- **npm**: `sharp ^0.33.5`
- **Usage**:
  - ActiveStorage image variants (resizing, optimization)
  - Critical CSS extraction: `npm run critical:extract`
- **Environment requirements**:
  - libvips library (for image processing)
  - Node.js for sharp

## 12. Environment Variables Summary

### Critical Variables
```
# Database
PWB_DATABASE_PASSWORD
RAILS_MAX_THREADS

# Email
SMTP_ADDRESS
SMTP_PORT
SMTP_USERNAME
SMTP_PASSWORD
MAILER_HOST

# Storage (R2)
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
R2_BUCKET
R2_ACCOUNT_ID
R2_PUBLIC_URL (optional)

# Caching
REDIS_URL
REDIS_CACHE_URL (optional)
```

### Optional Variables
```
# Security
SENTRY_DSN

# Logging
RAILS_LOG_LEVEL (default: info)
RAILS_SERVE_STATIC_FILES (for serving assets)

# Performance
RAILS_PERFORMANCE_RESOURCE_MONITOR (default: false)
SOLID_QUEUE_IN_PUMA (to embed worker in Puma)

# CDN
ASSET_HOST

# Email
SMTP_DOMAIN (optional)
SMTP_AUTH (optional)
```

## 13. Procfile Processes

```procfile
web: bundle exec puma -C config/puma.rb
worker: bundle exec bin/jobs
release: bundle exec rake db:migrate
```

### Deployment Process
1. **Release**: Run migrations on deployment
2. **Web**: Start Puma web server (configurable threads/workers via env)
3. **Worker**: Start Solid Queue background jobs

## Dockerfile Implementation Recommendations

### Multi-Stage Build Pattern
```dockerfile
# Stage 1: Dependencies and Asset Compilation
FROM node:22-bookworm AS node_builder
# Install Node dependencies
# Compile Tailwind CSS

# Stage 2: Ruby Build
FROM ruby:3.4-slim-bookworm AS ruby_builder
# Install build dependencies
# Copy Gemfile and install gems
# Install bundler

# Stage 3: Runtime
FROM ruby:3.4-slim-bookworm
# Install runtime dependencies only
# Copy compiled gems from ruby_builder
# Copy compiled assets from node_builder
# Setup entrypoint for Puma/Worker
```

### Key Build Steps
1. **Install system dependencies**:
   - Build tools: `build-essential`, `libpq-dev`, `libvips-dev`
   - Runtime libs: `libpq5`, `libvips`
   - Utilities: `curl`, `ca-certificates`

2. **Ruby setup**:
   - Install Bundler
   - Copy Gemfile and Gemfile.lock
   - Run `bundle install --without development,test`

3. **Node setup** (asset compilation stage):
   - Copy package.json and package-lock.json
   - Run `npm install`
   - Run `npm run tailwind:build:prod`

4. **Rails assets**:
   - Copy app code
   - Run `bundle exec rake assets:precompile`

5. **Cleanup**:
   - Remove development dependencies
   - Remove node_modules from final image
   - Remove build tools from final image

### Environment Preparation
- Set `RAILS_ENV=production`
- Set `NODE_ENV=production`
- Disable Ruby warnings in production
- Create directories for PID files

### Health Checks
- Use `/up` endpoint (Rails 7.1+ standard)
- Configure timeout and retry values

### Signal Handling
- Puma handles SIGTERM gracefully
- Solid Queue workers should handle shutdown signals

### Storage Considerations
- Temporary storage: `/tmp` (build artifacts)
- No persistent storage (stateless design)
- Use R2 for file storage
- Use Redis for caching/sessions
- Use PostgreSQL for primary data

## 13. Deployment Checklist

- [ ] Ruby 3.4.7 base image
- [ ] Node.js 22.16.0 for asset compilation
- [ ] PostgreSQL connection with `PWB_DATABASE_PASSWORD` env var
- [ ] Solid Queue configured with 4 worker types
- [ ] Redis for caching at `REDIS_URL`
- [ ] Cloudflare R2 credentials for object storage
- [ ] SMTP configuration for email delivery
- [ ] Sentry DSN for error tracking
- [ ] SSL/TLS configuration (assume reverse proxy)
- [ ] Health check endpoint `/up` configured
- [ ] Proper signal handling for graceful shutdown
- [ ] Multi-stage Docker build for optimization
- [ ] Asset precompilation in build process
- [ ] Database migrations on release
- [ ] Separate health check database pools

