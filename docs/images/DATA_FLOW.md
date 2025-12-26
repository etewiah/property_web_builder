# Image Handling - Data Flow Diagrams

## 1. Image Upload Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    UPLOAD PROCESS                               │
└─────────────────────────────────────────────────────────────────┘

User selects file
    ↓
SiteAdmin::MediaLibraryController#create
    ├─ Validates content_type against allowed list
    ├─ Validates byte_size <= 25MB
    └─ Creates Pwb::Media record
        ↓
ActiveStorage creates Blob
    ├─ Computes checksum
    ├─ Stores file to configured service
    │   ├─ Development: Local disk (tmp/storage)
    │   ├─ Test: Temp disk (tmp/test/storage)
    │   └─ Production: Cloudflare R2
    └─ Attaches to Media#file
        ↓
Media#set_metadata_from_file (before_validation)
    ├─ Sets: filename, content_type, byte_size, checksum
    └─ Saves metadata to database
        ↓
Media#extract_dimensions (after_commit for images)
    ├─ Calls: file.blob.analyze
    ├─ Extracts: width, height from EXIF/metadata
    └─ Updates: width, height columns
        ↓
Success Response
    └─ Returns media_json with ID, URL, dimensions
```

## 2. Property Photo Assignment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              PROPERTY PHOTO ASSIGNMENT                           │
└─────────────────────────────────────────────────────────────────┘

Property Upload or Property Editor
    ↓
Pwb::PropPhoto.create or Pwb::PropPhoto#image.attach
    ├─ Creates association to Pwb::Prop
    └─ Accepts:
       ├─ image (ActiveStorage file)
       ├─ description (text)
       ├─ external_url (URL string)
       ├─ sort_order (integer)
       └─ folder (string)
           ↓
ActiveStorage::Attachment created
    ├─ Links blob_id to prop_photo record
    └─ Enables variant generation
           ↓
PropPhoto available for display
    └─ Via: prop.prop_photos (ordered by sort_order)
           ↓
View: opt_image_tag(photo) renders image
    └─ Generates variant if needed
        ├─ resize_to_limit applied
        ├─ Cached in active_storage_variant_records
        └─ Served from R2 CDN in production
```

## 3. Image Display Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 IMAGE RENDERING IN VIEWS                        │
└─────────────────────────────────────────────────────────────────┘

Template calls: <%= opt_image_tag(photo, options) %>
    ↓
Pwb::ImagesHelper#opt_image_tag
    ├─ Extract custom options: width, height, quality, crop, use_picture, eager, lazy
    ├─ Setup lazy loading defaults
    │   └─ loading: "lazy" (default)
    │   └─ decoding: "async"
    ├─ Setup eager loading (if eager: true)
    │   └─ loading: "eager"
    │   └─ fetchpriority: "high"
    ├─ Check if external URL
    │   └─ Return image_tag(external_url, options)
    └─ Else check if ActiveStorage attached
        └─ Build variant_options if width/height specified
            ├─ Build picture element (if use_picture: true && photo.image.variable?)
            │   ├─ Generate webp variant
            │   ├─ Generate fallback variant
            │   └─ Wrap in <picture> with sources
            └─ Or generate image_tag with variant
                ├─ Call image.variant(variant_options)
                ├─ First call: generate variant file
                │   └─ Mini_magick/libvips process image
                ├─ Cache variant record
                └─ Return image_tag
                    ↓
Rendered HTML (example)
    ├─ With lazy loading:
    │   <img loading="lazy" decoding="async" src="...blob..." alt="...">
    │
    ├─ With eager loading:
    │   <img loading="eager" fetchpriority="high" src="...blob..." alt="...">
    │
    └─ With picture element:
        <picture>
          <source srcset="...variant-webp..." type="image/webp">
          <img loading="lazy" src="...variant-jpg..." alt="...">
        </picture>
