# Responsive Image Helper API Reference

Complete API documentation for PropertyWebBuilder's responsive image helpers.

---

## Table of Contents

- [responsive_image_tag](#responsive_image_tag)
- [ResponsiveVariants Module](#responsivevariants-module)
- [ResponsiveVariantGenerator Service](#responsivevariantgenerator-service)
- [ImageVariantGeneratorJob](#imagevariantgeneratorjob)
- [Size Presets](#size-presets)
- [Examples](#examples)

---

## responsive_image_tag

The primary helper for rendering responsive images with automatic srcset generation.

### Signature

```ruby
responsive_image_tag(photo, sizes: :card, **options) → ActiveSupport::SafeBuffer
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `photo` | Object | required | Photo model (PropPhoto, ContentPhoto, etc.) |
| `sizes` | String, Symbol | `:card` | CSS sizes attribute or preset name |
| `**options` | Hash | `{}` | Additional options (see below) |

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `:eager` | Boolean | `false` | Use eager loading (for above-fold images) |
| `:alt` | String | `""` | Alt text for accessibility |
| `:class` | String | `nil` | CSS classes for the `<img>` element |
| `:picture_class` | String | `nil` | CSS classes for the `<picture>` element |
| `:avif` | Boolean | `true` | Include AVIF source (if supported) |
| `:fallback_url` | String | `nil` | Placeholder URL if no image |
| `:width` | Integer | `nil` | Explicit width attribute |
| `:height` | Integer | `nil` | Explicit height attribute |

### Return Value

Returns an `ActiveSupport::SafeBuffer` containing a `<picture>` element with:
- `<source>` elements for AVIF and WebP formats
- `<img>` element with JPEG srcset as fallback

### Generated HTML Structure

```html
<picture>
  <source srcset="image-320.avif 320w, image-640.avif 640w, ..."
          sizes="(min-width: 1280px) 400px, 100vw"
          type="image/avif">
  <source srcset="image-320.webp 320w, image-640.webp 640w, ..."
          sizes="(min-width: 1280px) 400px, 100vw"
          type="image/webp">
  <img src="image.jpg"
       srcset="image-320.jpg 320w, image-640.jpg 640w, ..."
       sizes="(min-width: 1280px) 400px, 100vw"
       alt="Property photo"
       loading="lazy"
       decoding="async">
</picture>
```

### Basic Examples

```erb
<%# Standard property card %>
<%= responsive_image_tag @property.primary_photo, sizes: :card %>

<%# Hero image (above fold) %>
<%= responsive_image_tag @property.primary_photo, sizes: :hero, eager: true %>

<%# With alt text and class %>
<%= responsive_image_tag @photo,
    sizes: :thumbnail,
    alt: "Kitchen view",
    class: "rounded-lg shadow" %>

<%# Custom sizes string %>
<%= responsive_image_tag @photo,
    sizes: "(min-width: 1024px) 50vw, 100vw" %>

<%# Without AVIF %>
<%= responsive_image_tag @photo, avif: false %>

<%# With custom placeholder %>
<%= responsive_image_tag nil,
    fallback_url: asset_path('no-image.svg'),
    alt: "No image available" %>
```

---

## ResponsiveVariants Module

Configuration module for responsive image breakpoints and formats.

### Location

```ruby
# lib/pwb/responsive_variants.rb
module Pwb::ResponsiveVariants
```

### Constants

#### WIDTHS

Array of pixel widths for variant generation.

```ruby
WIDTHS = [320, 640, 768, 1024, 1280, 1536, 1920].freeze
```

#### FORMATS

Hash of format configurations with quality settings.

```ruby
FORMATS = {
  avif: { format: :avif, saver: { quality: 65, effort: 4 } },
  webp: { format: :webp, saver: { quality: 80 } },
  jpeg: { format: :jpeg, saver: { quality: 85, progressive: true } }
}.freeze
```

#### SIZE_PRESETS

Predefined CSS sizes attribute values.

```ruby
SIZE_PRESETS = {
  hero: "(min-width: 1280px) 1280px, 100vw",
  card: "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw",
  card_sm: "(min-width: 1280px) 300px, (min-width: 768px) 50vw, 100vw",
  thumbnail: "(min-width: 768px) 200px, 150px",
  thumbnail_sm: "100px",
  lightbox: "100vw",
  content: "(min-width: 848px) 800px, calc(100vw - 48px)",
  logo: "200px",
  featured: "(min-width: 1280px) 600px, (min-width: 768px) 50vw, 100vw"
}.freeze
```

### Class Methods

#### widths_for(original_width)

Returns widths that don't exceed the original image width.

```ruby
Pwb::ResponsiveVariants.widths_for(800)
# => [320, 640, 768]

Pwb::ResponsiveVariants.widths_for(2000)
# => [320, 640, 768, 1024, 1280, 1536, 1920]
```

#### formats_to_generate

Returns array of formats to generate, including AVIF if supported.

```ruby
Pwb::ResponsiveVariants.formats_to_generate
# => [:avif, :webp, :jpeg]  # if AVIF supported
# => [:webp, :jpeg]          # if AVIF not supported
```

#### avif_supported?

Checks if libvips supports AVIF encoding.

```ruby
Pwb::ResponsiveVariants.avif_supported?
# => true/false
```

#### sizes_for(preset)

Returns the CSS sizes string for a preset.

```ruby
Pwb::ResponsiveVariants.sizes_for(:hero)
# => "(min-width: 1280px) 1280px, 100vw"

Pwb::ResponsiveVariants.sizes_for(:card)
# => "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw"
```

#### transformations_for(width, format)

Returns the transformation hash for ActiveStorage variants.

```ruby
Pwb::ResponsiveVariants.transformations_for(640, :webp)
# => { resize_to_limit: [640, nil], format: :webp, saver: { quality: 80 } }
```

---

## ResponsiveVariantGenerator Service

Service class for generating all responsive variants for an image.

### Location

```ruby
# app/services/pwb/responsive_variant_generator.rb
class Pwb::ResponsiveVariantGenerator
```

### Constructor

```ruby
generator = Pwb::ResponsiveVariantGenerator.new(attachment)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `attachment` | ActiveStorage::Attached | The image attachment |

### Instance Methods

#### generate_all!

Generates all variants for all widths and formats.

```ruby
generator = Pwb::ResponsiveVariantGenerator.new(photo.image)
success = generator.generate_all!

if success
  puts "All variants generated"
else
  puts "Errors: #{generator.errors}"
end
```

**Returns:** `Boolean` - `true` if all variants generated successfully

#### generate_variant(width, format)

Generates a single variant.

```ruby
generator.generate_variant(640, :webp)
generator.generate_variant(1024, :jpeg)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `width` | Integer | Target width in pixels |
| `format` | Symbol | Output format (`:avif`, `:webp`, `:jpeg`) |

#### errors

Returns array of errors encountered during generation.

```ruby
generator.errors
# => [
#   { width: 1920, format: :avif, error: "AVIF encoding failed" }
# ]
```

### Example Usage

```ruby
# Generate variants for a photo
photo = Pwb::PropPhoto.find(123)
generator = Pwb::ResponsiveVariantGenerator.new(photo.image)

if generator.generate_all!
  Rails.logger.info("Variants generated for photo #{photo.id}")
else
  Rails.logger.error("Failed: #{generator.errors}")
end

# Generate single variant
generator.generate_variant(640, :webp)
```

---

## ImageVariantGeneratorJob

Background job for asynchronous variant generation.

### Location

```ruby
# app/jobs/image_variant_generator_job.rb
class ImageVariantGeneratorJob < ApplicationJob
```

### Queue

```ruby
queue_as :images
```

### Perform

```ruby
ImageVariantGeneratorJob.perform_later(model_class, model_id)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `model_class` | String | Class name (e.g., `"Pwb::PropPhoto"`) |
| `model_id` | Integer | Record ID |

### Retry Behavior

- Retries 3 times with exponential backoff
- Discards job if record not found (deleted)
- Timeout: 120 seconds

### Example Usage

```ruby
# Enqueue for background processing
ImageVariantGeneratorJob.perform_later('Pwb::PropPhoto', photo.id)

# Process immediately (for testing)
ImageVariantGeneratorJob.perform_now('Pwb::PropPhoto', photo.id)

# In model callback
after_commit :schedule_variant_generation, on: :create

def schedule_variant_generation
  return unless image.attached?
  ImageVariantGeneratorJob.perform_later(self.class.name, id)
end
```

---

## Size Presets

### Quick Reference

| Preset | Sizes Value | Use Case |
|--------|-------------|----------|
| `:hero` | `(min-width: 1280px) 1280px, 100vw` | Full-width hero banners |
| `:card` | `(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw` | Property cards (3-col grid) |
| `:card_sm` | `(min-width: 1280px) 300px, (min-width: 768px) 50vw, 100vw` | Smaller cards (4-col grid) |
| `:thumbnail` | `(min-width: 768px) 200px, 150px` | List view thumbnails |
| `:thumbnail_sm` | `100px` | Small fixed thumbnails |
| `:lightbox` | `100vw` | Gallery lightbox |
| `:content` | `(min-width: 848px) 800px, calc(100vw - 48px)` | Article images |
| `:logo` | `200px` | Fixed-width logos |
| `:featured` | `(min-width: 1280px) 600px, (min-width: 768px) 50vw, 100vw` | Featured property |

### Choosing the Right Preset

```
┌─────────────────────────────────────────────────────────────┐
│                    Preset Selection Guide                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Full-width image?                                           │
│    ├── Yes → :hero (with eager: true if above fold)         │
│    └── No ↓                                                  │
│                                                              │
│  In a grid?                                                  │
│    ├── 3 columns → :card                                    │
│    ├── 4 columns → :card_sm                                 │
│    └── No ↓                                                  │
│                                                              │
│  Fixed small size?                                           │
│    ├── ~200px → :thumbnail                                  │
│    ├── ~100px → :thumbnail_sm                               │
│    └── No ↓                                                  │
│                                                              │
│  Inside content area?                                        │
│    ├── Yes → :content                                       │
│    └── No → Use custom sizes string                         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Examples

### Property Listing Page

```erb
<%# Search results grid %>
<div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
  <% @properties.each do |property| %>
    <article class="property-card">
      <%= responsive_image_tag(
        property.primary_photo,
        sizes: :card,
        alt: property.title,
        class: "w-full h-48 object-cover rounded-t-lg"
      ) %>
      <div class="p-4">
        <h3><%= property.title %></h3>
        <p><%= property.formatted_price %></p>
      </div>
    </article>
  <% end %>
</div>
```

### Property Detail Page

```erb
<%# Hero section %>
<section class="property-hero relative">
  <%= responsive_image_tag(
    @property.primary_photo,
    sizes: :hero,
    eager: true,
    alt: @property.title,
    class: "w-full h-[500px] object-cover"
  ) %>
  <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/60 p-6">
    <h1 class="text-white text-3xl font-bold"><%= @property.title %></h1>
  </div>
</section>

<%# Photo gallery %>
<section class="property-gallery mt-8">
  <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
    <% @property.prop_photos.each_with_index do |photo, index| %>
      <%= responsive_image_tag(
        photo,
        sizes: :thumbnail,
        alt: "#{@property.title} - Photo #{index + 1}",
        class: "w-full h-32 object-cover rounded cursor-pointer hover:opacity-90"
      ) %>
    <% end %>
  </div>
</section>
```

### Homepage Featured Properties

```erb
<%# Featured property - larger card %>
<div class="featured-property">
  <%= responsive_image_tag(
    @featured.primary_photo,
    sizes: :featured,
    eager: true,  # Above fold
    alt: @featured.title,
    class: "w-full h-64 object-cover rounded-lg"
  ) %>
</div>

<%# Recent listings - smaller cards %>
<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
  <% @recent.each do |property| %>
    <%= responsive_image_tag(
      property.primary_photo,
      sizes: :card_sm,
      alt: property.title,
      class: "w-full h-40 object-cover rounded"
    ) %>
  <% end %>
</div>
```

### Content/Blog Page

```erb
<%# Article with inline images %>
<article class="prose max-w-3xl mx-auto">
  <h1><%= @article.title %></h1>

  <%# Featured image %>
  <figure>
    <%= responsive_image_tag(
      @article.featured_image,
      sizes: :content,
      eager: true,
      alt: @article.title,
      class: "rounded-lg"
    ) %>
    <figcaption><%= @article.image_caption %></figcaption>
  </figure>

  <%# Article body with embedded images %>
  <div class="article-content">
    <%== @article.body %>
  </div>
</article>
```

### Handling Missing Images

```erb
<%# With custom fallback %>
<%= responsive_image_tag(
  @property.primary_photo,
  sizes: :card,
  fallback_url: asset_path('images/property-placeholder.svg'),
  alt: "Property image not available"
) %>

<%# Conditional rendering %>
<% if @property.primary_photo.present? %>
  <%= responsive_image_tag(@property.primary_photo, sizes: :card) %>
<% else %>
  <div class="bg-gray-200 h-48 flex items-center justify-center">
    <span class="text-gray-500">No image</span>
  </div>
<% end %>
```

---

## Migration from opt_image_tag

### Before (Current)

```erb
<%= opt_image_tag @photo, height: 280, alt: "Property" %>
```

### After (Responsive)

```erb
<%= responsive_image_tag @photo, sizes: :card, alt: "Property" %>
```

### Key Differences

| Aspect | `opt_image_tag` | `responsive_image_tag` |
|--------|-----------------|------------------------|
| Output | Single `<img>` | `<picture>` with sources |
| Sizing | Fixed height/width | Responsive srcset |
| Formats | Single format | WebP + AVIF + JPEG |
| Browser optimization | Manual | Automatic |
