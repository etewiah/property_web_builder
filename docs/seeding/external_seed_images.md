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

### Environment Variable

Set the base URL for seed images:

```bash
# In your .env or environment
SEED_IMAGES_BASE_URL=https://pub-pwb-seed-images.r2.dev/seed-images
```

If this variable is not set, the system falls back to attaching local files from `db/seeds/images/`.

### Config File

The image mappings are defined in `config/seed_images.yml`:

```yaml
default: &default
  base_url: <%= ENV.fetch('SEED_IMAGES_BASE_URL', 'https://pub-pwb-seed-images.r2.dev/seed-images') %>

  properties:
    apartment_downtown: apartment_downtown.jpg
    apartment_luxury: apartment_luxury.jpg
    villa_ocean: villa_ocean.jpg
    # ... more mappings

  content:
    hero_amsterdam_canal: hero_amsterdam_canal.jpg
    # ... hero/carousel images

  team:
    team_director: team_director.jpg
    # ... team member photos
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

## Setting Up R2 Bucket

### 1. Create Public R2 Bucket

In Cloudflare Dashboard:
1. Go to R2 > Create Bucket
2. Name it `pwb-seed-images` (or similar)
3. Enable public access (Settings > Public Access)

### 2. Upload Seed Images

Upload all images from `db/seeds/images/` to the bucket under a `seed-images/` prefix:

```
pwb-seed-images/
  seed-images/
    apartment_downtown.jpg
    apartment_luxury.jpg
    house_family.jpg
    ...
```

### 3. Configure Public URL

Get the public URL from R2 settings. It will look like:
```
https://pub-{account-id}.r2.dev
```

Set the full base URL in your environment:
```bash
SEED_IMAGES_BASE_URL=https://pub-{account-id}.r2.dev/seed-images
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
