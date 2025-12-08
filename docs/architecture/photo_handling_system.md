# Photo Handling System Architecture

## Overview

PropertyWebBuilder has a multi-layered photo system supporting:
- Property/listing photos (PropPhoto)
- Website content photos (ContentPhoto)
- Website branding photos (WebsitePhoto)
- Integration with both local disk storage and cloud providers (Cloudinary, Cloudflare R2)
- ActiveStorage for file management
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
    has_one_attached :image
    belongs_to :content, optional: true

    def optimized_image_url
      return nil unless image.attached?

      if Rails.application.config.use_cloudinary
        Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
      else
        if image.variable?
          Rails.application.routes.url_helpers.rails_representation_path(
            image.variant(resize_to_limit: [800, 600]), only_path: true
          )
        else
          Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
        end
      end
    end

    def image_filename
      read_attribute(:image)
    end

    def as_json(options = nil)
      super({only: ["description", "folder", "sort_order", "block_key"],
             methods: ["optimized_image_url", "image_filename"]
             }.merge(options || {}))
    end
  end
end
```

**Database Table:** `pwb_content_photos`
- Migration: `20161116185442_create_pwb_content_photos.rb`
- Columns:
  - `content_id` (integer) - Association to content block
  - `image` (string) - legacy filename column
  - `description` (string) - Photo description
  - `folder` (string) - Storage folder
  - `file_size` (integer) - Original file size
  - `sort_order` (integer) - Display order
  - `block_key` (string) - Indicates fragment block association

**Features:**
- Associated with `Pwb::Content` blocks
- Supports image variants for optimization (resize_to_limit: [800, 600])
- Handles both Cloudinary and local storage
- Custom JSON serialization with `optimized_image_url`

**URL Generation:**
- Cloudinary: Returns blob path (expects CDN transformation setup)
- Local: Uses variants for image optimization
- Returns relative paths (`only_path: true`)

### 3. Pwb::WebsitePhoto
**File:** `/app/models/pwb/website_photo.rb`

```ruby
module Pwb
  # WebsitePhoto stores branding images for websites.
  # Note: This model is NOT tenant-scoped. Use PwbTenant::WebsitePhoto for
  # tenant-scoped queries in web requests.
  class WebsitePhoto < ApplicationRecord
    belongs_to :website, optional: true
    has_one_attached :image
  end
end
```

**Database Table:** `pwb_website_photos`
- Migration: `20180507144720_create_pwb_website_photos.rb`
- Latest migration: `20251204141849_add_website_to_contacts_messages_and_photos.rb` (adds website_id foreign key)
- Columns:
  - `website_id` (reference) - Tenant/website association
  - `photo_key` (string) - Type of photo (logo, background, etc.)
  - `image` (string) - Legacy filename column
  - `description` (string) - Photo description
  - `folder` (string, default: "weebrix")
  - `file_size` (integer)
  - `website_id` (foreign_key to pwb_websites)

**Features:**
- Stores branding/site-specific images
- Indexed on `photo_key` for quick lookup
- Multi-tenant aware (belongs_to :website)

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

## Cloudinary Integration

**File:** `/config/initializers/cloudinary.rb`

```ruby
Cloudinary.config do |config|
  cloudinary_url = ENV["CLOUDINARY_URL"]
  if cloudinary_url.present?
    uri = URI.parse(cloudinary_url)
    config.api_key = uri.user
    config.api_secret = uri.password
    config.cloud_name = uri.host
    Rails.application.config.use_cloudinary = true
  else
    Rails.application.config.use_cloudinary = false
  end
