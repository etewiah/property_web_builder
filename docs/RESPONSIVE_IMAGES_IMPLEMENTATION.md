# Responsive Images Implementation

## Overview

This document describes the implementation of responsive images for PropertyWebBuilder. The system automatically generates and delivers optimized image variants at multiple sizes and formats for optimal performance across all devices.

## Architecture

### Core Components

1. **`Pwb::ResponsiveVariants`** (`lib/pwb/responsive_variants.rb`)
   - Centralized configuration for breakpoints, formats, and size presets
   - Tailwind CSS-aligned widths: `[320, 640, 768, 1024, 1280, 1536, 1920]`
   - Formats: AVIF (if supported), WebP, JPEG
   - Named size presets: `:hero`, `:card`, `:thumbnail`, `:content`, etc.

2. **`Pwb::ResponsiveVariantGenerator`** (`app/services/pwb/responsive_variant_generator.rb`)
   - Service for generating all responsive variants for an image
   - Handles width/format combinations based on original image size
   - Builds srcset strings for use in templates

3. **`Pwb::ImageVariantGeneratorJob`** (`app/jobs/pwb/image_variant_generator_job.rb`)
   - Background job for pre-generating variants on upload
   - Supports PropPhoto, ContentPhoto, WebsitePhoto models
   - Automatic retry with exponential backoff

4. **`ResponsiveVariantSupport`** (`app/models/concerns/responsive_variant_support.rb`)
   - Model concern that triggers variant generation on image upload
   - Included in PropPhoto, ContentPhoto, WebsitePhoto

5. **`Pwb::ImagesHelper`** (`app/helpers/pwb/images_helper.rb`)
   - `responsive_image_tag` - Generates `<picture>` elements with multiple sources
   - `make_media_responsive` - Upgrades existing HTML content to use responsive images
   - `generate_responsive_srcset` - Builds srcset strings for any format

## Usage

### In Views - The Recommended Approach

Use `responsive_image_tag` for all property and content images:

```erb
<%# Property card - uses :card size preset %>
<%= responsive_image_tag @property.primary_photo, sizes: :card, alt: @property.title %>

<%# Hero image - above the fold, loaded eagerly %>
<%= responsive_image_tag @property.primary_photo, sizes: :hero, eager: true %>

<%# Thumbnail in search results %>
<%= responsive_image_tag photo, sizes: :thumbnail, class: "rounded" %>

<%# Custom sizes string %>
<%= responsive_image_tag photo, sizes: "(min-width: 800px) 400px, 100vw" %>
```

### Available Size Presets

| Preset | Sizes Attribute | Use Case |
|--------|----------------|----------|
| `:hero` | `(min-width: 1280px) 1280px, 100vw` | Full-width hero images |
| `:card` | `(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw` | Property cards in grids |
| `:card_sm` | `(min-width: 1280px) 300px, ...` | Smaller card grids |
| `:thumbnail` | `(min-width: 768px) 200px, 150px` | List view thumbnails |
| `:content` | `(min-width: 848px) 800px, calc(100vw - 48px)` | Article/page content |
| `:featured` | `(min-width: 1280px) 600px, ...` | Featured property cards |

### Generated HTML

The helper generates semantic `<picture>` elements:

```html
<picture>
  <source srcset="image-320w.avif 320w, image-640w.avif 640w, ..."
          sizes="(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw"
          type="image/avif">
  <source srcset="image-320w.webp 320w, image-640w.webp 640w, ..."
          sizes="(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw"
          type="image/webp">
  <img src="original.jpg"
       srcset="image-320w.jpg 320w, image-640w.jpg 640w, ..."
       sizes="(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw"
       alt="Property photo"
       loading="lazy"
       decoding="async">
</picture>
```

### Legacy Content Migration

For existing HTML content (page parts, articles), use `make_media_responsive`:

```ruby
# In PagePartManager or migration service
html = make_media_responsive(raw_html, sizes: :content)
```

This upgrades `<img>` tags to `<picture>` elements for trusted sources.

## Automatic Variant Generation

### How It Works

1. **On Upload**: When a photo is created/updated with a new image, the `ResponsiveVariantSupport` concern schedules `ImageVariantGeneratorJob`

2. **Background Processing**: The job generates variants at all configured widths and formats

3. **On Request**: When variants are requested via srcset, ActiveStorage serves pre-generated variants (or generates on-demand if needed)

### Manual Generation

```ruby
# Generate variants for a single photo
photo = Pwb::PropPhoto.find(123)
photo.generate_responsive_variants!

# Or use the service directly
generator = Pwb::ResponsiveVariantGenerator.new(photo.image)
generator.generate_all!
```

### Backfill Existing Images

Use the rake tasks to generate variants for existing records:

```bash
# Generate for all photo models
bundle exec rake images:variants:generate_all

# Generate for specific model
bundle exec rake images:variants:prop_photos
bundle exec rake images:variants:content_photos
bundle exec rake images:variants:website_photos

# Generate for single record
bundle exec rake images:variants:single MODEL=Pwb::PropPhoto ID=123

# View statistics
bundle exec rake images:variants:stats
```

## Configuration

### Format Support

- **WebP**: Always generated (97%+ browser support)
- **JPEG**: Always generated as fallback
- **AVIF**: Generated if libvips 8.9+ supports it (~87% browser support)

Check AVIF support:
```ruby
Pwb::ResponsiveVariants.avif_supported?
# => true/false
```

### Width Configuration

Widths are defined in `Pwb::ResponsiveVariants::WIDTHS`:
```ruby
[320, 640, 768, 1024, 1280, 1536, 1920]
```

Variants larger than the original image are not generated.

### Quality Settings

| Format | Quality | Notes |
|--------|---------|-------|
| AVIF | 65 | Best compression |
| WebP | 80 | Good balance |
| JPEG | 85 | High quality fallback |

## Testing

```bash
# Run responsive image specs
bundle exec rspec spec/lib/pwb/responsive_variants_spec.rb
bundle exec rspec spec/helpers/pwb/images_helper_responsive_spec.rb
bundle exec rspec spec/services/pwb/responsive_variant_generator_spec.rb
```

## Comparison with docs/images Specification

This implementation aligns more closely with the `docs/images` architecture:

| Feature | docs/images Spec | Current Implementation |
|---------|------------------|----------------------|
| Configuration | `Pwb::ResponsiveVariants` module | ✅ Implemented |
| Breakpoints | Tailwind-aligned widths | ✅ `[320, 640, 768, 1024, 1280, 1536, 1920]` |
| Formats | AVIF, WebP, JPEG | ✅ All three (AVIF if supported) |
| Size Presets | Named presets | ✅ `:hero`, `:card`, `:thumbnail`, etc. |
| Background Generation | Job-based | ✅ `ImageVariantGeneratorJob` |
| Model Integration | Concern-based | ✅ `ResponsiveVariantSupport` |
| Helper API | `responsive_image_tag` | ✅ Implemented |

## Performance Considerations

1. **Lazy Loading**: All images use `loading="lazy"` by default
2. **Async Decoding**: Uses `decoding="async"` for non-blocking decode
3. **Above-fold Images**: Use `eager: true` for LCP images
4. **Pre-generation**: Variants are generated in background on upload
5. **Format Negotiation**: Browser automatically picks best supported format
