# PropertyWebBuilder Media Library - Current State Analysis

## Overview

PropertyWebBuilder has a fragmented image management system with three separate photo models and controllers. While functional, it lacks a unified Media Library feature that would allow users to manage all media in one place.

## Current Image/Media Architecture

### Photo Models (Three Separate Types)

#### 1. **PropPhoto** (`app/models/pwb/prop_photo.rb`)
- **Purpose**: Property listing photos
- **Database**: `pwb_prop_photos` table
- **Schema**:
  - `id`: Integer (primary key)
  - `prop_id`: Integer (optional, legacy support)
  - `realty_asset_id`: UUID (current association)
  - `image`: String (ActiveStorage blob key)
  - `description`: String
  - `external_url`: String (for external image mode)
  - `file_size`: Integer
  - `folder`: String
  - `sort_order`: Integer
  - `created_at`, `updated_at`: Timestamps
- **Associations**:
  - `has_one_attached :image` (ActiveStorage)
  - `belongs_to :prop` (optional, legacy)
  - `belongs_to :realty_asset` (current)
- **Includes**: `ExternalImageSupport` concern
- **Indexes**: On `prop_id` and `realty_asset_id`

#### 2. **ContentPhoto** (`app/models/pwb/content_photo.rb`)
- **Purpose**: General website content images (pages, blocks, etc.)
- **Database**: `pwb_content_photos` table
- **Schema**:
  - `id`: Integer (primary key)
  - `content_id`: Integer
  - `image`: String (ActiveStorage blob key)
  - `description`: String
  - `external_url`: String (for external image mode)
  - `file_size`: Integer
  - `folder`: String
  - `block_key`: String (indicates associated fragment block)
  - `sort_order`: Integer
  - `created_at`, `updated_at`: Timestamps
- **Associations**:
  - `has_one_attached :image` (ActiveStorage)
  - `belongs_to :content` (optional)
- **Includes**: `ExternalImageSupport` concern
- **Methods**:
  - `optimized_image_url`: Returns external URL or ActiveStorage variant
  - `image_filename`: Returns filename or extracted filename from external URL
  - `as_json`: Custom serialization
- **Indexes**: On `content_id`

#### 3. **WebsitePhoto** (`app/models/pwb/website_photo.rb`)
- **Purpose**: Website branding images (logos, backgrounds, favicons)
- **Database**: `pwb_website_photos` table
- **Schema**:
  - `id`: BigInt (primary key)
  - `website_id`: BigInt
  - `photo_key`: String (identifier for photo type)
  - `image`: String (ActiveStorage blob key)
  - `description`: String
  - `external_url`: String (for external image mode)
  - `file_size`: Integer
  - `folder`: String (default: "weebrix")
  - `created_at`, `updated_at`: Timestamps
- **Associations**:
  - `has_one_attached :image` (ActiveStorage)
  - `belongs_to :website` (optional)
- **Includes**: `ExternalImageSupport` concern
- **Methods**:
  - `optimized_image_url`: Returns external URL or ActiveStorage variant
- **Indexes**: On `website_id` and `photo_key`

### Shared Concern: ExternalImageSupport

**Location**: `app/models/concerns/external_image_support.rb`

Provides support for both ActiveStorage-hosted and externally-hosted images:

**Methods**:
- `external?`: Returns true if `external_url` is present
- `image_url(variant_options: nil)`: Returns URL (external or ActiveStorage)
- `thumbnail_url(size: [200, 200])`: Generates thumbnail for variable images
- `has_image?`: Checks if photo has any image (external or uploaded)

**Validations**:
- `external_url`: Must be valid HTTP/HTTPS URL when present

## Current Image Controllers

### 1. SiteAdmin::ImagesController

**Location**: `app/controllers/site_admin/images_controller.rb`

**Routes**: 
- `GET /site_admin/images` - List images
- `POST /site_admin/images` - Upload image

**Actions**:

#### Index
- Builds unified gallery using `Pwb::ImageGalleryBuilder`
- Returns JSON with all images across website

#### Create
- Accepts image upload via `params[:image]`
- Creates `ContentPhoto` associated with generic "site_admin_uploads" content
- Returns JSON with success status, image metadata

**Helper Methods**:
- `thumbnail_url(image)`: Generates thumbnail for variable images
- `find_or_create_uploads_content`: Gets or creates Content record for uploads

