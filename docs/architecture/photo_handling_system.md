# Photo Handling System Architecture

## Overview

PropertyWebBuilder has a multi-layered photo system supporting:
- Property/listing photos (PropPhoto)
- Website content photos (ContentPhoto)
- Website branding photos (WebsitePhoto)
- External URLs for CDN-hosted images
- ActiveStorage for file management with optional S3/R2 backend
- Multi-tenant isolation

## Photo Models

### 1. Pwb::PropPhoto
**File:** `/app/models/pwb/prop_photo.rb`

```ruby
module Pwb
  class PropPhoto < ApplicationRecord
    has_one_attached :image
    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true
    belongs_to :realty_asset, optional: true
  end
end
```

**Database Table:** `pwb_prop_photos`
- Migration: `20161124103103_create_pwb_prop_photos.rb`
- Columns:
  - `prop_id` (integer) - Legacy association
  - `realty_asset_id` (integer) - Current association (from migration `20251204141849`)
  - `image` (string) - legacy column for filename
  - `description` (string) - Photo description
  - `folder` (string) - Storage folder path
  - `file_size` (integer) - Original file size
  - `sort_order` (integer) - Display order
  - `website_id` (reference) - Added in latest migration for tenant scoping

**Features:**
- Associated with properties via `realty_asset`
- Supports backwards compatibility with legacy `prop` association
- Sorted by `sort_order` ASC
- Uses ActiveStorage's `has_one_attached :image`

**URL Generation:**
```ruby
# In Pwb::Prop and Pwb::RealtyAsset
def primary_image_url
  if prop_photos.any? && ordered_photo(1)&.image&.attached?
    Rails.application.routes.url_helpers.rails_blob_path(ordered_photo(1).image, only_path: true)
  else
    ""
  end
end
```

### 2. Pwb::ContentPhoto
**File:** `/app/models/pwb/content_photo.rb`

```ruby
module Pwb
  class ContentPhoto < ApplicationRecord
    include ExternalImageSupport
    has_one_attached :image
    belongs_to :content, optional: true

    def optimized_image_url
      # Use external URL if available
      return external_url if external?
      return nil unless image.attached?

      # Use variants for optimization when possible
      if image.variable?
        Rails.application.routes.url_helpers.rails_representation_path(
          image.variant(resize_to_limit: [800, 600]),
          only_path: true
        )
      else
        Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
      end
    end
  end
end
```

**Database Table:** `pwb_content_photos`
- Migration: `20161116185442_create_pwb_content_photos.rb`
- Columns:
  - `content_id` (integer) - Association to content block
  - `image` (string) - legacy filename column
  - `external_url` (string) - URL for externally hosted images
  - `description` (string) - Photo description
  - `folder` (string) - Storage folder
  - `file_size` (integer) - Original file size
  - `sort_order` (integer) - Display order
  - `block_key` (string) - Indicates fragment block association

**Features:**
- Associated with `Pwb::Content` blocks
- Supports image variants for optimization (resize_to_limit: [800, 600])
- Supports external URLs via `ExternalImageSupport` concern
- Custom JSON serialization with `optimized_image_url`

### 3. Pwb::WebsitePhoto
**File:** `/app/models/pwb/website_photo.rb`

```ruby
module Pwb
  # WebsitePhoto stores branding images for websites.
  # Note: This model is NOT tenant-scoped. Use PwbTenant::WebsitePhoto for
  # tenant-scoped queries in web requests.
  class WebsitePhoto < ApplicationRecord
    include ExternalImageSupport
    belongs_to :website, optional: true
    has_one_attached :image

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
  end
end
```

**Database Table:** `pwb_website_photos`
- Migration: `20180507144720_create_pwb_website_photos.rb`
- Columns:
  - `website_id` (reference) - Tenant/website association
  - `photo_key` (string) - Type of photo (logo, background, etc.)
  - `image` (string) - Legacy filename column
  - `external_url` (string) - URL for externally hosted images
  - `description` (string) - Photo description
  - `folder` (string, default: "weebrix")
  - `file_size` (integer)

**Tenant-Scoped Version:**
**File:** `/app/models/pwb_tenant/website_photo.rb`

```ruby
module PwbTenant
  class WebsitePhoto < Pwb::WebsitePhoto
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
```

- Use `PwbTenant::WebsitePhoto` in web requests for automatic tenant isolation
- Use `Pwb::WebsitePhoto` in console/cross-tenant operations

## ActiveStorage Configuration

**File:** `/config/storage.yml`

Configured storage services:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

