# Image Handling - Quick Reference Guide

## Storage Services

```
Development/Test: Local Disk (tmp/storage, tmp/test)
Production:       Cloudflare R2 (S3-compatible CDN)
```

## Photo Models (ActiveStorage)

| Model | Table | Purpose | Key Features |
|-------|-------|---------|--------------|
| `Pwb::PropPhoto` | `pwb_prop_photos` | Property listing images | Supports props & realty_assets |
| `Pwb::ContentPhoto` | `pwb_content_photos` | Page builder images | Has block_key for fragments |
| `Pwb::WebsitePhoto` | `pwb_website_photos` | Branding/logo images | Identified by photo_key |
| `Pwb::Media` | `pwb_media` | Media library files | Comprehensive metadata |

All include `ExternalImageSupport` (except Media)

## External Images

```ruby
# Enable external URL support
photo.external_url = "https://cdn.example.com/image.jpg"
photo.external?      # => true
photo.has_image?     # => true (external or uploaded)
photo.image_url      # => external URL
```

## Image Processing Stack

```
Rails ActiveStorage
    ↓
image_processing gem (1.14.0)
    ↓
mini_magick (5.3.1) [ImageMagick]
ruby-vips (2.3.0) [libvips - faster]
```

## Image Variants (Predefined Sizes)

```ruby
# Thumbnail (fill - crops to exact size)
resize_to_fill: [150, 150]

# Responsive (limit - fits within bounds)
resize_to_limit: [300, 300]
resize_to_limit: [600, 600]
resize_to_limit: [1200, 1200]

# Format conversion
format: :webp
```

## Helper: opt_image_tag

```erb
<!-- Basic usage -->
<%= opt_image_tag(photo, class: "w-full") %>

<!-- With sizing -->
<%= opt_image_tag(photo, height: 280, crop: "scale") %>

<!-- Above-the-fold (eager loading) -->
<%= opt_image_tag(photo, eager: true) %>

<!-- Below-the-fold (lazy loading - default) -->
<%= opt_image_tag(photo, loading: "lazy") %>

<!-- WebP with fallback -->
<%= opt_image_tag(photo, use_picture: true) %>

<!-- All options -->
<%= opt_image_tag(photo,
    width: 300,
    height: 200,
    quality: "auto",      # Reserved for CDN
    crop: "fill",         # Reserved for CDN
    class: "hero-image",
    alt: "Property",
    eager: true,
    fetchpriority: "high",
    decoding: "async") %>
```

## Helper: photo_image_tag (explicit variants)

```erb
<%= photo_image_tag(photo, 
    variant_options: { resize_to_limit: [300, 300] },
    class: "thumbnail",
    lazy: true) %>
```

## View Examples

### Property Carousel
```erb
<!-- First image: eager loading -->
<%= opt_image_tag(photo, height: 600, crop: "scale",
    loading: "eager", fetchpriority: "high") %>

<!-- Other images: lazy loading -->
<%= opt_image_tag(photo, height: 600, crop: "scale",
    loading: "lazy") %>
```

### Property Grid Card
```erb
<%= opt_image_tag((property.ordered_photo 1),
    quality: "auto",
    height: 280,
    crop: "fill",
    class: "w-full h-full object-cover",
    loading: "lazy",
    alt: property.title) %>
```

### Background Images
```erb
<div style="<%= bg_image(photo, gradient: 'rgba(0,0,0,0.5)') %>">
  <!-- Content -->
</div>
```

## Media Library Variants

```ruby
media.variant_url(:thumb)     # 150x150 fill
media.variant_url(:small)     # 300x300 limit
media.variant_url(:medium)    # 600x600 limit
media.variant_url(:large)     # 1200x1200 limit
```

## Photo Retrieval

```ruby
# Get first/specific photo
property.ordered_photo(1)     # First photo
property.ordered_photo(2)     # Second photo

# Get primary URL
property.primary_image_url    # URL or empty string

# Get all photos
property.prop_photos          # Ordered array
```

## Image Gallery Builder Service

```ruby
builder = Pwb::ImageGalleryBuilder.new(website, url_helper: self)

images = builder.build          # All images (content + website + property)
images = builder.content_photos # Content photos only (limit: 50)
images = builder.website_photos # Website photos only (limit: 20)
images = builder.property_photos # Property photos only (limit: 30)

# Output format
{
  id: "prop_123",
  type: "property",
  url: "https://cdn.example.com/image.jpg",
  thumb_url: "https://cdn.example.com/image-thumb.jpg",
  filename: "photo.jpg",
  description: "Photo description"
}
```

## Media Metadata Available