```

## 4. Variant Caching Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              IMAGE VARIANT CACHING PIPELINE                     │
└─────────────────────────────────────────────────────────────────┘

First request: <%= image.variant(resize_to_limit: [600, 600]) %>
    ↓
Rails checks: active_storage_variant_records table
    ├─ Searches by: blob_id, variation_digest
    └─ Not found (first time)
        ↓
Rails calls image processor (mini_magick or libvips)
    ├─ Read original image from storage
    ├─ Apply transformation: resize_to_limit [600, 600]
    ├─ Generate output file (e.g., image-variant.jpg)
    └─ Saves processed file to storage (with digest in filename)
        ↓
Rails creates variant record
    ├─ Stores: blob_id, variation_digest, processed_blob_id
    └─ Caches the association
        ↓
Rails generates URL
    ├─ Rails.application.routes.rails_representation_path(variant)
    └─ Returns: /rails/active_storage/representations/[digest]/image.jpg
        ↓
Production: Cloudflare R2 serves file
    ├─ URL redirects to: https://[public-url]/[digest].jpg
    └─ CDN caches at edge


Subsequent requests: Same URL requested again
    ↓
Rails checks: active_storage_variant_records
    ├─ Searches by: blob_id, variation_digest
    └─ FOUND (cached)
        ↓
Rails returns cached URL
    └─ Skips image processing
        ↓
Browser gets cached variant
    ├─ If CDN-cached: Served instantly from edge
    └─ If browser-cached: Served from local cache
```

## 5. External Image URL Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  EXTERNAL IMAGE SUPPORT                         │
└─────────────────────────────────────────────────────────────────┘

Website has: external_image_mode = true
    ↓
Admin provides: external_url instead of uploading
    └─ Example: https://cdn.example.com/image.jpg
        ↓
PropPhoto/ContentPhoto/WebsitePhoto stored
    ├─ image: nil (no ActiveStorage file)
    └─ external_url: "https://cdn.example.com/image.jpg"
        ↓
ExternalImageSupport#external? returns true
    └─ Validates URL format: must be HTTP(S)
        ↓
View calls: <%= opt_image_tag(photo) %>
    ├─ Checks: photo.external? → true
    ├─ Bypasses variant generation
    └─ Returns: <%= image_tag(external_url, options) %>
        ↓
Rendered HTML
    └─ <img src="https://cdn.example.com/image.jpg" alt="...">


Helper Methods with External URL Support:
    ├─ image_url(variant_options: nil)
    │   └─ Returns external_url if present
    ├─ thumbnail_url(size: [200, 200])
    │   └─ Returns external_url (no resize possible)
    ├─ has_image?
    │   └─ Returns true if external_url OR image.attached?
    └─ photo_url(photo)
        └─ Returns external_url or ActiveStorage URL
```

## 6. Media Gallery Builder Flow

```
┌─────────────────────────────────────────────────────────────────┐
│            IMAGE GALLERY BUILDER SERVICE FLOW                   │
└─────────────────────────────────────────────────────────────────┘

Controller or View calls:
    builder = Pwb::ImageGalleryBuilder.new(website, url_helper: self)
    images = builder.build
        ↓
ImageGalleryBuilder#build
    ├─ Call: content_photos (max 50)
    │   └─ Query: ContentPhoto.joins(:content)
    │           .where(pwb_contents: { website_id: website.id })
    ├─ Call: website_photos (max 20)
    │   └─ Query: website.website_photos
    ├─ Call: property_photos (max 30)
    │   └─ Query: PropPhoto.joins(:realty_asset)
    │           .where(pwb_realty_assets: { website_id: website.id })
    └─ Concatenate all results
        ↓
For each photo:
    ├─ Check: photo.image.attached?
    ├─ Build hash:
    │   ├─ id: "#{type}_#{photo.id}"
    │   ├─ type: "content|website|property"
    │   ├─ url: url_helper.url_for(photo.image)
    │   ├─ thumb_url: thumbnail_url(photo.image)
    │   │   └─ Variant: resize_to_limit: [150, 150]
    │   ├─ filename: photo.image.filename.to_s
    │   └─ description: photo.description
    └─ Add to results array
        ↓
Return Array<Hash>
    └─ [
        { id: "content_123", type: "content", url: "...", thumb_url: "...", ... },
        { id: "website_456", type: "website", url: "...", thumb_url: "...", ... },
        { id: "prop_789", type: "property", url: "...", thumb_url: "...", ... }
      ]
```

## 7. Photo Retrieval for Listings

```
┌─────────────────────────────────────────────────────────────────┐
│              PROPERTY PHOTO RETRIEVAL PATTERN                   │
└─────────────────────────────────────────────────────────────────┘

Property Model includes: ListedProperty::PhotoAccessors
    ↓
View needs: First photo for thumbnail
    ├─ Call: property.ordered_photo(1)
    │   └─ Returns: prop_photos[0] (first item)
    └─ Call: property.prop_photos
        └─ Returns: ordered array (sorted by sort_order)
            ↓
View renders:
    <%= opt_image_tag(property.ordered_photo(1),
        height: 280,
        crop: "fill",
        class: "w-full h-full object-cover",
        loading: "lazy") %>
        ↓