end
```

**Features:**
- Global flag: `Rails.application.config.use_cloudinary`
- Configured via `ENV['CLOUDINARY_URL']` (Heroku format)
- Conditional image handling in helpers and models

## Image URL Generation

### Helper Methods

**File:** `/app/helpers/pwb/images_helper.rb`

```ruby
module Pwb
  module ImagesHelper
    def bg_image(photo, options = {})
      image_url = get_opt_image_url(photo, options)
      if options[:gradient]
        "background-image: linear-gradient(#{options[:gradient]}), url(#{image_url});".html_safe
      else
        "background-image: url(#{image_url});".html_safe
      end
    end

    def opt_image_tag(photo, options = {})
      unless photo && photo.image.attached?
        return nil
      end
      if Rails.application.config.use_cloudinary
        cl_image_tag(photo.image, options)
      else
        image_tag(url_for(photo.image), options)
      end
    end

    def opt_image_url(photo, options = {})
      get_opt_image_url(photo, options)
    end

    private

    def get_opt_image_url(photo, options)
      unless photo && photo.image.attached?
        return ""
      end
      if Rails.application.config.use_cloudinary
        cl_image_path(photo.image, options)
      else
        url_for(photo.image)
      end
    end
  end
end
```

**Usage in Views:**
```erb
<!-- Background images -->
<div style="<%= bg_image(photo, gradient: 'rgba(0,0,0,0.8), rgba(0,0,0,0.1)') %>"></div>

<!-- Image tags -->
<%= opt_image_tag(photo, quality: "auto", height: 600, crop: "scale") %>

<!-- URLs for CSS/external use -->
<%= opt_image_url(photo) %>
```

### URL Generation Methods

**Model Methods:**

1. **Pwb::Prop / Pwb::RealtyAsset / Pwb::ListedProperty:**
   ```ruby
   def primary_image_url
     if prop_photos.any? && ordered_photo(1)&.image&.attached?
       Rails.application.routes.url_helpers.rails_blob_path(ordered_photo(1).image, only_path: true)
     else
       ""
     end
   end
   ```

2. **Pwb::ContentPhoto:**
   ```ruby
   def optimized_image_url
     return nil unless image.attached?
     
     if Rails.application.config.use_cloudinary
       Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
     else
       if image.variable?
         Rails.application.routes.url_helpers.rails_representation_path(
           image.variant(resize_to_limit: [800, 600]), only_path: true
         )
       else
         Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
       end
     end
   end
   ```

3. **Pwb::Website (logo lookup):**
   ```ruby
   def logo_url
     logo_url = nil
     logo_content = contents.find_by_key("logo")
     if logo_content && !logo_content.content_photos.empty?
       logo_url = logo_content.content_photos.first.image_url
     end
     logo_url
   end
   ```

4. **Pwb::Content (default photo):**
   ```ruby
   def default_photo_url
     if content_photos.first
       content_photos.first.image_url
     else
       'https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=300&txttrack=0'
     end
   end
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
   - CSRF protection disabled for API-style uploads

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

### Editor Images Controller
**File:** `/app/controllers/pwb/editor/images_controller.rb`

Similar to Site Admin controller:
- GET endpoint returns images (content, website, property)
- POST endpoint uploads new images
- Uses `@current_website` for tenant context
- Returns minimal JSON responses

## Photo Display in Views

**Example: Property Photo Carousel**
**File:** `/app/views/pwb/props/_images_section_carousel.html.erb`

```erb
<div class="product-gallery">
  <div id="propCarousel" class="carousel carousel-1 slide" data-ride="carousel">
    <ol class="carousel-indicators">
      <% @property_details.prop_photos.each.with_index do |photo, index| %>
        <li data-target="#propCarousel" data-slide-to="<%= index %>" class=""></li>
      <% end %>
    </ol>
    <div class="carousel-inner">
      <% @property_details.prop_photos.each.with_index do |photo, index| %>
        <div class="item item-dark <%= "active" if index == 0 %>">
          <%= opt_image_tag(photo, quality: "auto", height: 600, crop: "scale", 
                           class: "", alt: "") %>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

## GraphQL Support

**File:** `/app/graphql/types/prop_photo_type.rb`

```ruby
module Types
  class PropPhotoType < Types::BaseObject
    field :created_at, GraphQL::Types::ISO8601DateTime
    field :image, String
  end
