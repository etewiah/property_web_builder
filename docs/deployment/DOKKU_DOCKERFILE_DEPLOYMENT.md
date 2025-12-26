# Dokku Dockerfile Deployment Guide

This guide explains how to deploy PropertyWebBuilder to Dokku using the production Dockerfile.

## Prerequisites

- Dokku server with Docker installed
- PostgreSQL plugin installed
- Redis plugin installed (for caching)
- Domain configured

## Initial Setup

### 1. Switch to Dockerfile Builder

By default, Dokku uses the Heroku buildpack. Switch to Dockerfile-based builds:

```bash
# On your Dokku server
dokku builder:set pwb-2025 selected dockerfile
```

### 2. Create and Link Database

```bash
# Create PostgreSQL database
dokku postgres:create pwb-db

# Link to app (sets DATABASE_URL automatically)
dokku postgres:link pwb-db pwb-2025
```

### 3. Create and Link Redis (for caching)

```bash
# Create Redis instance
dokku redis:create pwb-redis

# Link to app (sets REDIS_URL automatically)
dokku redis:link pwb-redis pwb-2025
```

### 4. Configure Environment Variables

Set required environment variables:

```bash
# Database password (if not using DATABASE_URL)
dokku config:set pwb-2025 PWB_DATABASE_PASSWORD=your_secure_password

# Rails configuration
dokku config:set pwb-2025 RAILS_ENV=production
dokku config:set pwb-2025 SECRET_KEY_BASE=$(openssl rand -hex 64)
dokku config:set pwb-2025 RAILS_SERVE_STATIC_FILES=true
dokku config:set pwb-2025 RAILS_LOG_TO_STDOUT=true

# Email configuration (example using SendGrid)
dokku config:set pwb-2025 SMTP_ADDRESS=smtp.sendgrid.net
dokku config:set pwb-2025 SMTP_PORT=587
dokku config:set pwb-2025 SMTP_USERNAME=apikey
dokku config:set pwb-2025 SMTP_PASSWORD=your_sendgrid_api_key
dokku config:set pwb-2025 MAILER_HOST=your-domain.com

# Cloudflare R2 storage
dokku config:set pwb-2025 R2_ACCESS_KEY_ID=your_r2_access_key
dokku config:set pwb-2025 R2_SECRET_ACCESS_KEY=your_r2_secret_key
dokku config:set pwb-2025 R2_BUCKET=your_bucket_name
dokku config:set pwb-2025 R2_ACCOUNT_ID=your_cloudflare_account_id
dokku config:set pwb-2025 R2_PUBLIC_URL=https://cdn.your-domain.com

# Optional: CDN for static assets
dokku config:set pwb-2025 ASSET_HOST=https://cdn.your-domain.com

# Optional: Sentry error tracking
dokku config:set pwb-2025 SENTRY_DSN=your_sentry_dsn

# Optional: Embed Solid Queue in Puma (single process deployment)
dokku config:set pwb-2025 SOLID_QUEUE_IN_PUMA=true
```

### 5. Configure Process Scaling

```bash
# Scale web and worker processes
dokku ps:scale pwb-2025 web=1 worker=1

# Or for single-process deployment (with SOLID_QUEUE_IN_PUMA=true)
dokku ps:scale pwb-2025 web=1
```

### 6. Configure Health Checks

```bash
# Set health check path
dokku checks:set pwb-2025 /up
```

### 7. Set Up SSL

```bash
# Using Let's Encrypt
dokku letsencrypt:enable pwb-2025
```

## Deployment

### Deploy from Local Machine

```bash
# Add Dokku as a remote
git remote add dokku dokku@your-server.com:pwb-2025

# Push to deploy
git push dokku main:master
```

### Deploy from CI/CD

Example GitHub Actions workflow:

```yaml
name: Deploy to Dokku

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Deploy to Dokku
        uses: dokku/github-action@master
        with:
          git_remote_url: 'ssh://dokku@your-server.com:22/pwb-2025'
          ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
```

## Build Process

The Dockerfile performs a multi-stage build:

1. **Node.js Stage**: Compiles Tailwind CSS for all themes
2. **Ruby Builder Stage**: Installs gems with native extensions
3. **Production Stage**: Minimal runtime image with only necessary dependencies

### Build Output

- **Image size**: ~300-400MB (compared to ~1GB with buildpack)
- **Build time**: ~3-5 minutes (after Docker cache is warmed)
- **Boot time**: ~5-10 seconds (with bootsnap precompilation)

## Monitoring

### View Logs

```bash
dokku logs pwb-2025 -t
```

### Check Container Status

```bash
dokku ps:report pwb-2025
```

### Access Rails Console

```bash
dokku run pwb-2025 bundle exec rails console
```

### Run Database Migrations Manually

```bash
dokku run pwb-2025 bundle exec rake db:migrate
```

## Troubleshooting

### Build Fails at Asset Precompilation

Ensure the Tailwind CSS files are being built correctly:

```bash
# Check build logs
dokku logs pwb-2025 --all

# Rebuild without cache
dokku ps:rebuild pwb-2025
```

### Database Connection Issues

```bash
# Check database connectivity
dokku postgres:info pwb-db

# Verify DATABASE_URL is set
dokku config pwb-2025 | grep DATABASE
```

### Container Keeps Restarting

```bash
# Check health check endpoint
dokku checks:report pwb-2025

# Increase startup timeout if needed
dokku checks:set pwb-2025 wait-to-retire 60
```

## Environment Variables Reference

See `docs/deployment/DOCKERFILE_DEPLOYMENT_PLAN.md` for the complete list of environment variables.

### Critical Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SECRET_KEY_BASE` | Rails secret key | Yes |
| `DATABASE_URL` | PostgreSQL connection string | Yes (or PWB_DATABASE_PASSWORD) |
| `REDIS_URL` | Redis connection string | Yes |
| `SMTP_ADDRESS` | SMTP server address | Yes |
| `SMTP_USERNAME` | SMTP username | Yes |
| `SMTP_PASSWORD` | SMTP password | Yes |
| `MAILER_HOST` | Host for email links | Yes |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 access key | Yes |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 secret | Yes |
| `R2_BUCKET` | R2 bucket name | Yes |
| `R2_ACCOUNT_ID` | Cloudflare account ID | Yes |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ASSET_HOST` | CDN URL for assets | None |
| `SENTRY_DSN` | Sentry error tracking | None |
| `RAILS_LOG_LEVEL` | Log verbosity | `info` |
| `SOLID_QUEUE_IN_PUMA` | Embed worker in Puma | `false` |
| `RAILS_MAX_THREADS` | Puma thread count | `5` |

## Advantages Over Buildpack Deployment

1. **Full control over build process** - No reliance on Heroku buildpack behavior
2. **Smaller image size** - Multi-stage build removes build dependencies
3. **Faster boot times** - Bootsnap precompilation during build
4. **Predictable builds** - Same Dockerfile runs locally and in production
5. **Asset compilation during build** - Assets are compiled once, not on every deploy
6. **No buildpack version issues** - Pin exact Ruby and Node.js versions