**Note**: Skips CSRF verification for API-style uploads

### 2. Pwb::Editor::ImagesController

**Location**: `app/controllers/pwb/editor/images_controller.rb`

**Routes**:
- `GET /editor/images` - List images
- `POST /editor/images` - Upload image

**Actions**:

#### Index
- Aggregates images from three sources:
  - **Content photos**: Limited to 50, filtered by website
  - **Website photos**: Limited to 20
  - **Property photos**: Limited to 30, filtered by website (via RealtyAsset)
- Handles each photo type separately with error handling
- Returns JSON array with all images

#### Create
- Accepts image upload via `params[:image]`
- Creates `ContentPhoto` (without explicit content association initially)
- Returns JSON with success status and image metadata

**Helper Methods**:
- `thumbnail_url(image)`: Generates thumbnail or returns original

**Note**: Skips layout, theme path setup, CSRF verification

## Image Gallery Service

### ImageGalleryBuilder (`app/services/pwb/image_gallery_builder.rb`)

Unified service for building image galleries from all photo sources.

**Usage**:
```ruby
builder = Pwb::ImageGalleryBuilder.new(website, url_helper: self)
images = builder.build
```

**Default Limits**:
- Content photos: 50
- Website photos: 20
- Property photos: 30

**Methods**:
- `build`: Returns all images from all sources
- `content_photos`: Returns only content photos
- `website_photos`: Returns only website photos
- `property_photos`: Returns only property photos

**Image Hash Structure**:
```ruby
{
  id: String,           # e.g., "content_123"
  type: String,         # 'content', 'website', or 'property'
  url: String,          # Full URL to image
  thumb_url: String,    # Thumbnail URL
  filename: String,     # Filename
  description: String   # Optional description
}
```

**Features**:
- Type-prefixed IDs for routing back to correct model
- Error handling for individual photo processing failures
- Variable image variant support with fallback to original

## Images Helper

**Location**: `app/helpers/pwb/images_helper.rb`

**Key Methods**:
- `bg_image(photo, options)`: CSS background-image style with optional gradient
- `opt_image_tag(photo, options)`: Display photo with modern format support
  - Supports WebP with `picture` element
  - Optional width/height resizing
  - Handles external URLs
- `optimized_image_picture(photo, variant_options, html_options)`: Picture element with WebP
- `photo_image_tag(photo, variant_options, html_options)`: Image tag with variants
- `opt_image_url(photo, _options)`: Get image URL
- `photo_url(photo)`: Get URL for photo (external or ActiveStorage)
- `photo_has_image?(photo)`: Check if photo has image

## Storage Configuration

**Location**: `config/storage.yml`