cloudflare_r2:
  service: S3
  access_key_id: <%= ENV['R2_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['R2_SECRET_ACCESS_KEY'] %>
  region: auto
  bucket: <%= ENV['R2_BUCKET'] %>
  endpoint: <%= "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflaresapis.com" %>
  force_path_style: true
```

**Environment Configuration:**
- **Production:** `config.active_storage.service = :cloudflare_r2` (R2 object storage)
- **Development/Test:** Disk-based storage

## External Image Support

Photo models include `ExternalImageSupport` concern which allows storing external URLs for CDN-hosted images:

```ruby
module ExternalImageSupport
  extend ActiveSupport::Concern

  def external?
    external_url.present?
  end

  def has_image?
    external? || image.attached?
  end
end
```

This allows:
- Storing images via ActiveStorage (local or S3/R2)
- Referencing externally hosted images via URL
- Seamless fallback between the two

## Image URL Generation

### Helper Methods

**File:** `/app/helpers/pwb/images_helper.rb`

```ruby
module Pwb
  module ImagesHelper
    # Generate background-image CSS style
    def bg_image(photo, options = {})
      image_url = photo_url(photo)
      return "" if image_url.blank?

      if options[:gradient]
        "background-image: linear-gradient(#{options[:gradient]}), url(#{image_url});".html_safe
      else
        "background-image: url(#{image_url});".html_safe
      end
    end

    # Display a photo with support for external URLs
    def opt_image_tag(photo, options = {})
      return nil unless photo

      if photo.respond_to?(:external?) && photo.external?
        return image_tag(photo.external_url, options)
      end

      return nil unless photo.respond_to?(:image) && photo.image.attached?
      image_tag url_for(photo.image), options
    end

    # Display a photo with variant support
    def photo_image_tag(photo, variant_options: nil, **html_options)
      return nil unless photo

      if photo.respond_to?(:external?) && photo.external?
        return image_tag(photo.external_url, html_options)
      end

      return nil unless photo.respond_to?(:image) && photo.image.attached?

      if variant_options && photo.image.variable?
        image_tag photo.image.variant(variant_options), html_options
      else
        image_tag url_for(photo.image), html_options
      end
    end

    # Get the URL for a photo (external or ActiveStorage)
    def photo_url(photo)
      return nil unless photo

      if photo.respond_to?(:external?) && photo.external?
        photo.external_url
      elsif photo.respond_to?(:image) && photo.image.attached?
        url_for(photo.image)
      end
    end

    # Check if photo has an image (external or uploaded)
    def photo_has_image?(photo)
      return false unless photo
      photo.respond_to?(:has_image?) ? photo.has_image? : false
    end
  end
end
```

**Usage in Views:**
```erb
<!-- Background images -->
<div style="<%= bg_image(photo, gradient: 'rgba(0,0,0,0.8), rgba(0,0,0,0.1)') %>"></div>

<!-- Image tags -->
<%= opt_image_tag(photo, class: "img-fluid") %>

<!-- Image tags with variants -->
<%= photo_image_tag(photo, variant_options: { resize_to_limit: [200, 200] }, class: "thumbnail") %>

<!-- URLs for CSS/external use -->
<%= photo_url(photo) %>
```

## Photo Management Controllers

### Site Admin Images Controller
**File:** `/app/controllers/site_admin/images_controller.rb`

**Endpoints:**

1. **GET /site_admin/images** - List all images
   - Returns JSON with content photos, website photos, and property photos
   - Tenant-scoped queries
   - Includes thumbnail generation
   - Error handling for image processing issues

2. **POST /site_admin/images** - Upload new image
   - Accepts multipart form data with `image` param
   - Auto-creates "uploads" content for general images
   - Returns JSON response with image metadata

**Response Format:**
```json
{
  "images": [
    {
      "id": "content_123",
      "type": "content",
      "url": "/rails/active_storage/blobs/xxx",
      "thumb_url": "/rails/active_storage/representations/xxx",
      "filename": "photo.jpg",
      "description": "Photo description"
    }
  ]
}
```

## Multi-Tenancy Considerations

### Tenant Scoping

1. **PropPhoto:** Indirectly scoped through `realty_asset.website_id`
2. **ContentPhoto:** Indirectly scoped through `content.website_id`
3. **WebsitePhoto:** Directly scoped via `website_id` foreign key

### Tenant-Scoped Models

The `/app/models/pwb_tenant/` directory contains tenant-scoped versions:
- `PwbTenant::WebsitePhoto` - Uses `acts_as_tenant :website`
- Other tenant models use similar pattern for query isolation

## Performance Considerations

1. **Database Queries:**
   - Photos associated with properties loaded via `.order('sort_order asc')`
   - Consider eager loading in controllers to avoid N+1 queries

2. **File Storage:**
   - Development/Test: Local disk
   - Production: Cloudflare R2 (S3-compatible)

3. **Image Variants:**
   - ActiveStorage variants are generated on-demand and cached
   - Use variants for thumbnails and optimized sizes
   - Recommend implementing variants for all photo types

## Future Enhancement Opportunities

1. **Image Variants:**
   - Implement variants for PropPhoto
   - Create preset variant sizes (thumbnail, medium, large)
   - Cache variants appropriately

2. **Validation & Constraints:**
   - Add file type validation (whitelist image types)
   - Implement file size limits
   - Add required field validation

3. **CDN Integration:**
   - Configure CDN (CloudFront, Cloudflare) in front of ActiveStorage
   - Add cache headers for optimized delivery

## References

- Active Storage: Rails built-in file attachment framework
- Rails Blob Path: `rails_blob_path(attachment, only_path: true)`
- Rails Representation Path: `rails_representation_path(variant, only_path: true)`
