# Mobile-Optimized Image Processing - Technical Specification

**Version:** 1.0
**Status:** Proposed
**Last Updated:** 2024-12-26

## Executive Summary

This specification defines the implementation plan for automatic mobile-optimized image generation in PropertyWebBuilder. The goal is to serve appropriately-sized images based on device viewport, reducing bandwidth usage by 40-60% on mobile devices while maintaining visual quality.

---

## Table of Contents

1. [Goals & Objectives](#goals--objectives)
2. [Current State Analysis](#current-state-analysis)
3. [Proposed Architecture](#proposed-architecture)
4. [Responsive Breakpoints](#responsive-breakpoints)
5. [Image Format Strategy](#image-format-strategy)
6. [Variant Generation Pipeline](#variant-generation-pipeline)
7. [Helper Methods](#helper-methods)
8. [Storage & CDN Considerations](#storage--cdn-considerations)
9. [Performance Targets](#performance-targets)
10. [Migration Strategy](#migration-strategy)
11. [Testing Requirements](#testing-requirements)
12. [Rollout Plan](#rollout-plan)

---

## 1. Goals & Objectives

### Primary Goals

1. **Reduce mobile bandwidth** - Serve images sized for device viewport
2. **Improve Core Web Vitals** - Better LCP scores through optimized images
3. **Automatic optimization** - No manual intervention required per image
4. **Format modernization** - Serve WebP/AVIF with JPEG fallback

### Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Mobile image payload | ~2.5MB avg | <800KB |
| LCP (mobile) | ~3.5s | <2.5s |
| Image format adoption | 30% WebP | 95% modern formats |
| Variant cache hit rate | N/A | >90% |

### Non-Goals

- Real-time image transformation (CDN-based)
- User-uploaded image editing/cropping UI
- Video optimization (separate initiative)

---

## 2. Current State Analysis

### Existing Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│                    Current Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Upload → ActiveStorage → R2/Local → On-demand Variants     │
│                                                              │
│  Variants: thumb (150x), small (300x), medium (600x),       │
│            large (1200x)                                     │
│                                                              │
│  Formats: Original format preserved, WebP optional          │
│                                                              │
│  Delivery: Direct R2 URLs, no srcset                        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Current Limitations

| Limitation | Impact | Priority |
|------------|--------|----------|
| No srcset/sizes | Mobile downloads full-size images | Critical |
| On-demand variants | First request slow, cold cache | High |
| Manual WebP | Developers must specify format | Medium |
| Fixed breakpoints | Don't match CSS breakpoints | Medium |
| No AVIF | Missing 30% additional savings | Low |

### Affected Models

| Model | Image Field | Usage | Priority |
|-------|-------------|-------|----------|
| `Pwb::PropPhoto` | `image` | Property listings | Critical |
| `Pwb::ContentPhoto` | `image` | Page content | High |
| `Pwb::WebsitePhoto` | `image` | Logos, branding | Medium |
| `Pwb::Media` | `file` | Media library | Medium |

---

## 3. Proposed Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                   Proposed Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Upload                                                      │
│    │                                                         │
│    ▼                                                         │
│  ActiveStorage ──────────────────────────────────┐          │
│    │                                             │          │
│    ▼                                             ▼          │
│  ImageVariantGeneratorJob              Metadata Extraction  │
│    │                                             │          │
│    ├── xs (320w) ─┐                              │          │
│    ├── sm (640w)  │                              │          │
│    ├── md (768w)  ├── WebP + AVIF + JPEG         │          │
│    ├── lg (1024w) │                              │          │
│    ├── xl (1280w) │                              │          │
│    └── xxl (1920w)┘                              │          │
│          │                                       │          │
│          ▼                                       ▼          │
│    Cloudflare R2 ◄───────────────────── variant_records     │
│          │                                                   │
│          ▼                                                   │
│    responsive_image_tag                                      │
│          │                                                   │
│          ▼                                                   │
│    <picture>                                                 │
│      <source srcset="...avif" type="image/avif">            │
│      <source srcset="...webp" type="image/webp">            │
│      <img srcset="...jpg" sizes="..." loading="lazy">       │
│    </picture>                                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Responsibility | New/Modified |
|-----------|---------------|--------------|
| `ResponsiveVariants` | Define breakpoints & transforms | New |
| `ImageVariantGeneratorJob` | Background variant generation | New |
| `responsive_image_tag` | Generate picture/img markup | New |
| `opt_image_tag` | Enhanced with srcset support | Modified |
| `PropPhoto` | Trigger variant generation | Modified |

---

## 4. Responsive Breakpoints

### Breakpoint Definitions

Based on Tailwind CSS defaults (used in themes) and common device widths:

| Name | Width | Target Devices | DPR Variants |
|------|-------|----------------|--------------|
| `xs` | 320px | Small phones | 1x |
| `sm` | 640px | Large phones, small tablets | 1x, 2x |
| `md` | 768px | Tablets portrait | 1x, 2x |
| `lg` | 1024px | Tablets landscape, laptops | 1x, 2x |
| `xl` | 1280px | Desktops | 1x, 2x |
| `xxl` | 1920px | Large desktops, retina | 1x |

### Width Calculations

For responsive images, we generate variants at these pixel widths:

```ruby
RESPONSIVE_WIDTHS = {
  xs:  [320],
  sm:  [640, 1280],      # 1x, 2x for retina
  md:  [768, 1536],      # 1x, 2x for retina
  lg:  [1024, 2048],     # 1x, 2x for retina
  xl:  [1280, 2560],     # 1x, 2x for retina
  xxl: [1920]            # Max size, no 2x needed
}

# Flattened unique widths for variant generation
ALL_WIDTHS = [320, 640, 768, 1024, 1280, 1536, 1920, 2048, 2560]
```

### Context-Specific Sizes

Different contexts need different size hints:

```ruby
SIZE_PRESETS = {
  # Full-width hero images
  hero: "(min-width: 1280px) 1280px, (min-width: 768px) 100vw, 100vw",

  # Property cards in grid (3 columns on desktop)
  card: "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw",

  # Thumbnail in list view
  thumbnail: "(min-width: 768px) 200px, 150px",

  # Gallery lightbox
  lightbox: "100vw",

  # Content images (max 800px container)
  content: "(min-width: 800px) 800px, 100vw"
}
```

---

## 5. Image Format Strategy

### Format Priority

Modern browsers receive the most efficient format:

```
┌─────────────────────────────────────────────────────────┐
│              Format Selection (Best to Fallback)         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. AVIF  ─── Best compression (30-50% smaller than     │
│               JPEG), supported in Chrome 85+, Firefox   │
│               93+, Safari 16.4+                         │
│                                                          │
│  2. WebP  ─── Good compression (25-34% smaller than     │
│               JPEG), 95%+ browser support               │
│                                                          │
│  3. JPEG  ─── Universal fallback, legacy browsers       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Quality Settings

| Format | Quality | Rationale |
|--------|---------|-----------|
| AVIF | 65 | Perceptually equivalent to JPEG 85 |
| WebP | 80 | Good balance of size/quality |
| JPEG | 85 | Fallback, slightly higher for compatibility |

### Format Generation Matrix

| Original | Generate AVIF | Generate WebP | Keep Original |
|----------|---------------|---------------|---------------|
| JPEG | Yes | Yes | Yes (fallback) |
| PNG | Yes | Yes | No (use WebP) |
| WebP | Yes | No (already WebP) | Yes |
| GIF | No | No | Yes (preserve animation) |
| SVG | No | No | Yes (vector) |

---

## 6. Variant Generation Pipeline

### Upload Flow

```ruby
# 1. Image uploaded via ActiveStorage
prop_photo.image.attach(uploaded_file)

# 2. After commit callback triggers job
after_commit :schedule_variant_generation, on: :create

def schedule_variant_generation
  ImageVariantGeneratorJob.perform_later(self.class.name, id)
end

# 3. Job generates all variants
class ImageVariantGeneratorJob < ApplicationJob
  queue_as :images

  def perform(model_class, model_id)
    record = model_class.constantize.find(model_id)
    return unless record.image.attached?

    generator = ResponsiveVariantGenerator.new(record.image)
    generator.generate_all!
  end
end
```

### Variant Generator Service

```ruby
class ResponsiveVariantGenerator
  WIDTHS = [320, 640, 768, 1024, 1280, 1536, 1920]
  FORMATS = [:webp, :avif, :jpeg]

  def initialize(attachment)
    @attachment = attachment
  end

  def generate_all!
    return if skip_generation?

    WIDTHS.each do |width|
      next if width > original_width  # Don't upscale

      FORMATS.each do |format|
        next if skip_format?(format)
        generate_variant(width, format)
      end
    end
  end

  private

  def generate_variant(width, format)
    transformations = {
      resize_to_limit: [width, nil],
      format: format,
      saver: quality_for(format)
    }

    # This triggers variant generation and caches it
    @attachment.variant(transformations).processed
  end

  def quality_for(format)
    case format
    when :avif then { quality: 65 }
    when :webp then { quality: 80 }
    when :jpeg then { quality: 85 }
    end
  end

  def skip_generation?
    # Skip for external URLs
    @attachment.record.respond_to?(:external_url) &&
      @attachment.record.external_url.present?
  end

  def skip_format?(format)
    # Skip AVIF if libvips doesn't support it
    format == :avif && !vips_supports_avif?
  end

  def original_width
    @original_width ||= @attachment.metadata[:width] || 9999
  end
end
```

### Job Configuration

```ruby
# config/sidekiq.yml
:queues:
  - [critical, 5]
  - [default, 3]
  - [images, 2]      # Lower priority, resource-intensive
  - [mailers, 1]

# Limit concurrency to avoid memory issues
:concurrency: 5
```

---

## 7. Helper Methods

### Primary Helper: `responsive_image_tag`

```ruby
# app/helpers/pwb/responsive_images_helper.rb

module Pwb
  module ResponsiveImagesHelper
    # Generate a responsive image with srcset and modern formats
    #
    # @param photo [PropPhoto, ContentPhoto, etc.] Photo model instance
    # @param sizes [String, Symbol] Sizes attribute or preset name
    # @param options [Hash] Additional options
    # @option options [Boolean] :eager Load eagerly (above fold)
    # @option options [String] :alt Alt text
    # @option options [String] :class CSS classes
    # @option options [Boolean] :avif Include AVIF sources (default: true)
    #
    # @return [String] HTML picture element
    #
    def responsive_image_tag(photo, sizes: :card, **options)
      return placeholder_image(options) if photo.blank?

      # Handle external URLs
      if photo.respond_to?(:external_url) && photo.external_url.present?
        return external_image_tag(photo.external_url, options)
      end

      # Build picture element with sources
      build_picture_element(photo, sizes, options)
    end

    private

    def build_picture_element(photo, sizes, options)
      sizes_value = resolve_sizes(sizes)

      content_tag(:picture) do
        sources = []

        # AVIF source (if enabled)
        if options.fetch(:avif, true)
          sources << source_tag(photo, :avif, sizes_value)
        end

        # WebP source
        sources << source_tag(photo, :webp, sizes_value)

        # Fallback img with JPEG srcset
        sources << fallback_img_tag(photo, sizes_value, options)

        safe_join(sources)
      end
    end

    def source_tag(photo, format, sizes)
      srcset = build_srcset(photo, format)

      tag.source(
        srcset: srcset,
        sizes: sizes,
        type: "image/#{format}"
      )
    end

    def fallback_img_tag(photo, sizes, options)
      srcset = build_srcset(photo, :jpeg)

      tag.img(
        src: default_src(photo),
        srcset: srcset,
        sizes: sizes,
        alt: options[:alt] || "",
        class: options[:class],
        loading: options[:eager] ? "eager" : "lazy",
        decoding: "async",
        fetchpriority: options[:eager] ? "high" : nil
      )
    end

    def build_srcset(photo, format)
      widths = [320, 640, 768, 1024, 1280, 1920]

      widths.map do |width|
        url = variant_url(photo, width, format)
        "#{url} #{width}w"
      end.join(", ")
    end

    def variant_url(photo, width, format)
      photo.image.variant(
        resize_to_limit: [width, nil],
        format: format,
        saver: quality_for(format)
      ).url
    end

    def resolve_sizes(sizes)
      return sizes if sizes.is_a?(String)

      SIZE_PRESETS[sizes] || SIZE_PRESETS[:card]
    end
  end
end
```

### Enhanced `opt_image_tag`

```ruby
# Enhance existing helper with srcset option

def opt_image_tag(photo, **options)
  # New: If responsive option is set, delegate to responsive helper
  if options.delete(:responsive)
    return responsive_image_tag(photo, **options)
  end

  # ... existing implementation ...
end
```

---

## 8. Storage & CDN Considerations

### Storage Impact

Estimated storage increase per image:

| Variants | Sizes | Formats | Total Variants |
|----------|-------|---------|----------------|
| Current | 4 | 1 | 4 |
| Proposed | 7 | 3 | 21 |

**Storage multiplier: ~5x per image**

### Mitigation Strategies

1. **Skip larger variants for small originals** - Don't upscale
2. **Lazy variant generation** - Generate on first request for rarely-viewed images
3. **TTL for unused variants** - Clean up variants not accessed in 90 days
4. **Progressive rollout** - Start with PropPhoto only

### CDN Configuration

```yaml
# Cloudflare R2 bucket rules
rules:
  - match: "*.avif"
    cache_ttl: 31536000  # 1 year
    headers:
      Content-Type: "image/avif"

  - match: "*.webp"
    cache_ttl: 31536000
    headers:
      Content-Type: "image/webp"

  - match: "variants/*"
    cache_ttl: 31536000  # Variants are immutable
```

---

## 9. Performance Targets

### Page Load Metrics

| Page | Metric | Current | Target |
|------|--------|---------|--------|
| Property listing | LCP | 3.2s | <2.0s |
| Search results | Total images | 2.1MB | <600KB |
| Homepage hero | LCP | 2.8s | <1.5s |

### Variant Generation

| Metric | Target |
|--------|--------|
| Time per variant | <500ms |
| Full set (21 variants) | <10s |
| Job queue latency | <30s |
| Cache hit rate | >90% |

### Memory Limits

```ruby
# Limit memory usage during variant generation
class ImageVariantGeneratorJob
  # Process one image at a time
  sidekiq_options concurrency: 2

  # Timeout long-running jobs
  sidekiq_options timeout: 120
end
```

---

## 10. Migration Strategy

### Phase 1: Infrastructure (Week 1)

1. Add `image_processing` configuration for AVIF
2. Create `ResponsiveVariants` module
3. Create `ImageVariantGeneratorJob`
4. Add `responsive_image_tag` helper

### Phase 2: PropPhoto Integration (Week 2)

1. Add callback to PropPhoto model
2. Generate variants for new uploads
3. Update property card partial
4. Update property detail page

### Phase 3: Backfill Existing Images (Week 3)

```ruby
# Rake task for backfill
namespace :images do
  desc "Generate responsive variants for existing images"
  task generate_variants: :environment do
    Pwb::PropPhoto.find_each do |photo|
      next unless photo.image.attached?
      ImageVariantGeneratorJob.perform_later(photo.class.name, photo.id)
    end
  end
end
```

### Phase 4: Other Models (Week 4)

1. ContentPhoto integration
2. WebsitePhoto integration
3. Media library integration

### Phase 5: Monitoring & Optimization (Week 5)

1. Add performance monitoring
2. Tune quality settings based on feedback
3. Optimize slow variants
4. Document and close

---

## 11. Testing Requirements

### Unit Tests

```ruby
# spec/services/responsive_variant_generator_spec.rb
RSpec.describe ResponsiveVariantGenerator do
  describe '#generate_all!' do
    it 'generates variants for all widths' do
      # ...
    end

    it 'skips widths larger than original' do
      # ...
    end

    it 'generates WebP and JPEG formats' do
      # ...
    end

    it 'skips generation for external URLs' do
      # ...
    end
  end
end
```

### Helper Tests

```ruby
# spec/helpers/pwb/responsive_images_helper_spec.rb
RSpec.describe Pwb::ResponsiveImagesHelper do
  describe '#responsive_image_tag' do
    it 'returns picture element with sources' do
      # ...
    end

    it 'includes srcset with multiple widths' do
      # ...
    end

    it 'uses lazy loading by default' do
      # ...
    end

    it 'uses eager loading when specified' do
      # ...
    end
  end
end
```

### Integration Tests

```ruby
# spec/system/responsive_images_spec.rb
RSpec.describe 'Responsive images', type: :system do
  it 'serves appropriately sized images on mobile' do
    # Resize viewport to mobile
    # Verify img srcset is present
    # Verify correct image is loaded
  end
end
```

---

## 12. Rollout Plan

### Week 1: Development & Testing

- [ ] Implement ResponsiveVariants module
- [ ] Implement ImageVariantGeneratorJob
- [ ] Implement responsive_image_tag helper
- [ ] Write comprehensive tests
- [ ] Test in development environment

### Week 2: Staging Deployment

- [ ] Deploy to staging environment
- [ ] Test with real images
- [ ] Measure performance improvements
- [ ] Fix any issues discovered

### Week 3: Production Rollout (PropPhoto)

- [ ] Deploy behind feature flag
- [ ] Enable for 10% of traffic
- [ ] Monitor error rates and performance
- [ ] Gradually increase to 100%

### Week 4: Backfill & Other Models

- [ ] Run backfill job for existing images
- [ ] Enable for ContentPhoto
- [ ] Enable for WebsitePhoto
- [ ] Monitor storage usage

### Week 5: Optimization & Documentation

- [ ] Tune quality settings
- [ ] Optimize slow paths
- [ ] Update developer documentation
- [ ] Training for team

---

## Appendix A: Dependencies

### Required Gems

```ruby
# Already present
gem 'image_processing', '~> 1.14'

# Optional: AVIF support requires libvips 8.9+
# Check with: vips --version
```

### System Requirements

| Dependency | Minimum Version | For |
|------------|-----------------|-----|
| libvips | 8.9+ | AVIF encoding |
| ImageMagick | 7.0+ | Fallback processing |
| Redis | 6.0+ | Job queue |

### Checking AVIF Support

```ruby
# In Rails console
Vips.at_least_libvips?(8, 9)  # Returns true if AVIF supported
```

---

## Appendix B: Fallback Behavior

### When Variant Generation Fails

```ruby
def variant_url_with_fallback(photo, width, format)
  photo.image.variant(transformations).url
rescue ActiveStorage::FileNotFoundError, Vips::Error
  # Return original image URL as fallback
  photo.image.url
end
```

### When AVIF Not Supported

```ruby
def source_tag(photo, format, sizes)
  return nil if format == :avif && !avif_supported?
  # ... normal generation
end

def avif_supported?
  @avif_supported ||= Vips.at_least_libvips?(8, 9)
end
```

---

## Appendix C: Monitoring

### Key Metrics to Track

1. **Variant generation time** - P50, P95, P99
2. **Storage growth rate** - GB per day
3. **Cache hit rate** - % of requests served from cache
4. **Error rate** - Failed variant generations
5. **Bandwidth savings** - Before/after comparison

### Logging

```ruby
class ImageVariantGeneratorJob
  around_perform do |job, block|
    start_time = Time.current
    block.call
    duration = Time.current - start_time

    Rails.logger.info(
      "ImageVariantGenerator completed",
      model: job.arguments[0],
      id: job.arguments[1],
      duration_ms: (duration * 1000).round
    )
  end
end
```
