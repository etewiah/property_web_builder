# Responsive Images for Seed Data

This document describes the responsive image system used for seed images and hero backgrounds.

## Overview

To improve mobile performance (especially Largest Contentful Paint - LCP), seed images are generated in multiple sizes:
- **400w** - For mobile devices (< 640px viewport)
- **800w** - For tablets and small laptops (640px-1024px viewport)
- **1200w** - Original size for desktop (> 1024px viewport)

This reduces image transfer size on mobile from ~120KB to ~17KB (85% reduction).

## Quick Start for New Developers

After cloning the repository:

```bash
# Check dependencies and generate responsive images
bundle exec rake seed_images:setup
```

This will:
1. Check for ImageMagick and cwebp (install with `brew install imagemagick webp`)
2. Generate responsive image variants if missing
3. Optionally upload to R2 CDN if credentials are configured

## File Naming Convention

Responsive variants follow this pattern:
```
{original_name}-{width}.{ext}

Examples:
  carousel_villa_with_pool.webp        (original - 1200w)
  carousel_villa_with_pool-800.webp    (800w variant)
  carousel_villa_with_pool-400.webp    (400w variant)
```

## Rake Tasks

### Generate responsive variants

```bash
bundle exec rake seed_images:generate_responsive
```

Generates 400w and 800w variants for all images in:
- `db/example_images/` (hero and carousel images)
- `db/seeds/packs/*/images/` (seed pack images)

### Clean up responsive variants

```bash
bundle exec rake seed_images:clean_responsive
```

Removes all generated responsive variants.

### Report image sizes

```bash
bundle exec rake seed_images:report
```

Shows current image sizes and WebP savings.

### Sync to R2 CDN

```bash
bundle exec rake seed_images:sync_to_r2
```

Uploads all seed images (including responsive variants) to R2 CDN.

## How It Works in Templates

### Hero Liquid Templates

Hero templates use `srcset` to serve appropriate image sizes:

```liquid
{% assign hero_img = page_part.background_image.content %}
{% assign hero_img_400 = hero_img | replace: '.webp', '-400.webp' %}
{% assign hero_img_800 = hero_img | replace: '.webp', '-800.webp' %}

<img src="{{ hero_img }}"
     srcset="{{ hero_img_400 }} 400w, {{ hero_img_800 }} 800w, {{ hero_img }} 1200w"
     sizes="100vw"
     width="1200"
     height="800"
     fetchpriority="high">
```

### LCP Preload in Layouts

Theme layouts preload the LCP image with responsive srcset:

```erb
<% if @lcp_image_url.present? %>
  <% lcp_400 = @lcp_image_url.gsub(/\.(webp|jpg)$/, '-400.\1') %>
  <% lcp_800 = @lcp_image_url.gsub(/\.(webp|jpg)$/, '-800.\1') %>
  <link rel="preload"
        href="<%= @lcp_image_url %>"
        as="image"
        fetchpriority="high"
        imagesrcset="<%= lcp_400 %> 400w, <%= lcp_800 %> 800w, <%= @lcp_image_url %> 1200w"
        imagesizes="100vw">
<% end %>
```

## Dependencies

- **ImageMagick 7+** - For JPEG resizing (`brew install imagemagick`)
- **cwebp** - For WebP generation and resizing (`brew install webp`)

## R2 CDN Configuration (Optional)

For production, images are served from Cloudflare R2. Configure with environment variables:

```bash
R2_ACCESS_KEY_ID=your_key
R2_SECRET_ACCESS_KEY=your_secret
R2_ACCOUNT_ID=your_account
R2_SEED_IMAGES_BUCKET=seed-images
```

## Testing

Run the responsive image tests:

```bash
bundle exec rspec spec/lib/tasks/seed_images_optimize_spec.rb
```

## Performance Impact

Before responsive images:
- Mobile LCP: 3.3s (118KB image)
- Lighthouse Performance: 90

After responsive images:
- Mobile LCP: ~2.5s (17KB image on mobile)
- Expected Lighthouse improvement: +5-10 points

## Adding New Seed Images

1. Add the original image (1200px wide recommended) to `db/example_images/`
2. Run `bundle exec rake seed_images:generate_responsive`
3. Run `bundle exec rake seed_images:sync_to_r2` (if using CDN)
4. Commit all variants to git