Helper processes:
    ├─ Check: photo.external? → false (ActiveStorage)
    ├─ Check: photo.image.attached? → true
    ├─ Check: photo.image.variable? → true
    ├─ Generate variant: resize_to_limit: [280, nil]
    │   └─ First time: ImageMagick processes image
    │   └─ Cached: Returns cached variant record
    └─ Return: image_tag(variant_url, options)
        ↓
HTML Output:
    <img loading="lazy"
         decoding="async"
         src="/rails/active_storage/representations/[digest]/image.jpg"
         class="w-full h-full object-cover"
         alt="Property listing">


Carousel: Loop through all photos
    ↓
For index 0 (first):
    <%= opt_image_tag(photo, eager: true) %>
    └─ Renders with loading: "eager" + fetchpriority: "high"

For index 1+ (rest):
    <%= opt_image_tag(photo, loading: "lazy") %>
    └─ Renders with default lazy loading
```

## 8. Media Library UI Flow

```
┌─────────────────────────────────────────────────────────────────┐
│            MEDIA LIBRARY ADMIN INTERFACE FLOW                   │
└─────────────────────────────────────────────────────────────────┘

Admin visits: /site_admin/media_library
    ↓
SiteAdmin::MediaLibraryController#index
    ├─ Query: current_website.media
    ├─ Filter: by_folder, search(params[:q])
    ├─ Order: recent (desc by created_at)
    ├─ Paginate: 24 items per page
    └─ Get stats: total_files, total_images, total_documents, storage_used
        ↓
View renders: Grid of media items
    └─ For each media:
        ├─ Check: media.image? → true
        ├─ Generate thumbnail: media.variant_url(:thumb)
        │   └─ Returns: resize_to_fill: [150, 150]
        ├─ Display image_tag with thumbnail
        ├─ Show metadata: filename, size, dimensions
        ├─ Show actions: Edit, Delete
        └─ On hover: Show action buttons
            ↓
Admin clicks: Upload
    ├─ Select files via file input
    ├─ POST to: /site_admin/media_library (create action)
    ├─ Controller processes each file:
    │   ├─ Create Pwb::Media record
    │   ├─ Attach file to Media#file
    │   ├─ Extract metadata automatically
    │   ├─ Add to results
    │   └─ Handle errors gracefully
    └─ Render: JSON response or redirect
            ↓
User updates: Metadata (title, alt_text, tags)
    ├─ PATCH to: /site_admin/media_library/:id (update action)
    ├─ Controller updates record
    └─ JSON response with updated media


Admin edits: Click thumbnail
    ├─ GET: /site_admin/media_library/:id/edit
    ├─ Show form with all metadata fields
    ├─ User updates fields
    └─ Submit update
            ↓
Media available throughout site
    ├─ Used in: Property photos, Content photos, Website photos
    ├─ Reused in: Multiple places (usage_count tracked)
    └─ Searchable by: Filename, title, alt_text, description, tags
```

## 9. Database Schema Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│            ACTIVE STORAGE & PHOTO RELATIONSHIPS                 │
└─────────────────────────────────────────────────────────────────┘

Blobs (ActiveStorage::Blob)
    ├─ id (PK)
    ├─ key (unique storage key)
    ├─ filename
    ├─ content_type
    ├─ byte_size
    ├─ checksum
    └─ created_at
        ↑
        │ has_many through Attachments
        │
Attachments (ActiveStorage::Attachment)
    ├─ id (PK)
    ├─ name (e.g., "image", "file")
    ├─ record_type (e.g., "Pwb::PropPhoto")
    ├─ record_id (e.g., 123)
    ├─ blob_id (FK)
    ├─ created_at
    └─ Supports: has_one_attached, has_many_attached
        ↑
        │
PropPhoto
    ├─ id (PK)
    ├─ prop_id (FK)
    ├─ realty_asset_id (FK)
    ├─ image (attachment name)
    ├─ description
    ├─ external_url
    ├─ file_size
    ├─ sort_order
    └─ created_at

ContentPhoto
    ├─ id (PK)
    ├─ content_id (FK)
    ├─ image (attachment name)
    ├─ description
    ├─ external_url
    ├─ file_size
    ├─ block_key
    ├─ sort_order
    └─ created_at

WebsitePhoto
    ├─ id (PK)
    ├─ website_id (FK)
    ├─ image (attachment name)
    ├─ description
    ├─ external_url
    ├─ photo_key
    ├─ folder
    └─ created_at

Media
    ├─ id (PK)
    ├─ website_id (FK)
    ├─ folder_id (FK → MediaFolder)
    ├─ file (attachment name)
    ├─ filename
    ├─ content_type
    ├─ byte_size
    ├─ checksum
    ├─ width (images only)
    ├─ height (images only)
    ├─ title
    ├─ alt_text
    ├─ caption
    ├─ description
    ├─ tags (array)
    ├─ usage_count
    ├─ last_used_at
    └─ created_at

VariantRecords (ActiveStorage::VariantRecord)
    ├─ id (PK)
    ├─ blob_id (FK → Blob)
    ├─ variation_digest (unique hash of variant options)
    └─ Stores cache of generated variants
```

