# Seed Image Optimization

This document describes how to optimize seed images for PropertyWebBuilder to reduce file sizes and improve page load performance.

## Overview

Seed images are used for demo data, testing, and initial website setup. Optimized images provide:

- **Faster seeding** - Smaller files upload more quickly to R2
- **Better performance** - Reduced bandwidth for demo sites
- **WebP support** - Modern format with ~30-50% smaller file sizes
- **Consistent quality** - Standardized dimensions and compression

## Image Specifications

### Target Dimensions by Category

| Category | Max Width | Max Height | Quality | Use Case |
|----------|-----------|------------|---------|----------|
| Property | 1200px | 800px | 82% | Listing cards, search results |
| Hero | 1600px | 1067px | 80% | Homepage hero sections |
| Team | 600px | 800px | 85% | Team member photos |
| Content | 1200px | 800px | 82% | About pages, general content |

### Format Support

- **JPEG** - Primary format, progressive encoding
- **WebP** - Optional, ~30-50% smaller than JPEG

## Optimization Rake Tasks

### View Current Status

```bash
# Report on all seed images with sizes
rails seed_images:report
```

Example output:
```
======================================================================
Seed Image Report
======================================================================

Property: db/seeds/images
------------------------------------------------------------
  apartment_downtown.jpg                 800x533  57.2 KB  WebP: 33.7 KB
  villa_ocean.jpg                        800x533  72.3 KB  WebP: 45.2 KB
  ...

Totals
======================================================================
JPEG files: 23 (total: 2.4 MB)
WebP files: 23 (total: 1.6 MB)
WebP savings: 770.6 KB (31.3%)
======================================================================
```

### Optimize All Images

```bash
# Full optimization: compress JPEGs + generate WebP
rails seed_images:optimize
```

This command:
1. Resizes images that exceed target dimensions
2. Compresses JPEGs with optimal quality settings
3. Strips metadata (EXIF, color profiles)
4. Applies progressive encoding
5. Generates WebP versions of all images

### Individual Tasks

```bash
# Compress JPEGs only (no WebP)
rails seed_images:optimize_jpeg

# Generate WebP versions only
rails seed_images:generate_webp

# Remove all WebP files
rails seed_images:clean_webp
```

## Requirements

The optimization tasks require:

- **ImageMagick 7+** - For JPEG processing
- **cwebp** - For WebP generation (from libwebp)

Install on macOS:
```bash
brew install imagemagick webp
```

Install on Ubuntu/Debian:
```bash
apt-get install imagemagick webp
```

## Using WebP in Seeds

The `Pwb::SeedImages` helper supports WebP format:

```ruby
# Get JPEG URL (default)
Pwb::SeedImages.property_url('villa_ocean')
# => "https://seed-assets.propertywebbuilder.com/seeds/villa_ocean.jpg"

# Get WebP URL
Pwb::SeedImages.property_url('villa_ocean', format: :webp)
# => "https://seed-assets.propertywebbuilder.com/seeds/villa_ocean.webp"

# Get both formats for <picture> element
Pwb::SeedImages.urls_for_picture(:properties, 'villa_ocean')
# => { jpg: "...villa_ocean.jpg", webp: "...villa_ocean.webp" }
```

## Using WebP in Views

For optimal browser support, use the `<picture>` element:

```erb
<picture>
  <source srcset="<%= image_url.sub('.jpg', '.webp') %>" type="image/webp">
  <img src="<%= image_url %>" alt="Property photo" loading="lazy">
</picture>
```

The browser will:
1. Use WebP if supported (Chrome, Firefox, Edge, Safari 14+)
2. Fall back to JPEG for older browsers

## Uploading to R2

After optimization, upload both JPEG and WebP files:

```bash
# Upload new files (skip existing)
rails pwb:seed_images:upload

# Upload all files (overwrite existing)
rails pwb:seed_images:upload_all

# List files in R2
rails pwb:seed_images:list_remote
```

## Adding New Images

When adding new seed images:

1. Add the source image to the appropriate directory:
   - `db/seeds/images/` - Base seed images
   - `db/seeds/packs/PACK_NAME/images/` - Pack-specific images

2. Run optimization:
   ```bash
   rails seed_images:optimize
   ```

3. Update config if needed (`config/seed_images.yml`)

4. Upload to R2:
   ```bash
   rails pwb:seed_images:upload
   ```

## Image Sources

All seed images should be royalty-free. Recommended sources:

- [Unsplash](https://unsplash.com) - Free high-resolution photos
- [Pexels](https://pexels.com) - Free stock photos
- [Pixabay](https://pixabay.com) - Free images and videos

When downloading, choose images that are:
- Landscape orientation (for property photos)
- At least 1200px wide
- High quality (not overly compressed)

## Optimization Results

Typical optimization results:

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| Total JPEG size | 3.1 MB | 2.4 MB | 22% |
| Total WebP size | - | 1.6 MB | 48% |
| Average property image | 100 KB | 70 KB | 30% |
| Average team photo | 85 KB | 40 KB | 53% |

## Troubleshooting

### ImageMagick Not Found

```
ERROR: ImageMagick 7+ is required. Install with: brew install imagemagick
```

Solution: Install ImageMagick 7.x (uses `magick` command, not `convert`)

### cwebp Not Found

```
ERROR: cwebp is required for WebP generation. Install with: brew install webp
```

Solution: Install libwebp package

### Images Not Resizing

Images are only resized if they exceed target dimensions. The optimizer never enlarges images.

### WebP Files Not Generating

Check that source JPEGs exist and cwebp is installed:
```bash
which cwebp
cwebp -version
```
