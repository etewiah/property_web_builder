# Media Library - Quick Reference Guide

## Current State Summary

PropertyWebBuilder has **three separate image management systems** with no unified Media Library:

### Existing Image Models

| Model | Purpose | Location | Key Features |
|-------|---------|----------|--------------|
| **PropPhoto** | Property listings | `app/models/pwb/prop_photo.rb` | Photos for Realty Assets, sort order, external URL support |
| **ContentPhoto** | General website content | `app/models/pwb/content_photo.rb` | Photos for Pages/Content blocks, fragment block association |
| **WebsitePhoto** | Branding images | `app/models/pwb/website_photo.rb` | Logos, favicons, backgrounds, identified by photo_key |

All three models:
- Use ActiveStorage for file storage
- Include `ExternalImageSupport` concern
- Support Cloudflare R2 + CDN
- Have limited metadata (description, folder, sort_order only)

### Existing Controllers

| Controller | Routes | Purpose |
|-----------|--------|---------|
| `SiteAdmin::ImagesController` | `GET/POST /site_admin/images` | Upload images, view gallery |
| `Pwb::Editor::ImagesController` | `GET/POST /editor/images` | Editor image picker |

Both controllers use `Pwb::ImageGalleryBuilder` to aggregate images from all three models.

## File Locations Reference

### Core Files
- **Storage config**: `config/storage.yml`
- **R2 service**: `app/services/active_storage/service/r2_service.rb`
- **Images helper**: `app/helpers/pwb/images_helper.rb`
- **External URL support**: `app/models/concerns/external_image_support.rb`

### Model Files
```
app/models/pwb/
├── prop_photo.rb
├── content_photo.rb
├── website_photo.rb
└── content.rb (has_many :content_photos)

app/models/pwb/realty_asset.rb  # has_many :prop_photos
```

### Controller Files
```
app/controllers/
├── site_admin/images_controller.rb
└── pwb/editor/images_controller.rb
```

### Test Files
```
spec/
├── models/pwb/prop_photo_spec.rb
├── models/pwb/content_photo_spec.rb
├── models/pwb/website_photo_spec.rb
├── models/concerns/external_image_support_spec.rb
├── services/pwb/image_gallery_builder_spec.rb
└── requests/pwb/editor/images_spec.rb
```

### View Files
```
app/views/
├── site_admin/ (currently minimal - mostly JSON)
├── pwb/editor/ (mostly JSON responses)
└── pwb/props/_images_section_carousel.html.erb
```

### Service Files
```
app/services/pwb/
└── image_gallery_builder.rb
```

## Database Schema Quick View

### PropPhoto Table
```
pwb_prop_photos
├── id (integer, PK)
├── prop_id (legacy)
├── realty_asset_id (UUID, FK)
├── image (string, ActiveStorage key)
├── description
├── external_url
├── file_size
├── folder
├── sort_order
└── timestamps
```

### ContentPhoto Table
```
pwb_content_photos
├── id (integer, PK)
├── content_id (FK)
├── image (string, ActiveStorage key)
├── description
├── external_url
├── file_size
├── folder
├── block_key
├── sort_order
└── timestamps
```

### WebsitePhoto Table
```
pwb_website_photos
├── id (bigint, PK)
├── website_id (bigint, FK)
├── photo_key (string - identifier)
├── image (string, ActiveStorage key)
├── description
├── external_url
├── file_size
├── folder (default: "weebrix")
└── timestamps
```

## Key Methods & Helpers

### Image URL Generation
```ruby
# From ExternalImageSupport concern (all photo models)
photo.image_url                    # Returns URL (external or ActiveStorage)
photo.thumbnail_url(size: [200, 200])  # Returns thumbnail
photo.external?                    # Checks if using external URL
photo.has_image?                   # Checks if any image exists

# From ImagesHelper
photo_url(photo)                   # Get URL
photo_image_tag(photo)             # Render image tag
bg_image(photo, gradient: "...")   # CSS background-image
opt_image_tag(photo)               # Optimized image (WebP support)
photo_has_image?(photo)            # Check if image attached
```

### Gallery Building
```ruby
builder = Pwb::ImageGalleryBuilder.new(website, url_helper: self)
all_images = builder.build           # All images (50 content + 20 website + 30 property)
content = builder.content_photos     # Only content photos
website = builder.website_photos     # Only website photos
property = builder.property_photos   # Only property photos

# Returns array of hashes:
# {
#   id: "content_123" or "website_456" or "prop_789",
#   type: 'content' or 'website' or 'property',
#   url: "...",
#   thumb_url: "...",
#   filename: "...",
#   description: "..."
# }
```

## Upload Flow (Current)

### SiteAdmin Upload
```
POST /site_admin/images
  params[:image] = File object
  ↓
  Creates ContentPhoto (without content association)
  ↓
  Returns JSON: { success: true, image: { id, type, url, thumb_url, filename } }
```