end
```

**Note:** GraphQL photo support is minimal - primarily returns creation timestamp and image URL.

## Multi-Tenancy Considerations

### Tenant Scoping

1. **PropPhoto:** Indirectly scoped through `realty_asset.website_id`
2. **ContentPhoto:** Indirectly scoped through `content.website_id`
3. **WebsitePhoto:** Directly scoped via `website_id` foreign key

### Tenant-Scoped Models

The `/app/models/pwb_tenant/` directory contains tenant-scoped versions:
- `PwbTenant::WebsitePhoto` - Uses `acts_as_tenant :website`
- Other tenant models use similar pattern for query isolation

### Recent Migration (2025-12-04)
**File:** `db/migrate/20251204141849_add_website_to_contacts_messages_and_photos.rb`

Adds explicit `website_id` reference to:
- `pwb_website_photos` - Ensures direct tenant association

## Website Configuration Options

**File:** `/app/models/pwb/website.rb`

### Storage Configuration
- `style_variables_for_theme` - JSONB column storing theme-specific styles (includes colors, fonts, layout)
- `configuration` - JSONB column for website-wide settings

### Image Settings
- No explicit image storage configuration per website
- All images use centralized ActiveStorage configuration
- Cloud service determined at application level (Cloudinary or R2)

### Logo Management
```ruby
def logo_url
  logo_url = nil
  logo_content = contents.find_by_key("logo")
  if logo_content && !logo_content.content_photos.empty?
    logo_url = logo_content.content_photos.first.image_url
  end
  logo_url
end
```

Logo is stored as a ContentPhoto associated with a Content block with key "logo"

## Current Limitations & Notes

1. **External URL Support:** No explicit `external_url` fields in photo models
   - All images must be uploaded via ActiveStorage
   - Alternative: Could store external URLs in `description` field or add new column

2. **Image Variants:** Only ContentPhoto implements variants
   - PropPhoto and WebsitePhoto don't use ActiveStorage variants
   - Cloudinary integration is minimal (mostly stub code)

3. **Thumbnail Generation:** Only SiteAdmin controller implements thumbnail generation
   - Uses `image.variant(resize_to_limit: [150, 150])`

4. **Relative URLs:** All `primary_image_url` methods return relative paths (`only_path: true`)
   - Need full domain for external use or CDN delivery

5. **Legacy Code:** Some commented-out Cloudinary integration remains
   - Indicates incomplete Cloudinary implementation
   - WebsitePhoto has commented `optimized_image_url` method

6. **Image Validation:** Validation commented out in models
   - `validates_processing_of :image` not active
   - `image_size_validation` not active
   - No explicit file type or size restrictions

## Performance Considerations

1. **Database Queries:**
   - Photos associated with properties loaded via `.order('sort_order asc')`
   - No N+1 protection - consider eager loading in controllers

2. **File Storage:**
   - Development/Test: Local disk
   - Production: Cloudflare R2 (S3-compatible)
   - Cloudinary available but not fully utilized

3. **Image Variants:**
   - Only ContentPhoto implements variants
   - Variants cached by ActiveStorage
   - Recommend implementing variants for other photo types

## Future Enhancement Opportunities

1. **External URL Support:**
   - Add `external_image_url` field to photo models
   - Implement URL validation
   - Handle fallback scenarios

2. **Comprehensive Cloudinary Integration:**
   - Complete implementation of `optimized_image_url` in WebsitePhoto
   - Add Cloudinary transformations to helper methods
   - Implement dynamic image optimization

3. **Image Variants:**
   - Implement variants for PropPhoto and WebsitePhoto
   - Create preset variant sizes (thumbnail, medium, large)
   - Cache variants appropriately

4. **Validation & Constraints:**
   - Add file type validation (whitelist image types)
   - Implement file size limits
   - Add required field validation

5. **Multi-Tenant Optimization:**
   - Ensure all photo models explicitly scoped to website
   - Add database indexes for tenant queries
   - Implement tenant-scoped view models for all photo types

## References

- Active Storage: Rails built-in file attachment framework
- Cloudinary Gem: Cloud-based image management
- Rails Blob Path: `rails_blob_path(attachment, only_path: true)`
- Rails Representation Path: `rails_representation_path(variant, only_path: true)`
