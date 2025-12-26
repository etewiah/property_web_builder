# Responsive Image Variants Reference

This document defines the breakpoints, widths, and quality settings for responsive image generation.

## Breakpoint Definitions

### Tailwind CSS Alignment

Our breakpoints align with Tailwind CSS defaults used in PropertyWebBuilder themes:

| Breakpoint | Min Width | CSS Class | Common Devices |
|------------|-----------|-----------|----------------|
| `xs` | 0px | (default) | Small phones |
| `sm` | 640px | `sm:` | Large phones |
| `md` | 768px | `md:` | Tablets portrait |
| `lg` | 1024px | `lg:` | Tablets landscape, laptops |
| `xl` | 1280px | `xl:` | Desktops |
| `2xl` | 1536px | `2xl:` | Large desktops |

## Image Width Matrix

### Standard Widths

Generated for every uploaded image:

| Width | DPR | Use Case |
|-------|-----|----------|
| 320px | 1x | Small mobile |
| 640px | 1x / 2x@320 | Mobile / Retina small |
| 768px | 1x | Tablet portrait |
| 1024px | 1x / 2x@512 | Tablet landscape |
| 1280px | 1x / 2x@640 | Desktop |
| 1536px | 2x@768 | Retina tablet |
| 1920px | 1x | Large desktop / Hero |
| 2048px | 2x@1024 | Retina laptop |
| 2560px | 2x@1280 | Retina desktop |

### Configuration

```ruby
# lib/pwb/responsive_variants.rb

module Pwb
  module ResponsiveVariants
    # All unique widths to generate
    WIDTHS = [320, 640, 768, 1024, 1280, 1536, 1920, 2048, 2560].freeze

    # Widths by breakpoint with DPR consideration
    BREAKPOINT_WIDTHS = {
      xs:  { widths: [320], max_content: 320 },
      sm:  { widths: [640, 1280], max_content: 640 },
      md:  { widths: [768, 1536], max_content: 768 },
      lg:  { widths: [1024, 2048], max_content: 1024 },
      xl:  { widths: [1280, 2560], max_content: 1280 },
      xxl: { widths: [1920], max_content: 1920 }
    }.freeze

    # Don't generate variants larger than original
    def self.widths_for(original_width)
      WIDTHS.select { |w| w <= original_width }
    end
  end
end
```

## Format Settings

### Supported Formats

| Format | Extension | MIME Type | Quality | Notes |
|--------|-----------|-----------|---------|-------|
| AVIF | `.avif` | `image/avif` | 65 | Best compression, newer browsers |
| WebP | `.webp` | `image/webp` | 80 | Good compression, wide support |
| JPEG | `.jpg` | `image/jpeg` | 85 | Universal fallback |

### Format Configuration

```ruby
module Pwb
  module ResponsiveVariants
    FORMATS = {
      avif: {
        format: :avif,
        saver: { quality: 65, effort: 4 },
        mime_type: 'image/avif',
        browser_support: '~87%'  # As of 2024
      },
      webp: {
        format: :webp,
        saver: { quality: 80 },
        mime_type: 'image/webp',
        browser_support: '~97%'
      },
      jpeg: {
        format: :jpeg,
        saver: { quality: 85, progressive: true },
        mime_type: 'image/jpeg',
        browser_support: '100%'
      }
    }.freeze

    # Formats to generate (in order of preference)
    GENERATE_FORMATS = [:webp, :jpeg].freeze

    # Include AVIF if libvips supports it
    def self.formats_to_generate
      if avif_supported?
        [:avif] + GENERATE_FORMATS
      else
        GENERATE_FORMATS
      end
    end

    def self.avif_supported?
      defined?(Vips) && Vips.at_least_libvips?(8, 9)
    end
  end
end
```

## Size Presets

### Predefined `sizes` Attributes

Use these presets for common layouts:

```ruby
module Pwb
  module ResponsiveVariants
    SIZE_PRESETS = {
      # Full-width hero images
      hero: "(min-width: 1280px) 1280px, 100vw",

      # Property cards in grid
      # 3 columns on xl, 2 on md, 1 on mobile
      card: "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw",

      # Property cards in 4-column grid
      card_sm: "(min-width: 1280px) 300px, (min-width: 1024px) 25vw, (min-width: 768px) 50vw, 100vw",

      # Thumbnail in list view
      thumbnail: "(min-width: 768px) 200px, 150px",

      # Small thumbnail (search results sidebar)
      thumbnail_sm: "100px",

      # Gallery lightbox (full viewport)
      lightbox: "100vw",

      # Content images in articles (max 800px container)
      content: "(min-width: 848px) 800px, calc(100vw - 48px)",

      # Logo/branding (fixed size)
      logo: "200px",

      # Featured property (larger card)
      featured: "(min-width: 1280px) 600px, (min-width: 768px) 50vw, 100vw"
    }.freeze

    def self.sizes_for(preset)
      SIZE_PRESETS[preset.to_sym] || SIZE_PRESETS[:card]
    end
  end
end
```