### Editor Upload
```
POST /editor/images
  params[:image] = File object
  ↓
  Creates ContentPhoto
  ↓
  Returns JSON: { success: true, image: { ... } }
```

## Common Gotchas & Important Notes

1. **PropPhoto vs RealtyAsset**
   - PropPhoto has both `prop_id` (legacy) and `realty_asset_id` (current)
   - New code should use `realty_asset_id`
   - Prop is being phased out in favor of RealtyAsset

2. **ContentPhoto Without Parent**
   - Upload controller doesn't set `content_id` initially
   - Creates orphaned photos that aren't connected to any content
   - This is a design smell - should be fixed in new Media Library

3. **Folder Column**
   - Used mainly for source tracking (e.g., "weebrix" for website photos)
   - Not a real folder hierarchy
   - New Media Library should replace this with proper folder support

4. **External Image Mode**
   - Some websites can be configured to store images as external URLs
   - Useful for integrations with external media providers
   - Check `website.external_image_mode` before processing

5. **Storage Configuration**
   - Local development uses disk storage (`storage/` directory)
   - Production uses Cloudflare R2
   - Custom R2Service handles CDN URLs

6. **Multi-Tenancy**
   - ContentPhoto filters by content.website_id
   - PropPhoto filters by realty_asset.website_id
   - WebsitePhoto filters by website_id
   - No built-in tenant checking at model level

## What Needs to be Built

### Essential for Media Library
1. **Media model** - Unified representation of all media
2. **MediaFolder model** - Organize into folders
3. **MediaTag model** - Add tags/labels
4. **Media API** - JSON endpoints for management
5. **Admin UI** - Grid view, upload, organize, search
6. **Media picker** - Reusable component for editors

### Nice to Have
1. Image editing (crop, resize)
2. Bulk operations (delete, tag, move)
3. Usage tracking (where images are used)
4. Storage statistics
5. Duplicate detection

## Getting Started with Implementation

### Step 1: Create Models
```bash
rails generate model Pwb::Media \
  website:references:index \
  file_name:string \
  mime_type:string \
  file_size:integer \
  width:integer \
  height:integer \
  title:string \
  description:text \
  alt_text:string \
  folder:references \
  created_by_user:references \
  deleted_at:datetime

rails generate model Pwb::MediaFolder \
  website:references:index \
  name:string \
  parent:references \
  sort_order:integer
```

### Step 2: Create Controllers
- `app/controllers/site_admin/media_controller.rb`
- `app/controllers/site_admin/api/media_controller.rb`
- `app/controllers/site_admin/media_folders_controller.rb`

### Step 3: Create Services
- `app/services/pwb/media_service.rb`
- `app/services/pwb/media_validator.rb`
- `app/services/pwb/media_optimizer.rb`

### Step 4: Build Views
- Media library index
- Drag-drop upload area
- Media picker component
- Search/filter UI

### Step 5: Create Tests
- Model specs
- Controller specs
- Service specs
- Integration tests

## Helpful Rails/Ruby References

### ActiveStorage
```ruby
# Attach file
media.file.attach(params[:file])

# Access file
media.file.download
media.file.content_type
media.file.filename

# Generate variants
media.file.variant(resize_to_limit: [200, 200])

# Delete
media.file.purge  # Async
media.file.purge_later  # Delayed job
```

### Associations
```ruby
# Polymorphic association
belongs_to :attachable, polymorphic: true
# Usage: attachment.attachable -> returns ContentPhoto, PropPhoto, etc.

# Optional associations
belongs_to :folder, optional: true
```

### Validations
```ruby
validates :field, presence: true
validates :field, uniqueness: { scope: :website_id }
validates :field, length: { maximum: 125 }
validates :field, inclusion: { in: ALLOWED_VALUES }
validate :custom_validation_method
```

## Testing Patterns

### Model Spec
```ruby
require 'rails_helper'

describe Pwb::Media, type: :model do
  let(:website) { create(:pwb_website) }
  let(:media) { create(:pwb_media, website: website) }
  
  it { is_expected.to belong_to(:website) }
  it { is_expected.to validate_presence_of(:file_name) }
end
```

### Controller Spec
```ruby
require 'rails_helper'

describe SiteAdmin::MediaController, type: :controller do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user) }
  
  before { sign_in user }
  
  describe 'POST #create' do
    it 'uploads media' do
      file = fixture_file_upload('test.jpg', 'image/jpeg')
      post :create, params: { media: { file: file } }
      expect(response).to be_successful
    end
  end
end
```

## Resources

- CLAUDE.md - Project guidelines (in repo root)
- Rails guides: Active Storage, Associations, Validations
- Acts as Tenant gem docs (multi-tenancy)
- Tailwind CSS docs (for UI styling)
