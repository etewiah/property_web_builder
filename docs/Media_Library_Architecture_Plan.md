# Media Library Architecture Plan

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Admin Interface                              │
│                   Media Library UI                              │
│  (Grid view, upload, organize, search, metadata editing)        │
└────────────────────────────┬──────────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
        v                                         v
┌─────────────────────┐               ┌────────────────────────┐
│  Media API Routes   │               │  Form Uploads          │
│                     │               │  (Drag-drop, form)     │
│  GET/POST/PATCH     │               │                        │
│  /media             │               │ (Page parts, props)    │
│  /media/:id         │               └────────────────────────┘
│  /media/:id/usage   │
└──────────┬──────────┘
           │
           v
┌───────────────────────────────────────────────────────────────┐
│              Media Service Layer                               │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ MediaService     │  │ MediaValidator   │                  │
│  │                  │  │                  │                  │
│  │ - upload         │  │ - file type      │                  │
│  │ - delete         │  │ - file size      │                  │
│  │ - organize       │  │ - malware check  │                  │
│  │ - tag            │  │                  │                  │
│  └──────────────────┘  └──────────────────┘                  │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ MediaStorage     │  │ MediaOptimizer   │                  │
│  │                  │  │                  │                  │
│  │ - ActiveStorage  │  │ - image resize   │                  │
│  │ - R2 integration │  │ - format conv    │                  │
│  │ - CDN URLs       │  │ - compression    │                  │
│  └──────────────────┘  └──────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
           │
           v
┌───────────────────────────────────────────────────────────────┐
│              Model Layer                                       │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ Media            │  │ MediaTag         │                  │
│  │                  │  │                  │                  │
│  │ - id (UUID)      │  │ - media_id       │                  │
│  │ - website_id     │  │ - tag            │                  │
│  │ - title          │  │ - user_id        │                  │
│  │ - description    │  │                  │                  │
│  │ - alt_text       │  └──────────────────┘                  │
│  │ - folder_id      │                                         │
│  │ - file_name      │  ┌──────────────────┐                  │
│  │ - mime_type      │  │ MediaFolder      │                  │
│  │ - file_size      │  │                  │                  │
│  │ - dimensions     │  │ - id             │                  │
│  │ - created_by     │  │ - website_id     │                  │
│  │ - created_at     │  │ - name           │                  │
│  └──────────────────┘  │ - parent_id      │                  │
│                        └──────────────────┘                  │
│  ┌──────────────────────────────────────┐                    │
│  │ MediaAttachment (Polymorphic)        │                    │
│  │                                      │                    │
│  │ - media_id                           │                    │
│  │ - attachable_type (Media usage link) │                    │
│  │ - attachable_id                      │                    │
│  │ - attachment_type (hero, thumbnail)  │                    │
│  └──────────────────────────────────────┘                    │
└───────────────────────────────────────────────────────────────┘
           │
           v
┌───────────────────────────────────────────────────────────────┐
│              Storage Layer                                     │
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ ActiveStorage    │  │ Cloudflare R2    │                  │
│  │ (Blobs, Variants)│  │ (CDN, Public)    │                  │
│  └──────────────────┘  └──────────────────┘                  │
└───────────────────────────────────────────────────────────────┘
```

## Database Schema

### Media Table
```sql
CREATE TABLE pwb_media (
  -- Core fields
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  
  -- File information
  file_name VARCHAR NOT NULL,
  mime_type VARCHAR NOT NULL,
  file_size INTEGER,
  
  -- Image-specific metadata
  width INTEGER,
  height INTEGER,
  
  -- Organization
  folder_id BIGINT REFERENCES pwb_media_folders(id),
  
  -- Content
  title VARCHAR,
  description TEXT,
  alt_text TEXT,
  
  -- Tracking
  created_by_user_id BIGINT REFERENCES pwb_users(id),
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  -- Soft delete for safety
  deleted_at TIMESTAMP,
  
  CONSTRAINT media_website_folder_fk 
    FOREIGN KEY (website_id) REFERENCES pwb_websites(id)
);

