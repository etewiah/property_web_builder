# Serving Static Assets from Cloudflare R2 CDN

This guide explains how to serve Rails static assets (JS, CSS, fonts, images) from Cloudflare R2 for improved performance.

## Overview

- Assets are compiled locally or in CI
- Assets are synced to R2 bucket
- Assets are served via R2's public URL with CDN caching
- Rails `asset_host` is configured to use the R2 public URL

## Prerequisites

1. Cloudflare R2 bucket with public access enabled
2. R2 API credentials configured
3. `aws-sdk-s3` gem (already included)

## Environment Variables

Add these to your production environment:

```bash
# Existing R2 variables (for ActiveStorage)
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key
R2_BUCKET=pwb-prod-assets-eu

# New variables for asset CDN
R2_PUBLIC_URL=https://pub-xxx.r2.dev
ASSET_HOST=https://pub-xxx.r2.dev/assets
```

**Note**: `ASSET_HOST` should include `/assets` at the end since files are uploaded to the `assets/` prefix in R2.

## Deployment Steps

### Option A: Manual Sync

```bash
# 1. Precompile assets
RAILS_ENV=production bundle exec rails assets:precompile

# 2. Sync to R2
RAILS_ENV=production bundle exec rails assets:sync_to_r2

# Or do both in one command:
RAILS_ENV=production bundle exec rails assets:cdn_deploy
```

### Option B: CI/CD Integration

Add to your deployment script (e.g., GitHub Actions, Render, etc.):

```yaml
# GitHub Actions example
- name: Precompile and sync assets
  env:
    RAILS_ENV: production
    R2_ACCOUNT_ID: ${{ secrets.R2_ACCOUNT_ID }}
    R2_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
    R2_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
    R2_BUCKET: ${{ secrets.R2_BUCKET }}
  run: |
    bundle exec rails assets:cdn_deploy
```

### Option C: Render.com Build Command

```bash
bundle install && bundle exec rails assets:cdn_deploy && bundle exec rails db:migrate
```

## How It Works

1. `assets:precompile` compiles assets to `public/assets/`
2. `assets:sync_to_r2` uploads files to R2 bucket under `assets/` prefix
3. Files are uploaded with:
   - Correct `Content-Type` headers
   - `Cache-Control: public, max-age=31536000, immutable` (1 year cache)
4. Rails serves asset URLs pointing to `ASSET_HOST`

## Verification

After deployment, check that assets load from R2:

```bash
# Check an asset URL
curl -I https://your-site.com/ 2>&1 | grep -i "link.*stylesheet"

# Should show something like:
# <link href="https://pub-xxx.r2.dev/assets/application-abc123.css" ...>
```

## Rollback

To revert to serving assets from the app server:

1. Remove or unset `ASSET_HOST` environment variable
2. Restart the application

Assets will be served from `public/assets/` on your app server again.

## Troubleshooting

### Assets not loading from CDN
- Verify `ASSET_HOST` is set correctly (include `/assets` suffix)
- Check R2 bucket has public access enabled
- Run `rails assets:sync_to_r2` to ensure files are uploaded

### CORS errors
Add CORS policy to your R2 bucket in Cloudflare dashboard:
```json
[
  {
    "AllowedOrigins": ["https://yourdomain.com", "https://*.yourdomain.com"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 86400
  }
]
```

### Missing content types
The sync task handles common file types. If you have unusual file types, add them to the `content_types` hash in `lib/tasks/assets_cdn.rake`.