### Usage Examples

```erb
<%# Hero image - full width %>
<%= responsive_image_tag @property.primary_photo, sizes: :hero, eager: true %>

<%# Property card in grid %>
<%= responsive_image_tag @property.primary_photo, sizes: :card %>

<%# Thumbnail in search results %>
<%= responsive_image_tag @property.primary_photo, sizes: :thumbnail %>

<%# Custom sizes string %>
<%= responsive_image_tag @photo, sizes: "(min-width: 600px) 300px, 100vw" %>
```

## Aspect Ratio Presets

### Common Property Photo Ratios

```ruby
module Pwb
  module ResponsiveVariants
    ASPECT_RATIOS = {
      # Landscape (most property photos)
      landscape_16_9: { width: 16, height: 9 },
      landscape_4_3:  { width: 4, height: 3 },
      landscape_3_2:  { width: 3, height: 2 },

      # Portrait
      portrait_9_16: { width: 9, height: 16 },
      portrait_3_4:  { width: 3, height: 4 },

      # Square
      square: { width: 1, height: 1 },

      # Property listing standard
      property: { width: 4, height: 3 }
    }.freeze

    # Calculate height for given width and ratio
    def self.height_for(width:, ratio:)
      aspect = ASPECT_RATIOS[ratio.to_sym]
      return nil unless aspect

      (width * aspect[:height] / aspect[:width]).round
    end
  end
end
```

## Variant Naming Convention

### URL Structure

Variants are stored with predictable names for caching:

```
/rails/active_storage/representations/redirect/
  [signed_blob_id]/
  [signed_variation_key]/
  [filename]

# Example variant keys:
resize_to_limit_640_nil_format_webp_saver_quality_80
resize_to_limit_1024_nil_format_avif_saver_quality_65
```

### Cache Keys

```ruby
# Variant cache key includes:
# - Blob ID
# - Transformation parameters
# - Format

def variant_cache_key(width, format)
  [
    blob.key,
    "w#{width}",
    format.to_s
  ].join("-")
end
```

## Storage Estimates

### Per-Image Storage

| Original Size | Variants Generated | Estimated Storage |
|--------------|-------------------|-------------------|
| 500KB JPEG | 14 (7 widths x 2 formats) | ~1.5MB |
| 2MB JPEG | 18 (9 widths x 2 formats) | ~4MB |
| 5MB JPEG | 18 (9 widths x 2 formats) | ~8MB |

### Calculation Formula

```ruby
def estimate_storage(original_size_kb, original_width)
  widths = ResponsiveVariants.widths_for(original_width)
  formats = ResponsiveVariants.formats_to_generate

  total = 0
  widths.each do |w|
    scale = w.to_f / original_width
    formats.each do |f|
      # Rough compression ratios vs original JPEG
      ratio = case f
              when :avif then 0.4
              when :webp then 0.6
              when :jpeg then 0.8
              end
      total += original_size_kb * scale * scale * ratio
    end
  end

  total.round
end
```

## Browser Support Reference

### Format Support (as of December 2024)

| Format | Chrome | Firefox | Safari | Edge | iOS Safari |
|--------|--------|---------|--------|------|------------|
| AVIF | 85+ | 93+ | 16.4+ | 121+ | 16.4+ |
| WebP | 32+ | 65+ | 14+ | 18+ | 14+ |
| JPEG | All | All | All | All | All |

### Feature Detection

```html
<!-- Picture element handles format negotiation automatically -->
<picture>
  <source srcset="image.avif" type="image/avif">
  <source srcset="image.webp" type="image/webp">
  <img src="image.jpg" alt="...">
</picture>

<!-- Browser automatically selects best supported format -->
```

## Configuration Reference

### Environment Variables

```bash
# Enable/disable AVIF generation (auto-detected by default)
ENABLE_AVIF_VARIANTS=true

# Maximum variant width (don't generate larger)
MAX_VARIANT_WIDTH=2560

# Variant generation concurrency
VARIANT_JOB_CONCURRENCY=2

# Quality overrides (0-100)
VARIANT_QUALITY_AVIF=65
VARIANT_QUALITY_WEBP=80
VARIANT_QUALITY_JPEG=85
```

### Rails Configuration

```ruby
# config/initializers/responsive_images.rb

Pwb::ResponsiveVariants.configure do |config|
  config.widths = [320, 640, 768, 1024, 1280, 1920]
  config.formats = [:webp, :jpeg]
  config.enable_avif = ENV.fetch('ENABLE_AVIF_VARIANTS', 'auto')

  config.quality = {
    avif: ENV.fetch('VARIANT_QUALITY_AVIF', 65).to_i,
    webp: ENV.fetch('VARIANT_QUALITY_WEBP', 80).to_i,
    jpeg: ENV.fetch('VARIANT_QUALITY_JPEG', 85).to_i
  }
end
```
