# Image Handling Architecture - PropertyWebBuilder

## Overview

PropertyWebBuilder uses **ActiveStorage** as its primary image management system with support for both local disk storage and cloud object storage (Cloudflare R2). The project includes comprehensive image optimization helpers and supports external image URLs for CDN-based image delivery.

---

## 1. Image Storage System

### ActiveStorage Configuration

**Primary Technology:** Rails ActiveStorage (Rails 8.1+)

**Configuration Files:**
- `config/storage.yml` - Storage service configurations
- `config/initializers/active_storage_url_options.rb` - URL generation outside request context
- `config/initializers/active_storage_r2.rb` - Custom Cloudflare R2 service registration

### Storage Services

#### Development & Test
```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

#### Production
```yaml
cloudflare_r2:
  service: R2
  access_key_id: <%= ENV['R2_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['R2_SECRET_ACCESS_KEY'] %>
  region: auto
  bucket: <%= ENV['R2_BUCKET'] %>
  endpoint: <%= "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com" %>
  force_path_style: true
  public: true
  public_url: <%= ENV['R2_PUBLIC_URL'] %>
```

**Custom R2 Service:**
- Custom service implementation at `app/services/active_storage/service/r2_service.rb`
- Supports CDN domain for public URLs
- Handles checksum verification

### Environment-Specific Configuration

| Environment | Service | Note |
|-------------|---------|------|
| Development | `cloudflare_r2` | Can be switched to `:local` for offline dev |
| Production | `cloudflare_r2` | S3-compatible, supports CDN delivery |
| Test | `test` | Temporary disk storage, cleaned between runs |

---

## 2. Image Processing & Optimization

### Image Processing Gems

**Gemfile Dependencies:**
```ruby
gem "image_processing", "~> 1.2"
```

**Transitive Dependencies (from Gemfile.lock):**
- `image_processing` (1.14.0)
  - `mini_magick` (5.3.1) - ImageMagick Ruby wrapper
  - `ruby-vips` (2.3.0) - libvips binding (high-performance alternative)

### Image Processing Strategy

The project uses `image_processing` gem which provides abstraction over multiple processors:
1. **Default:** mini_magick (ImageMagick)
2. **Alternative:** ruby-vips (libvips) - faster, lower memory footprint

Rails automatically chooses the available processor (vips preferred if available).

### Variant Support

ActiveStorage variants are used for image optimization:

```ruby
# Thumbnail variant (150x150 fill)
file.variant(resize_to_fill: [150, 150])

# Responsive variants (limiting dimensions)
file.variant(resize_to_limit: [300, 300])
file.variant(resize_to_limit: [600, 600])
file.variant(resize_to_limit: [1200, 1200])

# WebP format conversion
file.variant(resize_to_limit: [600, 600], format: :webp)
```

### Variant Caching

- ActiveStorage variants are cached after first generation
- Variant cache stored via `active_storage_variant_records` table
- Schema includes `blob_id` and fingerprint for variant tracking

---

## 3. Photo Models & Attachments

### Three Photo Models with ActiveStorage

#### 1. PropPhoto - Property Photos
**Location:** `app/models/pwb/prop_photo.rb`

```ruby
class PropPhoto < ApplicationRecord
  include ExternalImageSupport
  has_one_attached :image, dependent: :purge_later
  belongs_to :prop, optional: true
  belongs_to :realty_asset, optional: true
end
```

**Database Table:** `pwb_prop_photos`
- Columns: `id`, `description`, `external_url`, `file_size`, `folder`, `image`, `sort_order`, `prop_id`, `realty_asset_id`
- Indexes on `prop_id` and `realty_asset_id`
- Supports both property listings and realty assets

#### 2. ContentPhoto - Page Content Photos
**Location:** `app/models/pwb/content_photo.rb`

```ruby
class ContentPhoto < ApplicationRecord
  include ExternalImageSupport
  has_one_attached :image, dependent: :purge_later
  belongs_to :content, optional: true
end
```

**Database Table:** `pwb_content_photos`
- Columns: `id`, `block_key`, `description`, `external_url`, `file_size`, `folder`, `image`, `sort_order`, `content_id`
- Used for page builder content sections
- Includes `block_key` for fragment block association

**Helper Method:**
```ruby
def optimized_image_url
  return external_url if external?
  return nil unless image.attached?
  
  if image.variable?
    Rails.application.routes.url_helpers.rails_representation_path(
      image.variant(resize_to_limit: [800, 600]),
      only_path: true
    )
  else
    Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
  end
end
```

#### 3. WebsitePhoto - Branding Images
**Location:** `app/models/pwb/website_photo.rb` (non-tenant-scoped)
**Tenant-scoped:** `app/models/pwb_tenant/website_photo.rb`

```ruby
class WebsitePhoto < ApplicationRecord
  include ExternalImageSupport
  belongs_to :website, optional: true
  has_one_attached :image, dependent: :purge_later
end
```

**Database Table:** `pwb_website_photos`
- Columns: `id`, `description`, `external_url`, `file_size`, `folder` (default: "weebrix"), `image`, `photo_key`, `website_id`
- Used for site logos, backgrounds, branding assets
- Identified by `photo_key` for programmatic reference

#### 4. Media - Media Library Files
**Location:** `app/models/pwb/media.rb`

```ruby
class Media < ApplicationRecord
  has_one_attached :file
  belongs_to :website
  belongs_to :folder, class_name: 'Pwb::MediaFolder', optional: true
end
```

**Database Table:** `pwb_media`
- Comprehensive metadata: `alt_text`, `byte_size`, `caption`, `checksum`, `content_type`, `description`, `filename`, `height`, `width`, `tags`, `title`, `usage_count`, `last_used_at`, `sort_order`
- Supports images and documents (PDFs, Word, Excel, text)
- Automatic dimension extraction for images
- Max file size: 25 MB
- Content type validation

**Variant Methods:**
```ruby
def variant_url(variant_name)
  case variant_name.to_sym
  when :thumb, :thumbnail
    file.variant(resize_to_fill: [150, 150])
  when :small
    file.variant(resize_to_limit: [300, 300])
  when :medium
    file.variant(resize_to_limit: [600, 600])
  when :large
    file.variant(resize_to_limit: [1200, 1200])
  end
end
```

### ExternalImageSupport Concern

**Location:** `app/models/concerns/external_image_support.rb`

Provides URL flexibility for tenants:

```ruby
module ExternalImageSupport
  def external?
    external_url.present?
  end

  def image_url(variant_options: nil)
    if external?
      external_url
    elsif image.attached?
      active_storage_url(variant_options: variant_options)
    end
  end

  def thumbnail_url(size: [200, 200])
    if external?
      external_url  # Returns original (no resizing for external)
    elsif image.attached? && image.variable?
      Rails.application.routes.url_helpers.rails_representation_path(
        image.variant(resize_to_limit: size),
        only_path: true
      )
    end
  end

  def has_image?
    external? || image.attached?
  end
end
```

**Features:**
- URL validation for external images (HTTP/HTTPS)
- Allows websites to reference external CDN-hosted images
- Prevents duplicate storage
- Used by PropPhoto, ContentPhoto, WebsitePhoto

---

## 4. Image Display & Rendering

### Images Helper

**Location:** `app/helpers/pwb/images_helper.rb`

#### Main Helper: `opt_image_tag`

```ruby
def opt_image_tag(photo, options = {})
  # Extracts custom options
  use_picture = options.delete(:use_picture)
  width = options.delete(:width)
  height = options.delete(:height)
  quality = options.delete(:quality)  # Reserved for CDN
  crop = options.delete(:crop)        # Reserved for CDN
  
  # Lazy loading setup
  unless eager == true || lazy == false
    options[:loading] ||= DEFAULT_LOADING  # "lazy"
    options[:decoding] ||= "async"
  end
  
  # Eager loading for above-the-fold
  if eager == true
    options[:fetchpriority] ||= "high"
    options[:loading] = "eager"
  end
  
  # Generate variants if dimensions specified
  variant_options = {}
  if width || height
    variant_options[:resize_to_limit] = [width, height].compact
  end
  
  # Picture element for WebP
  if use_picture && photo.image.variable?
    optimized_image_picture(photo, variant_options, options)
  elsif variant_options.present? && photo.image.variable?
    image_tag photo.image.variant(variant_options), options
  else
    image_tag url_for(photo.image), options
  end
end
```

#### Picture Element Generation

```ruby
def optimized_image_picture(photo, variant_options = {}, html_options = {})
  webp_options = variant_options.merge(format: :webp)
  fallback_url = if variant_options.present?
                   url_for(photo.image.variant(variant_options))
                 else
                   url_for(photo.image)
                 end

  content_tag(:picture) do
    webp_source = tag(:source, srcset: url_for(photo.image.variant(webp_options)), type: "image/webp")
    fallback_img = image_tag(fallback_url, html_options)
    safe_join([webp_source, fallback_img])
  end
end
```

#### Supporting Helpers

```ruby
# Low-level helper with variant support
def photo_image_tag(photo, variant_options: nil, **html_options)
  # Similar to opt_image_tag but takes explicit variant_options hash

# Get photo URL (external or ActiveStorage)
def photo_url(photo)
  if photo.respond_to?(:external?) && photo.external?
    photo.external_url
  elsif photo.respond_to?(:image) && photo.image.attached?
    url_for(photo.image)
  end

# Background image CSS
def bg_image(photo, options = {})
  image_url = photo_url(photo)
  return "" if image_url.blank?
  
  if options[:gradient]
    "background-image: linear-gradient(#{options[:gradient]}), url(#{image_url});".html_safe
  else
    "background-image: url(#{image_url});".html_safe
  end
end
```

### Image Display Features

- **Lazy Loading:** Default behavior (`loading="lazy"`)
- **Eager Loading:** For above-the-fold images (`loading="eager"`, `fetchpriority="high"`)
- **Async Decoding:** `decoding="async"` for non-critical images
- **WebP Support:** Picture element with WebP source + fallback
- **Responsive:** Optional `resize_to_limit` variants
- **External URLs:** Direct support without variants
- **Error Handling:** Graceful fallback on variant generation failure

---

## 5. Image Display in Views

### Property Carousel Example
**File:** `app/themes/default/views/pwb/props/_images_section_carousel.html.erb`

```erb
<div class="carousel carousel-1">
  <% @property_details.prop_photos.each.with_index do |photo, index| %>
    <div class="item <%= "active" if index == 0 %>">
      <%= opt_image_tag((photo), 
          quality: "auto", 
          height: 600, 
          crop: "scale",
          class: "carousel-image",
          alt: @property_details.title.presence || "Property photo",
          loading: index == 0 ? "eager" : "lazy",
          fetchpriority: index == 0 ? "high" : nil) %>
    </div>
  <% end %>
</div>
```

**Key Features:**
- First image: eager loading + high fetch priority
- Remaining images: lazy loading
- Height constraint: 600px
- Responsive scaling

### Property Card Example
**File:** `app/themes/default/views/pwb/search/_search_result_item.html.erb`

```erb
<div class="property-card">
  <div class="aspect-[4/3] overflow-hidden">
    <%= link_to property.contextual_show_path(@operation_type) do %>
      <%= opt_image_tag((property.ordered_photo 1), 
          quality: "auto",
          height: 280, 
          crop: "fill",
          class: "w-full h-full object-cover hover:scale-105",
          loading: "lazy",
          alt: property.title.presence || "Property listing") %>
    <% end %>
  </div>
</div>
```

**Key Features:**
- Lazy loading (below-the-fold)
- Height constraint: 280px
- Crop mode: fill (responsive)
- Aspect ratio: 4:3 (card layout)
- Hover effect: scale transform

### Media Library Example
**File:** `app/views/site_admin/media_library/index.html.erb`

```erb
<div class="grid grid-cols-4 gap-4">
  <% @media.each do |media| %>
    <% if media.image? && media.file.attached? %>
      <%= image_tag media.variant_url(:thumb), 
          alt: media.alt_text || media.filename,
          class: "w-full h-full object-cover" %>
    <% end %>
  <% end %>
</div>
```

**Key Features:**
- Direct variant URL access (`:thumb` = 150x150)
- Media metadata (alt_text, filename)
- Grid layout with 4 columns
- Object-fit cover

---

## 6. Image Gallery Builder Service

**Location:** `app/services/pwb/image_gallery_builder.rb`

Service for aggregating images from multiple sources:

```ruby
class ImageGalleryBuilder
  DEFAULT_LIMITS = {
    content: 50,
    website: 20,
    property: 30
  }.freeze

  THUMBNAIL_SIZE = [150, 150].freeze

  def build
    images = []
    images.concat(content_photos)
    images.concat(website_photos)
    images.concat(property_photos)
    images
  end

  def content_photos
    ContentPhoto.joins(:content)
                .where(pwb_contents: { website_id: @website&.id })
                .order(created_at: :desc)
                .limit(@limits[:content])
  end

  def website_photos
    @website&.website_photos&.order(created_at: :desc)&.limit(@limits[:website]) || []
  end

  def property_photos
    PropPhoto.joins(:realty_asset)
             .where(pwb_realty_assets: { website_id: @website&.id })
             .order(created_at: :desc)
             .limit(@limits[:property])
  end
end
```

**Output Format:**
```ruby
{
  id: "prop_123",
  type: "property",
  url: "https://cdn.example.com/images/abc123.jpg",
  thumb_url: "https://cdn.example.com/images/abc123-thumb.jpg",
  filename: "living-room.jpg",
  description: "Property 123 Main St"
}
```

---

## 7. Media Handling & Metadata

### Media Library Model Features

**File Upload Support:**
- Images: JPEG, PNG, GIF, WebP, SVG
- Documents: PDF, Word (.docx), Excel (.xlsx), Text, CSV
- Max size: 25 MB
- Validation on `content_type` and `byte_size`

**Automatic Metadata Extraction:**
```ruby
before_validation :set_metadata_from_file
after_commit :extract_dimensions, on: :create, if: -> { image? }

# Sets: filename, content_type, byte_size, checksum
# Extracts: width, height (for images)
```

**Database Columns:**
| Column | Type | Purpose |
|--------|------|---------|
| `filename` | string | Original filename |
| `content_type` | string | MIME type |
| `byte_size` | bigint | File size |
| `checksum` | string | Integrity verification |
| `width` | integer | Image width (px) |
| `height` | integer | Image height (px) |
| `alt_text` | string | Accessibility alt text |
| `title` | string | Display title |
| `caption` | string | Image caption |
| `description` | text | Extended description |
| `tags` | string[] | Array of tags |
| `usage_count` | integer | Track reuse |
| `last_used_at` | datetime | Last usage timestamp |
| `folder_id` | bigint | Organization |

**Scopes for Querying:**
```ruby
scope :images, -> { where("content_type LIKE 'image/%'") }
scope :documents, -> { where("content_type NOT LIKE 'image/%'") }
scope :recent, -> { order(created_at: :desc) }
scope :search, ->(query) { where("filename ILIKE ? OR title ILIKE ?", "%#{query}%", "%#{query}%") }
scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }
```

---

## 8. Multi-Tenancy & Scoping

### Tenant Isolation

- **Primary Models (non-tenant):** `Pwb::PropPhoto`, `Pwb::ContentPhoto`, `Pwb::WebsitePhoto`
- **Tenant-Scoped Models:** `PwbTenant::WebsitePhoto` (auto-scoped via `acts_as_tenant`)

**Photo Access Concern:**
```ruby
# Listed Property Photo Accessors
module ListedProperty::PhotoAccessors
  def ordered_photo(number)
    prop_photos[number - 1] if prop_photos.length >= number
  end

  def primary_image_url
    first_photo = ordered_photo(1)
    if first_photo&.image&.attached?
      Rails.application.routes.url_helpers.rails_blob_path(first_photo.image, only_path: true)
    else
      ""
    end
  end