```ruby
# From upload
media.filename             # Original filename
media.content_type         # MIME type
media.byte_size            # File size in bytes
media.checksum             # Integrity verification

# Auto-extracted (images)
media.width                # Image width
media.height               # Image height
media.dimensions           # "1920 x 1080" (string)

# User-provided
media.title                # Display title
media.alt_text             # Accessibility
media.caption              # Short description
media.description          # Extended description
media.tags                 # Array of tags

# Tracking
media.usage_count          # Times referenced
media.last_used_at         # Last access timestamp

# Organization
media.folder_id            # Folder classification
```

## Media Scopes

```ruby
Pwb::Media.images                    # Only images
Pwb::Media.documents                 # Only documents
Pwb::Media.recent                    # Ordered by created_at desc
Pwb::Media.search("keyword")         # Filename, title, alt_text, description
Pwb::Media.with_tag("featured")      # Array tag matching
Pwb::Media.by_folder(folder)         # Filter by folder
```

## Configuration Keys

### Environment Variables

```bash
# ActiveStorage URL generation
APP_HOST=example.com
MAILER_HOST=example.com

# Cloudflare R2
R2_ACCESS_KEY_ID=xxxxx
R2_SECRET_ACCESS_KEY=xxxxx
R2_BUCKET=my-bucket
R2_ACCOUNT_ID=xxxxx
R2_PUBLIC_URL=https://images.example.com

# Asset host (optional)
ASSET_HOST=https://cdn.example.com

# Image processing (auto-detected)
# Uses ruby-vips if available, falls back to mini_magick
```

### Per-Environment Services

```yaml
# Development
config.active_storage.service = :cloudflare_r2  # or :local

# Production
config.active_storage.service = :cloudflare_r2

# Test
config.active_storage.service = :test
```

## Lazy Loading Strategy

| Scenario | Setting | Rationale |
|----------|---------|-----------|
| Hero image (top) | `eager: true` | Above-the-fold, high priority |
| Grid thumbnails | `loading: "lazy"` | Below-the-fold, non-critical |
| Carousel (first) | `eager: true` + `fetchpriority: "high"` | Visible on load |
| Carousel (rest) | `loading: "lazy"` | Off-screen initially |
| Modal gallery | `loading: "lazy"` | Hidden until interaction |

## Common Patterns

### Responsive Image with WebP
```erb
<%= opt_image_tag(photo, use_picture: true, height: 400, class: "hero") %>
```

### Grid Thumbnail
```erb
<%= image_tag media.variant_url(:thumb), 
    alt: media.alt_text,
    class: "w-full h-full object-cover" %>
```

### Property Card
```erb
<%= link_to property.show_path do %>
  <%= opt_image_tag(property.ordered_photo(1),
      height: 280,
      crop: "fill",
      class: "w-full h-full object-cover",
      loading: "lazy",
      alt: property.title) %>
<% end %>
```

## URL Generation Outside Requests

```ruby
# In console, jobs, rake tasks
ActiveStorage::Current.url_options = {
  host: "example.com",
  protocol: "https"
}

url = Rails.application.routes.url_helpers.rails_blob_url(blob)
```

Configured automatically in `config/initializers/active_storage_url_options.rb`

## Future CDN Parameters

These are reserved for future implementation:

```ruby
# Quality (e.g., for image proxy service)
quality: "auto"    # Auto-detect optimal quality
quality: "80"      # Specific quality percentage

# Crop modes (e.g., for Cloudinary, ImageKit)
crop: "scale"      # Scale to fit
crop: "fill"       # Crop to exact size
crop: "thumb"      # Optimize for thumbnail
crop: "auto"       # Smart crop detection
```

## File Limits & Validation

```ruby
# Max file size
25.megabytes

# Allowed image formats
image/jpeg, image/png, image/gif, image/webp, image/svg+xml

# Allowed document formats
application/pdf
application/msword
application/vnd.openxmlformats-officedocument.wordprocessingml.document
application/vnd.ms-excel
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
text/plain, text/csv
```

## Multi-Tenancy

```ruby
# Non-tenant-scoped (use in console, cross-tenant operations)
Pwb::WebsitePhoto.all

# Tenant-scoped (use in web requests)
PwbTenant::WebsitePhoto.all   # Auto-scoped to current_website
```

## Performance Tips

1. **Lazy load below-the-fold:** `loading: "lazy"` (default)
2. **Eager load hero images:** `eager: true`
3. **Use variants for specific sizes:** `height: 280` generates resize_to_limit
4. **Enable WebP:** `use_picture: true` for modern browsers
5. **Set alt text:** Always for accessibility and SEO
6. **Use R2 CDN:** Production URLs benefit from Cloudflare edge caching
7. **Async decode:** `decoding: "async"` for non-blocking rendering