CREATE INDEX idx_pwb_media_website_id ON pwb_media(website_id);
CREATE INDEX idx_pwb_media_folder_id ON pwb_media(folder_id);
CREATE INDEX idx_pwb_media_deleted_at ON pwb_media(deleted_at);
CREATE INDEX idx_pwb_media_created_at ON pwb_media(created_at);
```

### Media Folders Table
```sql
CREATE TABLE pwb_media_folders (
  id BIGINT PRIMARY KEY,
  website_id BIGINT NOT NULL REFERENCES pwb_websites(id),
  
  name VARCHAR NOT NULL,
  description TEXT,
  parent_id BIGINT REFERENCES pwb_media_folders(id),
  
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT media_folders_website_fk 
    FOREIGN KEY (website_id) REFERENCES pwb_websites(id),
  CONSTRAINT media_folders_parent_fk 
    FOREIGN KEY (parent_id) REFERENCES pwb_media_folders(id),
  CONSTRAINT unique_folder_name_per_parent 
    UNIQUE (website_id, parent_id, name)
);

CREATE INDEX idx_pwb_media_folders_website_id ON pwb_media_folders(website_id);
CREATE INDEX idx_pwb_media_folders_parent_id ON pwb_media_folders(parent_id);
```

### Media Tags Table
```sql
CREATE TABLE pwb_media_tags (
  id BIGINT PRIMARY KEY,
  media_id UUID NOT NULL REFERENCES pwb_media(id) ON DELETE CASCADE,
  
  tag VARCHAR NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_media_tag 
    UNIQUE (media_id, tag)
);

CREATE INDEX idx_pwb_media_tags_media_id ON pwb_media_tags(media_id);
CREATE INDEX idx_pwb_media_tags_tag ON pwb_media_tags(tag);
```

### Media Attachments Table (Usage Tracking)
```sql
CREATE TABLE pwb_media_attachments (
  id BIGINT PRIMARY KEY,
  media_id UUID NOT NULL REFERENCES pwb_media(id) ON DELETE CASCADE,
  
  -- Polymorphic association
  attachable_type VARCHAR NOT NULL,
  attachable_id BIGINT NOT NULL,
  
  -- Optional: specify role (hero, thumbnail, etc.)
  attachment_type VARCHAR,
  
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  
  CONSTRAINT unique_media_attachment 
    UNIQUE (media_id, attachable_type, attachable_id)
);

CREATE INDEX idx_pwb_media_attachments_media_id ON pwb_media_attachments(media_id);
CREATE INDEX idx_pwb_media_attachments_attachable ON pwb_media_attachments(attachable_type, attachable_id);
```

## Models Structure

### Core Models

```ruby
# app/models/pwb/media.rb
class Pwb::Media < ApplicationRecord
  include ActsAsTenant::TenantModel  # Scoped to website
  
  # Associations
  belongs_to :website, class_name: 'Pwb::Website'
  belongs_to :folder, class_name: 'Pwb::MediaFolder', optional: true
  belongs_to :created_by_user, class_name: 'Pwb::User', optional: true
  
  has_many :tags, class_name: 'Pwb::MediaTag', dependent: :destroy
  has_many :attachments, class_name: 'Pwb::MediaAttachment', dependent: :destroy
  
  # ActiveStorage
  has_one_attached :file, dependent: :purge_later
  
  # Validations
  validates :file_name, :mime_type, presence: true
  validates :alt_text, length: { maximum: 125 }  # For accessibility
  validates :mime_type, inclusion: { in: ALLOWED_MIME_TYPES }
  validate :file_size_within_limit
  
  # Scopes
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :by_folder, ->(folder_id) { where(folder_id: folder_id) }
  scope :by_tag, ->(tag) { joins(:tags).where(pwb_media_tags: { tag: tag }) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(mime_type) { where(mime_type: mime_type) }
  
  # Methods
  def image?
    mime_type.start_with?('image/')
  end
  
  def video?
    mime_type.start_with?('video/')
  end
  
  def display_url
    # Return CDN URL or variant based on config
  end
  
  def thumbnail_url(size: [200, 200])
    # Generate or return existing thumbnail
  end
  
  def usage_count
    attachments.count
  end
  
  def used_in
    attachments.group_by(&:attachable_type)
  end
end

# app/models/pwb/media_folder.rb
class Pwb::MediaFolder < ApplicationRecord
  include ActsAsTenant::TenantModel
  
  belongs_to :website, class_name: 'Pwb::Website'
  belongs_to :parent, class_name: 'Pwb::MediaFolder', optional: true
  
  has_many :children, class_name: 'Pwb::MediaFolder', foreign_key: :parent_id
  has_many :media, class_name: 'Pwb::Media', dependent: :nullify
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:website_id, :parent_id] }
end

