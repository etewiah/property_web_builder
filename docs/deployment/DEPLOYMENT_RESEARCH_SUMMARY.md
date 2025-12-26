# Deployment Research Summary

## Quick Reference: PropertyWebBuilder Production Deployment

### Core Technologies
| Component | Version | Configuration |
|-----------|---------|----------------|
| **Ruby** | 3.4.7 | Rails 8.1 |
| **Node.js** | 22.16.0 | Asset compilation (Tailwind) |
| **Database** | PostgreSQL | Separate host, `pwb` user |
| **Queue** | Solid Queue 1.0 | Native Rails 8, in PostgreSQL |
| **Cache** | Redis 5.0 | Multi-tenant aware caching |
| **Storage** | Cloudflare R2 | S3-compatible, with custom CDN |
| **Web Server** | Puma | Configurable threads/workers |
| **Email** | SMTP | Async via Solid Queue mailers |

### No Docker Files Found
- **Dockerfile**: None exists
- **docker-compose**: None exists
- This is a fresh Docker setup opportunity

### Multi-Process Architecture Required
```
web:    bundle exec puma -C config/puma.rb
worker: bundle exec bin/jobs
db:     rake db:migrate (on release)
```

### Asset Compilation Pipeline
1. **Node/NPM** → Compiles 3 Tailwind themes (default, bologna, brisbane)
2. **Rails Assets** → Precompiles images, fonts, JavaScript
3. **Output**: Digest-stamped files in `public/assets/`
4. **Serving**: Via `ASSET_HOST` CDN or static file server

### Critical Environment Variables (18 Required)
```
Database:         PWB_DATABASE_PASSWORD, RAILS_MAX_THREADS
Email:            SMTP_ADDRESS, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD, MAILER_HOST
Storage (R2):     R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_ACCOUNT_ID
Caching:          REDIS_URL (REDIS_CACHE_URL optional)
SSL/TLS:          ASSET_HOST (for CDN)
Monitoring:       SENTRY_DSN (optional)
Performance:      RAILS_PERFORMANCE_RESOURCE_MONITOR (optional)
```

### System Libraries Required
```
Build:   build-essential, libpq-dev, libvips-dev
Runtime: libpq5, libvips, curl, ca-certificates
```

### Production Queue Configuration
- **4 separate worker types** with different priorities:
  - `mailers`: 2 threads (emails - highest priority)
  - `notifications`: 2 threads
  - `default`: 3 threads
  - `low`: 1 thread (batch operations)
- Alternative: Embed in Puma via `SOLID_QUEUE_IN_PUMA=true`

### Important Notes

#### Multi-Tenancy
- App is multi-tenant (each website = tenant)
- Cache keys include `website_id`
- Model queries scoped to `current_website`

#### Deprecated Tech
- Vue.js is NOT in use (deprecated)
- Bootstrap is NOT in use (using Tailwind)
- Selenium/Capybara JS tests NOT used (using Playwright)

#### Special Features
- Structured logging (lograge + logstash format) → STDOUT
- Self-hosted performance monitoring (rails_performance via Redis)
- Ahoy.js analytics tracking
- Liquid template support for theme pages
- GraphQL API support (configured but usage varies)

#### Health Checks
- Use `/up` endpoint (standard Rails 7.1+ endpoint)
- App logs to STDOUT (container-friendly)
- Request ID tagged logging

#### SSL/TLS
- Assumes reverse proxy (nginx/load balancer) handles SSL
- `config.assume_ssl = true` and `config.force_ssl = true`
- HSTS headers automatically added

### Procfile Strategy
```
Release: db:migrate (runs once per deployment)
Web:     puma server (main app, configurable via env)
Worker:  bin/jobs (background job processing)
```

### Next Steps for Dockerfile
1. **Build base image** with Ruby 3.4.7 and system dependencies
2. **Multi-stage build**: Node stage → asset compilation, Ruby stage → app
3. **Environment setup**:
   - `RAILS_ENV=production`
   - `NODE_ENV=production`
4. **Asset precompilation** in build process
5. **Entrypoint script** to handle Puma/Worker processes
6. **Health check** configuration
7. **Optional**: Build layers for reduced image size (gem caching, etc.)

### Key Production Settings
- **Cache store**: Redis with namespacing and compression
- **Asset caching**: 1-year cache control headers (digest stamped)
- **Database**: Prepared statements disabled (compatibility)
- **Logging**: Request ID tagged, health checks silenced
- **Email**: Raise delivery errors for monitoring
- **SSL**: Enforce HTTPS with HSTS headers
- **Static files**: Served from CDN via `ASSET_HOST` (optional)