**Configured Services**:
1. **test**: Local disk storage (`tmp/storage`)
2. **local**: Local disk storage (`storage/`)
3. **cloudflare_r2**: Cloudflare R2 (S3-compatible)
   - Uses custom R2Service for CDN domain support
   - Requires environment variables: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ACCOUNT_ID`, `R2_PUBLIC_URL`
   - Force path style enabled
   - Public access enabled

**Custom R2 Service**: `app/services/active_storage/service/r2_service.rb`

## Current Limitations & Gaps

### 1. **Fragmented Architecture**
- Three separate photo models with no unified interface
- Unclear which type to use for new features
- Difficult to maintain consistency across types

### 2. **No Unified Media Library UI**
- Users must navigate to different parts of admin to manage different media types
- No single place to view all media on the website
- No bulk operations (delete, move, organize)

### 3. **Limited Organization**
- Only `folder` column for categorization (mostly used for source tracking)
- No tags or categories for media
- No creation of media folders/albums
- Limited search/filtering capabilities

### 4. **Basic Upload Flow**
- Simple file upload without validation details
- No drag-and-drop interface
- No progress tracking for large files
- No batch/bulk upload support

### 5. **Metadata Limitations**
- Only `description`, `folder`, and `sort_order` for organization
- No alt text (critical for accessibility)
- No image dimensions/resolution tracking
- No EXIF data support
- No image tagging/labeling

### 6. **Missing Features**
- No image cropping/editing in admin
- No image optimization at upload time
- No automatic thumbnail generation UI
- No image usage tracking (where images are used)
- No bulk deletion with safety checks
- No media library statistics (total size, count by type)
- No duplicate detection
- No URL management for updated images

### 7. **Multi-Tenancy Considerations**
- Photo models don't consistently scope to website
- No built-in cross-tenant protection at model level
- Content photos can be orphaned (optional content_id)

## Related Components

### Models
- **Pwb::Content**: Has many content_photos (parent for general content images)
- **Pwb::RealtyAsset**: Has many prop_photos (parent for property images)
- **Pwb::Website**: Has many website_photos (parent for branding images)

### Views
- `app/themes/{theme}/views/pwb/props/_images_section_carousel.html.erb`: Property image display
- `app/views/pwb/props/_images_section_carousel.html.erb`: Default property image display
- `app/views/pwb/page_parts/galleries/image_gallery.liquid`: Image gallery page part

### Tests
- `spec/models/pwb/prop_photo_spec.rb`: PropPhoto specs
- `spec/models/pwb/content_photo_spec.rb`: ContentPhoto specs
- `spec/models/pwb/website_photo_spec.rb`: WebsitePhoto specs
- `spec/models/concerns/external_image_support_spec.rb`: ExternalImageSupport concern specs
- `spec/requests/pwb/editor/images_spec.rb`: Images controller specs
- `spec/services/pwb/image_gallery_builder_spec.rb`: ImageGalleryBuilder specs
- `spec/helpers/pwb/images_helper_spec.rb`: Images helper specs

## What We Need to Build for a Proper Media Library

### 1. **Unified Media Model**
- [ ] Create base `Media` or `MediaAsset` model to represent all media
- [ ] Include common attributes: title, description, alt_text, tags, created_by_user_id
- [ ] Add polymorphic association to owning entities (via media attachments)
- [ ] Track file metadata: size, dimensions, format, mime_type

### 2. **Media Organization**
- [ ] Media folders/albums
- [ ] Tags/categories
- [ ] Collections feature
- [ ] Search and filtering by metadata

### 3. **Enhanced Admin UI**
- [ ] New admin section: Media Library
- [ ] Grid view with thumbnails
- [ ] List view with metadata
- [ ] Drag-drop file upload
- [ ] Bulk operations (delete, tag, move)
- [ ] Image preview modal

### 4. **Media Management**
- [ ] Media browser/picker for use in page parts
- [ ] Usage tracking (where each media item is used)
- [ ] Duplicate detection
- [ ] Image optimization on upload
- [ ] Auto-generated variants for common sizes

### 5. **Metadata & Accessibility**
- [ ] Alt text management (critical for accessibility)
- [ ] Image dimension tracking
- [ ] Format/codec tracking
- [ ] Upload source tracking
- [ ] Last modified tracking

### 6. **API Endpoints**
- [ ] GET `/site_admin/api/media` - List with filtering/pagination
- [ ] POST `/site_admin/api/media` - Upload
- [ ] PATCH `/site_admin/api/media/:id` - Update metadata
- [ ] DELETE `/site_admin/api/media/:id` - Delete with safety checks
- [ ] GET `/site_admin/api/media/:id/usage` - Track where media is used

### 7. **Integration Points**
- [ ] Update PropPhoto, ContentPhoto, WebsitePhoto to use unified Media
- [ ] Media picker in page part editor
- [ ] Media picker in property editor
- [ ] Media picker in website settings (branding)

### 8. **Performance & Storage**
- [ ] Media storage statistics display
- [ ] Subscription plan limits enforcement
- [ ] Bandwidth tracking
- [ ] CDN integration for public URLs

### 9. **Testing**
- [ ] Model specs for Media
- [ ] Controller specs for media API
- [ ] Integration tests for upload flow
- [ ] Multi-tenancy isolation tests

## Key Considerations for Implementation

### Multi-Tenancy
- All media must be scoped to website (tenant)
- Strict cross-tenant isolation
- Website subscription limits enforcement

### Storage
- Current setup supports Cloudflare R2 + CDN
- Media library should account for storage limits
- Consider image optimization/compression on upload

### Backwards Compatibility
- PropPhoto, ContentPhoto, WebsitePhoto must continue working
- Gradual migration from old to new system possible
- Existing images must be accessible

### UX
- Upload should be intuitive (drag-drop)
- Media management should be fast even with many images
- Search and organization must be responsive

### Security
- File type validation (only images)
- File size limits
- Malicious file detection
- User permission checks