# app/models/pwb/media_tag.rb
class Pwb::MediaTag < ApplicationRecord
  belongs_to :media, class_name: 'Pwb::Media'
  
  validates :tag, presence: true
  validates :tag, uniqueness: { scope: :media_id }
end

# app/models/pwb/media_attachment.rb
class Pwb::MediaAttachment < ApplicationRecord
  belongs_to :media, class_name: 'Pwb::Media'
  belongs_to :attachable, polymorphic: true
  
  validates :media_id, :attachable_type, :attachable_id, presence: true
  validates :media_id, uniqueness: { scope: [:attachable_type, :attachable_id] }
end
```

## Controllers

### SiteAdmin::MediaController
```ruby
# app/controllers/site_admin/media_controller.rb
class SiteAdmin::MediaController < SiteAdminController
  # CRUD for media management
  # GET /site_admin/media - Index with filtering
  # GET /site_admin/media/:id - Show details
  # POST /site_admin/media - Create/upload
  # PATCH /site_admin/media/:id - Update metadata
  # DELETE /site_admin/media/:id - Soft delete
  # GET /site_admin/media/:id/usage - Show where used
end

# app/controllers/site_admin/media_folders_controller.rb
class SiteAdmin::MediaFoldersController < SiteAdminController
  # Organize media
  # POST /site_admin/media_folders - Create folder
  # PATCH /site_admin/media_folders/:id - Rename
  # DELETE /site_admin/media_folders/:id - Delete
end
```

### API Controller for Editor/Integrations
```ruby
# app/controllers/site_admin/api/media_controller.rb
class SiteAdmin::Api::MediaController < SiteAdminController
  # JSON API for browser/integrations
  # Returns paged, filterable media list
  # Used by page part editor, property editor, etc.
end
```

## Services

### MediaService
```ruby
# app/services/pwb/media_service.rb
class Pwb::MediaService
  def initialize(website)
    @website = website
  end
  
  # Upload with validation and optimization
  def upload(file:, metadata: {})
    validate_file(file)
    media = create_media_record(file, metadata)
    optimize_and_store(media, file)
    media
  end
  
  # Batch organize
  def move_to_folder(media_ids, folder_id)
  def add_tags(media_ids, tags)
  def delete_media(media_ids, soft_delete: true)
  
  # Search and filter
  def search(query:, filters: {}, limit: 50)
  
  # Statistics
  def storage_usage
  def media_by_type
end
```

### MediaValidator
```ruby
# app/services/pwb/media_validator.rb
class Pwb::MediaValidator
  ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
  MAX_FILE_SIZE = 50.megabytes
  
  def validate(file)
    # File type validation
    # File size validation
    # Malware scanning (if integrated)
    # Dimension validation for images
  end
end
```

### MediaOptimizer
```ruby
# app/services/pwb/media_optimizer.rb
class Pwb::MediaOptimizer
  def optimize(media)
    # Image format conversion (WebP, etc.)
    # Dimension tracking
    # Thumbnail generation
    # Variant creation for common sizes
  end