## 10. Cloudflare R2 Storage Flow

```
┌─────────────────────────────────────────────────────────────────┐
│            CLOUDFLARE R2 INTEGRATION FLOW                       │
└─────────────────────────────────────────────────────────────────┘

File Upload
    ↓
ActiveStorage::Service::R2Service#upload
    ├─ Use AWS S3 SDK (aws-sdk-s3 gem)
    ├─ Auth: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
    ├─ Endpoint: https://[R2_ACCOUNT_ID].r2.cloudflarestorage.com
    ├─ Bucket: R2_BUCKET
    ├─ Key pattern: [key]/[filename]
    └─ force_path_style: true (R2 requirement)
        ↓
File stored in R2 bucket
    ├─ Region: auto (global distribution)
    └─ Public: true (world-readable)
        ↓
URL Generation
    ├─ Internal URL (for Rails): 
    │   /rails/blob/eyJfcmFpbHMiOnsib2JqZWN0IjoiQWN0aXZlU3RvcmFnZTo6QmxvYiI...
    │
    └─ Public URL (to R2):
        ├─ Standard: https://[account-id].r2.cloudflarestorage.com/[key]/[file]
        ├─ Custom domain: https://[R2_PUBLIC_URL]/[key]/[file]
        │   (Configured via custom R2Service)
        │
        └─ Example: https://images.example.com/prop_photos/abc123.jpg
            ↓
Production Request Flow
    ├─ Browser requests: https://images.example.com/abc123.jpg
    ├─ Cloudflare edge caches the file
    ├─ Subsequent requests served from cache (low latency)
    ├─ Cache headers configured per object
    └─ S3-compatible API means full control over cache-control headers
```

## 11. Lazy Loading & Performance Flow

```
┌─────────────────────────────────────────────────────────────────┐
│           LAZY LOADING PERFORMANCE OPTIMIZATION                 │
└─────────────────────────────────────────────────────────────────┘

Page loads
    ├─ Hero image (above the fold)
    │   ├─ opt_image_tag(photo, eager: true)
    │   └─ HTML: <img loading="eager" fetchpriority="high" ... >
    │       ├─ Requested immediately
    │       ├─ Given high fetch priority
    │       └─ Critical for LCP (Largest Contentful Paint)
    │
    └─ Grid/list images (below the fold)
        ├─ opt_image_tag(photo, loading: "lazy")
        └─ HTML: <img loading="lazy" decoding="async" ... >
            ├─ Deferred until near viewport
            ├─ Async decode prevents main thread blocking
            └─ Improves FCP (First Contentful Paint)
                ↓
Browser Lazy Loading Engine
    ├─ Observes: intersection with viewport
    ├─ When entering viewport:
    │   └─ Fetches src URL
    ├─ When exiting viewport:
    │   └─ May unload (browser dependent)
    └─ Result: Reduced initial payload & bandwidth
                ↓
CDN Caching Benefits
    ├─ Images served from Cloudflare edge
    ├─ Global distribution = fast delivery
    ├─ Compression: WebP variant smaller than JPEG
    └─ Browser caching: Multiple variants reused
                ↓
Performance Gains
    ├─ LCP: Hero image loads eagerly
    ├─ FCP: Page interactive before all images load
    ├─ FID: No blocking from image decoding (async)
    ├─ CLS: Images have dimensions (prevents jank)
    └─ Bundle size: Only needed images downloaded
```

## Summary

The image handling architecture supports:

1. **Upload** → Validation → Metadata Extraction → Storage
2. **Caching** → Variant Generation → Record Tracking → Reuse
3. **Display** → Helper Processing → Variant Selection → Rendering
4. **Optimization** → Lazy Loading → CDN Delivery → Edge Caching
5. **Flexibility** → External URLs OR Uploaded Files → Same Interface
6. **Multi-tenancy** → Per-website storage → Proper scoping → Isolation
