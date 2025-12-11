# External Seed Images

This document describes how PropertyWebBuilder uses external image URLs for seeding instead of uploading files to storage.

## Problem

When seeding databases (for development, testing, or demos), the traditional approach was to attach local image files to properties using ActiveStorage. This created several issues:

1. **Storage Bloat**: Seed images accumulated in storage (local disk or R2)
2. **Orphaned Blobs**: When users deleted seeded properties, the underlying blobs often remained
3. **Unnecessary Costs**: R2/S3 storage costs for temporary demo data
4. **Slow Seeding**: File uploads add overhead to the seeding process

## Solution

Instead of uploading images, seed data now uses **external URLs** pointing to a public R2 bucket containing pre-uploaded seed images. This approach:

- Avoids creating any ActiveStorage blobs for seed data
- Uses the existing `external_url` column on photo models
- Works seamlessly with the `ExternalImageSupport` concern
- Falls back to local file attachment when R2 URLs aren't configured

## Configuration

### Quick Setup (Recommended)

Set your R2 bucket name - the public URL is auto-calculated:

```bash
# In your .env or environment
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_SEED_IMAGES_BUCKET=pwb-seed-assets
```

This automatically generates the public URL:
```
https://pub-{R2_ACCOUNT_ID}.r2.dev/{R2_SEED_IMAGES_BUCKET}
```

### Alternative: Direct URL

You can also set a custom base URL directly:

```bash
SEED_IMAGES_BASE_URL=https://your-custom-cdn.com/images
```

### Fallback Behavior

If neither `R2_SEED_IMAGES_BUCKET` nor `SEED_IMAGES_BASE_URL` is set, the system falls back to attaching local files from `db/seeds/images/`.

### Config File

The image mappings are defined in `config/seed_images.yml`:

```yaml
default: &default
  base_url: <%= seed_images_base_url %>  # Auto-calculated from R2 bucket
  r2_bucket: <%= ENV['R2_SEED_IMAGES_BUCKET'] %>
  r2_account_id: <%= ENV['R2_ACCOUNT_ID'] %>

  properties:
    apartment_downtown: apartment_downtown.jpg
    villa_ocean: villa_ocean.jpg
    # ... more mappings
```

## Usage in Seeds

### Using the SeedImages Helper

```ruby
require_relative '../../lib/pwb/seed_images'

# Get property image URL
url = Pwb::SeedImages.property_url('villa_ocean')
# => "https://pub-pwb-seed-images.r2.dev/seed-images/villa_ocean.jpg"

# Get content image URL
url = Pwb::SeedImages.content_url('hero_amsterdam_canal')

# Get team image URL
url = Pwb::SeedImages.team_url('team_director')

# Check if external images are enabled
if Pwb::SeedImages.enabled?
  # Use external URLs
else
  # Fall back to local files
end
```

### In E2E Seeds

The `attach_property_image` helper automatically uses external URLs when available:

```ruby
# This will use external_url if SEED_IMAGES_BASE_URL is set
attach_property_image(asset, 'villa_ocean.jpg')
```

### In Seed Packs

Seed packs also automatically use external URLs:

```ruby
# In pack.yml property definitions
properties/villa_marbella:
  image: villa_ocean.jpg  # Will use external URL automatically
```

## Rake Tasks

The following rake tasks help manage seed images:

### Check Availability

```bash
# Check if seed images are available (local or R2)
rails pwb:seed_images:check
```

This checks whether images are available and reports the mode (external or local).

### Upload to R2

```bash
# Upload seed images to R2 (skips existing)
rails pwb:seed_images:upload

# Upload all images (overwrites existing)
rails pwb:seed_images:upload_all
```

Required environment variables for upload:
- `R2_ACCESS_KEY_ID` - R2 API access key
- `R2_SECRET_ACCESS_KEY` - R2 API secret key
- `R2_ACCOUNT_ID` - Cloudflare account ID
- `R2_SEED_IMAGES_BUCKET` - Bucket name (e.g., `pwb-seed-assets`)

### Show Configuration

```bash
# View current configuration and computed values
rails pwb:seed_images:config
```

### List Remote Images

```bash
# List images currently in R2 bucket
rails pwb:seed_images:list_remote
```

## Automatic Warnings

When running seeding tasks, the system automatically checks for image availability and warns if images are not found:

```
============================================================
WARNING: Seed images not available for E2E test seeding
============================================================
No local images found at:
  /path/to/db/seeds/images

Options:
  1. Add images to db/seeds/images/
  2. Set SEED_IMAGES_BASE_URL for external R2 images
  3. Run: rails pwb:seed_images:check

Properties will be created without images.
============================================================
```

This warning appears before:
- `playwright:reset`
- `playwright:seed`
- `pwb:seed_packs:apply`
- `pwb:seed_packs:apply_with_options`
- `pwb:seed_packs:reset_and_apply`

## Setting Up R2 Bucket

### 1. Create R2 Bucket

In Cloudflare Dashboard:
1. Go to R2 > Create Bucket
2. Name it `pwb-seed-assets` (or your preferred name)
3. Enable public access (Settings > Public Access > Allow Access)

### 2. Configure Environment

Add to your `.env` file:

```bash
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_SEED_IMAGES_BUCKET=pwb-seed-assets
R2_ACCESS_KEY_ID=your_r2_access_key
R2_SECRET_ACCESS_KEY=your_r2_secret_key
```

### 3. Upload Seed Images

```bash
# Upload images (skips existing)
rails pwb:seed_images:upload

# Or force upload all (overwrites)
rails pwb:seed_images:upload_all
```

### 4. Verify

```bash
# Check configuration
rails pwb:seed_images:config

# Check availability
rails pwb:seed_images:check

# List uploaded images
rails pwb:seed_images:list_remote
```

The public URL is auto-calculated from your account ID and bucket name:
```
https://pub-{R2_ACCOUNT_ID}.r2.dev/{R2_SEED_IMAGES_BUCKET}
```

## How It Works

### Photo Models

Both `PropPhoto` and `ContentPhoto` include the `ExternalImageSupport` concern which provides:

```ruby
# Check if using external URL
photo.external?  # => true if external_url is set

# Get image URL (works for both external and ActiveStorage)
photo.image_url  # => returns external_url or ActiveStorage URL

# Check if any image exists
photo.has_image?  # => true if external_url OR image.attached?
```

### Display in Views

The existing view helpers already handle external URLs:

```erb
<%= opt_image_url(photo) %>
<!-- Works for both external and ActiveStorage images -->
```

## Benefits

1. **No Storage Used**: Seed images don't consume R2/disk quota
2. **Fast Seeding**: No file uploads, just database inserts
3. **Easy Cleanup**: Deleting seeded properties leaves no orphan blobs
4. **Shared Images**: Multiple tenants can reference the same seed images
5. **CDN Performance**: R2 provides edge caching for seed images

## Fallback Behavior

When `SEED_IMAGES_BASE_URL` is not set:

1. Seeds check for local files in `db/seeds/images/`
2. If found, images are attached via ActiveStorage (legacy behavior)
3. If not found, a warning is logged

This ensures development works without R2 configuration.

## Image Requirements

Seed images should be:
- JPEG format (`.jpg`)
- Reasonable size (800-1200px wide)
- Optimized for web (compressed)
- Royalty-free (we use Unsplash images)

## Adding New Seed Images

1. Add the image file to `db/seeds/images/`
2. Upload to R2 bucket under `seed-images/` prefix
3. Add mapping to `config/seed_images.yml`
4. Reference in seed files by filename
