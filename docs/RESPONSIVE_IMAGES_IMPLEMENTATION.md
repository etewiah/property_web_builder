# Responsive Images Implementation

## Overview

This document describes the implementation of responsive images for PropertyWebBuilder. The system automatically generates and delivers optimized image variants at multiple sizes and formats for optimal performance across all devices.

## Architecture

### Core Components

1. **`Pwb::ResponsiveVariants`** (`lib/pwb/responsive_variants.rb`)
   - Centralized configuration for breakpoints, formats, and size presets
   - Tailwind CSS-aligned widths: `[320, 640, 1024, 1280]`
`
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

### External vs Local Images

**Important:** Variant generation only applies to **local ActiveStorage attachments** (uploaded files). 
Images referenced via `external_url` (like default seed data pointing to `seed-assets.propertywebbuilder.com`) are **skipped** by the generator. 

For external images:
- The system assumes the external host provides optimized versions if configured (see `trusted_webp_source?` in `ImagesHelper`).
- No local processing/resizing occurs.
- If variants are missing on the external host, 404s may occur for `<source>` tags, falling back to the original `<img>`.

## Maintenance Tasks

### Repair Nested Picture Tags

If content migration was run multiple times or on already-responsive content (prior to idempotency fixes), HTML might contain nested `<picture>` tags. Use this task to stripping outer wrappers and regenerate clean HTML:

```bash
bundle exec rake images:fix_nested_pictures
```


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
| Breakpoints | Tailwind-aligned widths | ✅ `[320, 640, 1024, 1280]` |
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

## Troubleshooting

If you encounter issues with images not loading, 500 errors, or missing variants, follow these steps.

### Automated Troubleshooting

Run the included troubleshooting suite to check configuration, dependencies, and database content:

```bash
bundle exec rake images:troubleshoot:all
```

This will verify:
1.  **Dependencies**: Checks if `vips` or `mini_magick` is correctly installed and matched with Rails config.
2.  **Configuration**: Checks if `default_url_options` and `ActiveStorage::SetCurrent` are configured.
3.  **HTML Structure**: Scans content for proper `<picture>` tags.
4.  **URL Generation**: Attempts to generate a test variant URL.

### Common Issues & Fixes

#### 1. `LoadError: Could not open library 'libvips'`

**Symptom**: 500 Error when loading pages with images; logs show `ActiveStorage::UnknownVariant` or `LoadError`.

**Cause**: Rails 8 defaults to Vips, but it may not be installed on your system.

**Fix**:
Switch to MiniMagick (which uses ImageMagick) if Vips is not available.

*config/application.rb* or *config/environments/development.rb*:
```ruby
config.active_storage.variant_processor = :mini_magick
```
Ensure `mini_magick` gem is in your Gemfile:
```ruby
gem "mini_magick"
```

#### 2. `ArgumentError: Cannot generate URL ... please set ActiveStorage::Current.url_options`

**Symptom**: API requests or background jobs fail to generate image URLs.

**Cause**: ActiveStorage needs to know the domain/host to generate absolute URLs, and this info is missing in API/non-browser contexts.

**Fix**:
1. Set default URL options in `config/environments/development.rb`:
   ```ruby
   Rails.application.routes.default_url_options = { host: "localhost", port: 3000 }
   ```
2. Include the setup module in your API base controller:
   ```ruby
   # app/controllers/api_public/v1/base_controller.rb
   include ActiveStorage::SetCurrent
   ```

#### 3. `The provided transformation method is not supported: saver`

**Symptom**: `images:variants:generate` fails with this error.

**Cause**: You are using MiniMagick, but the code is trying to use Vips-specific options (like `saver: { quality: ... }`).

**Fix**:
Ensure `Pwb::ResponsiveVariants.transformations_for` handles the processor type correctly. (This is patched in the current codebase).

#### 4. Corrupted/Nested Picture Tags

**Symptom**: HTML shows `<picture><picture>...</picture></picture>`.

**Cause**: Content migration ran multiple times on already-processed content.

**Fix**:
Run the cleanup task:
```bash
bundle exec rake images:fix_nested_pictures
```

#### 5. External Images Not Responsive

**Symptom**: Images from external URLs (e.g. `seed-assets`) are still regular `<img>` tags.

**Cause**: Variant generation only works for local ActiveStorage attachments.

**Fix**:
Import external images to local storage:
```bash
bundle exec rake images:import_external
```

## Maintenance Tasks

### Reprocessing Content

If responsive image logic changes (e.g., new breakpoints or logic updates), you can reprocess all existing content blocks in the database using the provided rake task:

```bash
bundle exec rake pwb:content:reprocess_responsive
```

This task:
1. Iterates through all `Pwb::Content` records.
2. Checks all localized `raw_*` fields (e.g., `raw_en`, `raw_es`).
3. Runs the content through `make_media_responsive`.
4. Updates the record only if the HTML has changed (e.g., new `srcset`, updated `sizes`).
5. Handles `Mobility` translations correctly.