end
```

---

## 9. URL Generation & CDN Support

### URL Options Configuration

**File:** `config/initializers/active_storage_url_options.rb`

```ruby
Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = {
    host: ENV.fetch("APP_HOST") { ENV.fetch("MAILER_HOST", "localhost") },
    protocol: Rails.env.production? ? "https" : "http"
  }
end
```

**Purpose:** Enables URL generation outside request context (console, jobs, rake tasks)

### CDN Configuration

**R2 Public URL:**
```yaml
# config/storage.yml
cloudflare_r2:
  public_url: <%= ENV['R2_PUBLIC_URL'] %>
  # e.g., https://images.example.com/
```

**Asset Host (optional):**
```ruby
# config/environments/production.rb
config.asset_host = ENV["ASSET_HOST"] if ENV["ASSET_HOST"].present?
# e.g., https://cdn.example.com
```

---

## 10. Current Limitations & Future Enhancements

### Current State
- **No srcset generation** for responsive images (quality/crop params reserved but not implemented)
- **External images not resizable** (no image proxy service)
- **WebP support** available but not automatically generated (requires explicit `:use_picture` flag)
- **No automatic format negotiation** based on browser capabilities

### Reserved for Future CDN Integration
```ruby
_quality = options.delete(:quality)    # e.g., "auto", "80"
_crop = options.delete(:crop)          # e.g., "scale", "fill", "thumb"
```

These parameters can be passed to a CDN API in the future (e.g., Cloudinary, ImageKit).

### Recommended Enhancements
1. **Auto WebP generation** - Always serve modern formats
2. **Responsive srcset** - Generate multiple sizes automatically
3. **Image proxy** - For external URL transformation
4. **AVIF support** - Next-gen image format
5. **Lazy loading placeholders** - Blur-up or LQIP implementation
6. **Image cropping UI** - Admin interface for custom crops

---

## 11. File Organization Summary

### Models
- `app/models/pwb/prop_photo.rb` - Property photos
- `app/models/pwb/content_photo.rb` - Page content photos
- `app/models/pwb/website_photo.rb` - Website branding images
- `app/models/pwb/media.rb` - Media library files
- `app/models/pwb/media_folder.rb` - Media organization

### Concerns
- `app/models/concerns/external_image_support.rb` - External URL handling
- `app/models/concerns/listed_property/photo_accessors.rb` - Photo retrieval methods

### Helpers
- `app/helpers/pwb/images_helper.rb` - Image rendering and optimization

### Services
- `app/services/pwb/image_gallery_builder.rb` - Gallery aggregation
- `app/services/active_storage/service/r2_service.rb` - Custom R2 service

### Controllers
- `app/controllers/site_admin/media_library_controller.rb` - Media management interface

### Configuration
- `config/storage.yml` - Storage service configurations
- `config/initializers/active_storage_url_options.rb` - URL generation
- `config/initializers/active_storage_r2.rb` - R2 service registration
- `config/environments/*.rb` - Per-environment storage settings

### Migrations
- `db/migrate/*create_active_storage_tables.rb` - ActiveStorage schema
- `db/migrate/20251208124059_add_external_url_to_photos.rb` - External URL support

---

## Summary

PropertyWebBuilder has a **mature, production-ready image handling system** based on Rails ActiveStorage with:

1. **Storage:** Dual-mode (local development, Cloudflare R2 production)
2. **Optimization:** Image variants with mini_magick/libvips
3. **Models:** Four photo models (PropPhoto, ContentPhoto, WebsitePhoto, Media)
4. **Features:** External URLs, lazy loading, eager loading, WebP support
5. **Multi-tenancy:** Proper tenant scoping with flexible external URL option
6. **Metadata:** Comprehensive tracking (dimensions, tags, usage, descriptions)
7. **Display:** Flexible helper methods for responsive image rendering
8. **Extensibility:** Reserved parameters for future CDN integration

The architecture supports both uploaded images and external CDN references, making it flexible for different deployment scenarios and tenant needs.