end
```

## Views & Frontend

### Media Library Admin Interface
```
app/views/site_admin/media/
├── index.html.erb           # Main media library UI
├── _grid.html.erb           # Grid view component
├── _list.html.erb           # List view component
├── _upload_area.html.erb    # Drag-drop upload
├── _search_filters.html.erb # Search and filter UI
├── _media_modal.html.erb    # View/edit modal
└── _folder_tree.html.erb    # Folder navigation
```

### Media Picker for Forms
```
app/views/site_admin/media/
├── _picker.html.erb         # Reusable media picker
└── picker.js                # Stimulus controller
```

## Routes

```ruby
namespace :site_admin do
  # Media library management
  resources :media do
    member do
      get :usage
      post :restore  # Soft delete recovery
    end
    collection do
      get :deleted
      post :empty_trash
    end
  end
  
  # Media organization
  resources :media_folders
  
  # API for integrations (JSON)
  namespace :api do
    resources :media, only: [:index, :create, :update, :destroy] do
      member do
        get :usage
      end
    end
    resources :media_folders, only: [:create, :update, :destroy]
  end
end
```

## Migration Path

### Phase 1: Foundation
1. Create Media, MediaFolder, MediaTag, MediaAttachment models
2. Create database tables and migrations
3. Implement MediaService with upload/delete
4. Build API endpoints

### Phase 2: Admin UI
1. Build Media Library admin interface
2. Implement drag-drop upload
3. Add search and filtering
4. Create folder organization UI

### Phase 3: Integration
1. Update page part editor to use media picker
2. Update property editor to use media picker
3. Update website settings to use media picker
4. Migrate existing images to new system (optional)

### Phase 4: Enhancements
1. Image editing (crop, resize in admin)
2. Batch operations
3. Advanced search (by metadata)
4. Usage analytics

## Multi-Tenancy & Security

### Tenant Isolation
- All queries filtered by `website_id`
- Use `ActsAsTenant` for automatic scoping
- Strict foreign key constraints
- No cross-website media sharing

### Access Control
- User permissions check in controllers
- Website admin can only access their media
- Eventually: granular user roles (view-only, editor, admin)

### File Security
- Type validation (whitelist allowed MIME types)
- Size limits enforced
- Malicious file detection (future)
- Soft deletes for recovery

## Performance Considerations

### Pagination
- API endpoints paginate results (50 per page default)
- Lazy load images in UI

### Caching
- Cache media list for quick load
- Cache folder tree
- Invalidate on upload/delete

### Database Indexes
- Index on `website_id` for tenant isolation
- Index on `folder_id` for folder queries
- Index on tags for search
- Index on `deleted_at` for soft deletes
- Index on `created_at` for recent queries

### Storage
- Cloudflare R2 for scalable storage
- CDN for fast delivery
- Variants for different sizes
- WebP conversion for optimization

## API Specification

### List Media
```
GET /site_admin/api/media?page=1&limit=50&folder_id=&search=&tags=&type=
Response: { media: [...], total: 1000, page: 1, limit: 50 }
```

### Upload Media
```
POST /site_admin/api/media
Form data: file, title, alt_text, description, folder_id, tags[]
Response: { success: true, media: {...} }
```

### Update Media
```
PATCH /site_admin/api/media/:id
JSON: { title, alt_text, description, folder_id, tags }
Response: { success: true, media: {...} }
```

### Delete Media
```
DELETE /site_admin/api/media/:id?soft=true
Response: { success: true }
```

### Get Usage
```
GET /site_admin/api/media/:id/usage
Response: { usage: [{type: 'PropPhoto', id: 123}, ...] }
```

### Get Storage Stats
```
GET /site_admin/api/media/stats
Response: { 
  total_size: 2048000,
  total_count: 100,
  by_type: { images: 95, videos: 5 },
  by_folder: { ...}
}
```
