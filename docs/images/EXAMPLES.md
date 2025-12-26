# Image Handling - Code Examples & Common Patterns

## Table of Contents
1. [View Examples](#view-examples)
2. [Model Examples](#model-examples)
3. [Helper Usage](#helper-usage)
4. [Controller Examples](#controller-examples)
5. [Service Examples](#service-examples)
6. [Testing Examples](#testing-examples)
7. [Common Gotchas](#common-gotchas)

---

## View Examples

### Hero Image (Property Detail Page)

```erb
<!-- app/themes/default/views/pwb/props/show.html.erb -->

<div class="hero-image-section">
  <% if @property.prop_photos.any? %>
    <div class="hero-container" style="height: 500px;">
      <%= opt_image_tag(@property.ordered_photo(1),
          quality: "auto",
          height: 500,
          crop: "scale",
          class: "w-full h-full object-cover",
          alt: @property.title,
          eager: true,
          fetchpriority: "high",
          decoding: "async") %>
    </div>
  <% else %>
    <div class="hero-placeholder bg-gray-200 h-96 flex items-center justify-center">
      <p class="text-gray-400">No photos available</p>
    </div>
  <% end %>
</div>
```

**Key Points:**
- First image above-the-fold → use `eager: true`
- High fetch priority for LCP optimization
- Explicit height prevents layout shift
- Fallback for properties without photos

---

### Image Carousel

```erb
<!-- app/themes/default/views/pwb/props/_images_section_carousel.html.erb -->

<div class="carousel-container">
  <div class="carousel-inner">
    <% @property.prop_photos.each_with_index do |photo, index| %>
      <div class="carousel-item <%= 'active' if index == 0 %>">
        <%= opt_image_tag(photo,
            quality: "auto",
            height: 400,
            crop: "scale",
            class: "carousel-image w-full h-full object-cover",
            alt: "#{@property.title} - Photo #{index + 1}",
            loading: index == 0 ? "eager" : "lazy",
            fetchpriority: index == 0 ? "high" : nil,
            decoding: "async") %>
      </div>
    <% end %>
  </div>

  <!-- Indicators -->
  <div class="carousel-indicators">
    <% @property.prop_photos.each_with_index do |_, index| %>
      <button type="button"
              class="indicator <%= 'active' if index == 0 %>"
              data-slide-to="<%= index %>"
              aria-label="Photo <%= index + 1 %>"></button>
    <% end %>
  </div>

  <!-- Controls -->
  <button type="button" class="carousel-control-prev" data-carousel-prev>Previous</button>
  <button type="button" class="carousel-control-next" data-carousel-next>Next</button>
</div>

<script>
  // Carousel initialization handled by Flowbite/Stimulus controller
</script>
```

**Key Points:**
- First slide: eager loading + high priority
- Subsequent slides: lazy loading
- Progressive enhancement (works with JS or without)
- Accessible button labels

---

### Property Grid/Search Results

```erb
<!-- app/themes/default/views/pwb/search/_search_result_item.html.erb -->

<div class="property-card">
  <!-- Image Section -->
  <div class="image-container aspect-video overflow-hidden">
    <%= link_to @property.show_path, class: "block w-full h-full group" do %>
      <%= opt_image_tag((@property.ordered_photo(1)),
          quality: "auto",
          height: 240,
          crop: "fill",
          class: "w-full h-full object-cover group-hover:scale-105 transition-transform duration-300",
          alt: @property.title.presence || "Property listing",
          loading: "lazy",
          decoding: "async") %>
    <% end %>
  </div>

  <!-- Featured Badge -->
  <% if @property.highlighted %>
    <div class="featured-badge absolute top-2 right-2">
      <span class="bg-blue-600 text-white text-xs px-2 py-1 rounded">
        Featured
      </span>
    </div>
  <% end %>

  <!-- Property Info -->
  <div class="card-content p-4">
    <h3><%= @property.title %></h3>
    <p class="text-gray-500"><%= @property.reference %></p>

    <!-- Features -->
    <div class="features flex gap-4">
      <span><i class="fa fa-bed"></i> <%= @property.bedrooms %></span>
      <span><i class="fa fa-shower"></i> <%= @property.bathrooms %></span>
      <span><i class="fa fa-arrows-alt"></i> <%= @property.area %></span>
    </div>

    <!-- Price & CTA -->
    <div class="footer flex justify-between items-center">
      <span class="price text-lg font-bold text-blue-600">
        <%= @property.price_with_currency %>
      </span>
      <%= link_to "View Property", @property.show_path, class: "btn btn-blue" %>
    </div>
  </div>
</div>
```

**Key Points:**
- Below-the-fold → lazy loading (default)
- Aspect video ratio maintains layout
- Hover effect on image (scale transform)
- Link wraps entire image for accessibility

---

### Media Library Admin Interface

```erb
<!-- app/views/site_admin/media_library/index.html.erb -->

<div class="media-library">
  <!-- Search & Filter -->
  <div class="search-bar">
    <%= form_tag site_admin_media_library_index_path, method: :get do %>
      <%= text_field_tag :q, params[:q], placeholder: "Search files..." %>
      <%= submit_tag "Search" %>
    <% end %>
  </div>

  <!-- Folder Navigation -->
  <div class="folder-tree">
    <%= link_to "All Files", site_admin_media_library_index_path,
        class: "folder-link #{'active' if @current_folder.nil?}" %>

    <% @folders.each do |folder| %>
      <%= link_to folder.name,
          site_admin_media_library_index_path(folder: folder.id),
          class: "folder-link #{'active' if @current_folder&.id == folder.id}" %>
    <% end %>
  </div>

  <!-- Media Grid -->
  <div class="media-grid grid grid-cols-4 gap-4">
    <% @media.each do |media| %>
      <div class="media-item group">
        <!-- Thumbnail -->
        <div class="thumbnail-container aspect-square bg-gray-100 relative">
          <% if media.image? %>
            <%= image_tag media.variant_url(:thumb),
                alt: media.alt_text || media.filename,
                class: "w-full h-full object-cover" %>
          <% else %>
            <div class="placeholder flex items-center justify-center">
              <i class="far fa-file text-4xl text-gray-300"></i>
            </div>
          <% end %>

          <!-- Hover Actions -->
          <div class="hover-actions absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
            <%= link_to edit_site_admin_media_library_path(media), class: "action-btn edit" do %>
              <i class="fas fa-edit"></i>
            <% end %>

            <%= link_to site_admin_media_library_path(media),
                method: :delete,
                data: { confirm: "Delete this file?" },
                class: "action-btn delete" do %>
              <i class="fas fa-trash"></i>
            <% end %>
          </div>
        </div>

        <!-- Metadata -->
        <div class="media-info p-2">
          <p class="filename truncate text-sm font-medium">
            <%= media.display_name %>
          </p>
          <p class="metadata text-xs text-gray-500">
            <%= media.human_file_size %>
            <% if media.dimensions %> · <%= media.dimensions %><% end %>
          </p>
        </div>
      </div>
    <% end %>
  </div>

  <!-- Pagination -->
  <div class="pagination">
    <%== pagy_nav(@pagy) %>
  </div>
</div>
```

**Key Points:**
- Thumbnail variant for grid display (150x150)
- Hover actions only visible on mouse over
- Fallback icon for non-image files
- Pagination for large media libraries

---

### Background Image with Gradient

```erb
<!-- Using helper with gradient overlay -->

<section class="hero-section" style="<%= bg_image(photo, gradient: 'rgba(0,0,0,0.5)') %> background-size: cover; background-position: center;">
  <div class="hero-content">
    <h1><%= @page.title %></h1>
    <p><%= @page.subtitle %></p>
  </div>
</section>

<!-- Alternative: CSS class approach -->
<section class="hero-section" style="background-image: url(<%= photo_url(photo) %>);">
  <!-- Content -->
</section>
```

**Key Points:**
- Gradient overlay improves text readability
- Background-size and position set via CSS
- Falls back to solid color if image not available

---

## Model Examples

### Creating Photos with Images

```ruby
# Create with image upload
photo = Pwb::PropPhoto.new(
  prop: property,
  description: "Living room"
)
photo.image.attach(
  io: File.open("path/to/image.jpg"),
  filename: "living_room.jpg",
  content_type: "image/jpeg"
)
photo.save

# Or in controller with params
prop_photo = current_website.properties.find(params[:prop_id]).prop_photos.create(
  image: params[:file],
  description: params[:description],
  sort_order: prop.prop_photos.count + 1
)

# Using factory in tests
photo = create(:pwb_prop_photo, :with_image, prop: property)
```

---

### Working with External Images

```ruby
# Enable external image mode for website
website.update(external_image_mode: true)

# Create photo with external URL
photo = Pwb::PropPhoto.new(
  prop: property,
  external_url: "https://cdn.example.com/photo.jpg",
  description: "Imported from external CDN"
)
photo.save

# Check if external
if photo.external?
  puts "Using external URL: #{photo.external_url}"
else
  puts "Using uploaded file: #{photo.image.filename}"
end

# Get image URL (handles both)
url = photo.image_url
# => "https://cdn.example.com/photo.jpg" or "/rails/blob/..."

# Get thumbnail
thumb = photo.thumbnail_url(size: [200, 200])
# => "https://cdn.example.com/photo.jpg" (no resize for external)
```

---

### Querying Photos

```ruby
# Get first photo
first = property.ordered_photo(1)
# => Pwb::PropPhoto or nil

# Get photo by position
second = property.ordered_photo(2)

# Get all photos
all = property.prop_photos  # ActiveRecord::Relation
# => [photo1, photo2, photo3]

# Filter by description
photos_with_desc = property.prop_photos.where.not(description: nil)

# Order manually
sorted = property.prop_photos.order(sort_order: :asc, created_at: :desc)

# Count
count = property.prop_photos.count  # => 5

# Check if has photos
has_photos = property.prop_photos.any?  # => true
```

---

### Media Model with Metadata

```ruby
# Create with file
media = Pwb::Media.create(
  website: website,
  file: params[:file],
  title: "Living Room",
  alt_text: "Modern living room with fireplace",
  caption: "Featured in spring collection",
  tags: ["interior", "modern", "living-room"],
  folder: media_folder
)

# Metadata auto-extracted
media.width      # => 1920
media.height     # => 1080
media.dimensions # => "1920 x 1080"
media.byte_size  # => 2500000
media.content_type # => "image/jpeg"

# Track usage
media.record_usage!  # Increments usage_count, updates last_used_at

# Search
Pwb::Media.search("living room")          # By filename, title, alt_text, description
Pwb::Media.images                         # Only image files
Pwb::Media.documents                      # PDFs, Word, Excel, etc.
Pwb::Media.with_tag("interior")           # By tag
Pwb::Media.recent                         # Ordered by created_at DESC
```

---

### Working with Variants

```ruby
# Photo model optimized_image_url method
photo.optimized_image_url
# => "/rails/active_storage/representations/.../image.jpg"
# OR
# => "https://cdn.example.com/image.jpg" (if external)

# Media model variant methods
media.variant_url(:thumb)   # resize_to_fill: [150, 150]
media.variant_url(:small)   # resize_to_limit: [300, 300]
media.variant_url(:medium)  # resize_to_limit: [600, 600]
media.variant_url(:large)   # resize_to_limit: [1200, 1200]

# Direct variant in controller/view
photo.image.variant(resize_to_limit: [400, 300])

# With format conversion
photo.image.variant(resize_to_limit: [400, 300], format: :webp)
```

---

## Helper Usage

### opt_image_tag - Common Patterns

```erb
<!-- Minimal -->
<%= opt_image_tag(photo) %>

<!-- With sizing -->
<%= opt_image_tag(photo, height: 300) %>

<!-- Above-the-fold hero -->
<%= opt_image_tag(photo,
    eager: true,
    height: 500,
    alt: "Hero image",
    class: "w-full h-full object-cover") %>

<!-- Below-the-fold lazy load (default) -->
<%= opt_image_tag(photo,
    height: 250,
    loading: "lazy",
    alt: "Thumbnail") %>

<!-- WebP with fallback -->
<%= opt_image_tag(photo,
    use_picture: true,
    height: 400) %>

<!-- All options -->
<%= opt_image_tag(photo,
    width: 300,
    height: 200,
    quality: "auto",         # Reserved for CDN
    crop: "fill",            # Reserved for CDN
    class: "my-image",
    alt: "Photo",
    id: "photo-1",
    data: { lightbox: "gallery" },
    eager: false,            # Can explicitly disable
    lazy: true,              # Or enable (eager overrides)
    fetchpriority: "high",   # "high", "low", "auto"
    decoding: "async",       # "async", "sync"
    loading: "lazy") %>      # Can explicitly set
```

---

### photo_image_tag - Explicit Variants

```erb
<!-- With explicit variant hash -->
<%= photo_image_tag(photo,
    variant_options: { resize_to_limit: [300, 300] },
    class: "thumbnail",
    alt: "Property thumbnail",
    lazy: true) %>

<!-- Multiple photos with different variants -->
<% photos.each do |photo| %>
  <%= photo_image_tag(photo,
      variant_options: { resize_to_fill: [150, 150] },
      class: "grid-thumbnail",
      alt: photo.description) %>
<% end %>
```

---

### photo_url - Direct URL Generation

```erb
<!-- Get URL for API response -->
<% photo_urls = property.prop_photos.map { |p| photo_url(p) } %>

<!-- In controller -->
def api_property_photos
  urls = @property.prop_photos.map { |p| photo_url(p) }
  render json: { urls: urls }
end

<!-- Check if photo exists before rendering -->
<% if photo_has_image?(photo) %>
  <%= opt_image_tag(photo) %>
<% end %>
```

---

### bg_image - Background Images

```erb
<!-- Simple background -->
<div style="<%= bg_image(photo) %>">
  Content over image
</div>

<!-- With gradient overlay -->
<div style="<%= bg_image(photo, gradient: 'rgba(0,0,0,0.5)') %> background-size: cover;">
  Content with dark overlay
</div>

<!-- Multiple gradients -->
<div style="<%= bg_image(photo, gradient: 'to right, rgba(0,0,0,0.7), rgba(0,0,0,0)') %>">
  Gradient fade from left
</div>
```

---

## Controller Examples

### Media Library Controller

```ruby
# app/controllers/site_admin/media_library_controller.rb

class SiteAdmin::MediaLibraryController < SiteAdminController
  before_action :set_website_and_folder, only: [:index]
  before_action :set_media, only: [:show, :edit, :update, :destroy]

  def index
    # Build query
    media_scope = current_website.media
                                 .by_folder(@folder)
                                 .search(params[:q])
                                 .recent

    # Paginate
    @pagy, @media = pagy(media_scope, limit: 24)

    # Get stats
    @folders = current_website.media_folders.root.ordered
    @current_folder = @folder
    @stats = calculate_stats

    # Respond to both HTML and JSON
    respond_to do |format|
      format.html
      format.json { render json: media_json(@media, @pagy) }
    end
  end

  def create
    uploaded_files = Array(params[:files] || params[:file])

    if uploaded_files.empty?
      flash[:alert] = "Please select files to upload."
      return redirect_to site_admin_media_library_index_path
    end

    results = upload_files(uploaded_files)

    if results[:errors].empty?
      flash[:notice] = "#{results[:uploaded].size} file(s) uploaded successfully."
    else
      flash[:alert] = "#{results[:uploaded].size} uploaded, #{results[:errors].size} failed."
    end

    respond_to do |format|
      format.html { redirect_to site_admin_media_library_index_path }
      format.json { render json: results }
    end
  end

  def update
    if @media.update(media_params)
      @media.record_usage!  # Track usage

      respond_to do |format|
        format.html { redirect_to site_admin_media_library_index_path, notice: "Media updated." }
        format.json { render json: media_item_json(@media) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @media.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @media.destroy
    respond_to do |format|
      format.html { redirect_to site_admin_media_library_index_path, notice: "Media deleted." }
      format.json { head :no_content }
    end
  end

  private

  def upload_files(files)
    uploaded = []
    errors = []

    files.each do |file|
      media = current_website.media.build(file: file)
      if media.save
        uploaded << media
      else
        errors << { filename: file.original_filename, error: media.errors.full_messages.join(", ") }
      end
    end

    { uploaded: uploaded, errors: errors }
  end

  def media_params
    params.require(:media).permit(:title, :alt_text, :caption, :description, tags: [], file: [])
  end
end
```

---

### Property Photos Controller

```ruby
class SiteAdmin::PropertiesPhotosController < SiteAdminController
  def upload
    property = current_website.properties.find(params[:property_id])
    files = Array(params[:files])

    uploaded = []
    errors = []

    files.each do |file|
      photo = property.prop_photos.new(image: file)
      if photo.save
        uploaded << photo
      else
        errors << file.original_filename
      end
    end

    render json: {
      success: errors.empty?,
      uploaded: uploaded.map { |p| { id: p.id, url: rails_blob_url(p.image) } },
      errors: errors
    }
  end

  def update_order
    property = current_website.properties.find(params[:property_id])
    params[:order].each_with_index do |photo_id, index|
      property.prop_photos.find(photo_id).update(sort_order: index)
    end

    render json: { success: true }
  end

  def destroy
    photo = Pwb::PropPhoto.find(params[:id])
    photo.image.purge if photo.image.attached?
    photo.destroy

    render json: { success: true }
  end
end
```

---

## Service Examples

### Image Gallery Builder

```ruby
# app/services/pwb/image_gallery_builder.rb

class Pwb::ImageGalleryBuilder
  def initialize(website, url_helper:, limits: {})
    @website = website
    @url_helper = url_helper
    @limits = DEFAULT_LIMITS.merge(limits)
  end

  # Get all images from all sources
  def build
    images = []
    images.concat(content_photos)
    images.concat(website_photos)
    images.concat(property_photos)
    images
  end

  # Get only property images
  def property_photos
    # ...
  end

  # Usage in controller:
  # builder = Pwb::ImageGalleryBuilder.new(current_website, url_helper: self)
  # @gallery_images = builder.build
  # @property_images = builder.property_photos
end

# In view:
<% builder = Pwb::ImageGalleryBuilder.new(current_website, url_helper: self) %>
<% @images = builder.build %>

<% @images.each do |image_hash| %>
  <div class="gallery-item">
    <img src="<%= image_hash[:url] %>"
         alt="<%= image_hash[:description] %>"
         class="w-full h-full object-cover">
    <p><%= image_hash[:filename] %></p>
  </div>
<% end %>
```

---

## Testing Examples

### Model Specs

```ruby
# spec/models/pwb/prop_photo_spec.rb

require 'rails_helper'

RSpec.describe Pwb::PropPhoto do
  describe 'attachments' do
    it 'has one image attachment' do
      photo = create(:pwb_prop_photo, :with_image)
      expect(photo.image).to be_attached
    end
  end

  describe 'external images' do
    it 'validates external URL format' do
      photo = Pwb::PropPhoto.new(external_url: "invalid")
      expect(photo).not_to be_valid

      photo.external_url = "https://example.com/image.jpg"
      expect(photo).to be_valid
    end

    it 'returns external_url when external?' do
      external_url = "https://cdn.example.com/image.jpg"
      photo = create(:pwb_prop_photo, external_url: external_url)

      expect(photo.external?).to be true
      expect(photo.image_url).to eq(external_url)
    end
  end

  describe 'variants' do
    it 'generates variants for attached images' do
      photo = create(:pwb_prop_photo, :with_image)

      variant = photo.image.variant(resize_to_limit: [300, 300])
      expect(variant).to be_a(ActiveStorage::Variant)
    end
  end
end
```

### Factory Setup

```ruby
# spec/factories/pwb_prop_photos.rb

FactoryBot.define do
  factory :pwb_prop_photo, class: 'Pwb::PropPhoto' do
    prop { create(:pwb_prop) }
    description { "Living room photo" }
    sort_order { 0 }

    trait :with_image do
      image do
        Rack::Test::UploadedFile.new(
          File.join(Rails.root, 'spec/fixtures/images/sample.jpg'),
          'image/jpeg'
        )
      end
    end

    trait :with_external_url do
      external_url { "https://cdn.example.com/image.jpg" }
    end
  end
end
```

### Feature Spec

```ruby
# spec/features/property_images_spec.rb

require 'rails_helper'

feature 'Property Images' do
  scenario 'User views property carousel with images' do
    property = create(:pwb_prop, :with_photos)

    visit property_path(property)

    # Check that first image is visible
    expect(page).to have_css('img[loading="eager"]')

    # Check that other images lazy load
    expect(page).to have_css('img[loading="lazy"]', count: property.prop_photos.count - 1)

    # Check carousel controls exist
    expect(page).to have_button('Previous')
    expect(page).to have_button('Next')
  end

  scenario 'Admin uploads property photos' do
    property = create(:pwb_prop)
    visit edit_site_admin_property_path(property)

    # Upload images
    attach_file 'files[]', Rails.root.join('spec/fixtures/images/sample.jpg')

    click_button 'Upload'

    expect(page).to have_content('file(s) uploaded successfully')
    expect(property.reload.prop_photos.count).to eq(1)
  end
end
```

---

## Common Gotchas

### 1. Forgot to Attach Image

```ruby
# WRONG - Photo created but no image attached
photo = Pwb::PropPhoto.create(prop: property, description: "Test")
# => photo.image.attached? → false

# RIGHT - Attach image before or after save
photo = Pwb::PropPhoto.new(prop: property)
photo.image.attach(io: File.open(...), filename: "photo.jpg")
photo.save

# OR use factory
photo = create(:pwb_prop_photo, :with_image)
```

---

### 2. Using External URL with Variants

```erb
<!-- WRONG - External images don't support variants -->
<% external_photo = create(:pwb_prop_photo, external_url: "https://cdn.example.com/image.jpg") %>
<%= image_tag external_photo.image.variant(resize_to_limit: [300, 300]) %>
<!-- Error: variant not supported for external URL -->

<!-- RIGHT - opt_image_tag handles this -->
<%= opt_image_tag(external_photo, height: 300) %>
<!-- Returns original external URL (no resize) -->

<!-- OR check before using variants -->
<% if external_photo.image.attached? && external_photo.image.variable? %>
  <%= image_tag external_photo.image.variant(resize_to_limit: [300, 300]) %>
<% else %>
  <%= image_tag external_photo.external_url %>
<% end %>
```

---

### 3. Not Setting Alt Text

```erb
<!-- WRONG - No alt text, bad for accessibility and SEO -->
<%= image_tag photo.image %>

<!-- RIGHT - Always provide descriptive alt text -->
<%= opt_image_tag(photo,
    alt: @property.title.presence || "Property listing") %>

<!-- RIGHT - Use metadata when available -->
<%= image_tag media.file,
    alt: media.alt_text || media.filename %>
```

---

### 4. Lazy Loading Above-the-Fold Images

```erb
<!-- WRONG - Hero image uses lazy loading by default -->
<div class="hero" style="height: 500px;">
  <%= opt_image_tag(photo) %>
  <!-- Loading='lazy' causes delay before visible -->
</div>

<!-- RIGHT - Use eager loading for above-the-fold -->
<div class="hero" style="height: 500px;">
  <%= opt_image_tag(photo, eager: true, fetchpriority: "high") %>
  <!-- Loads immediately, high priority for LCP -->
</div>
```

---

### 5. Undefined Method on Nil Photo

```ruby
# WRONG - Crashes if ordered_photo returns nil
<%= opt_image_tag(@property.ordered_photo(1)) %>
<!-- Error if @property has no photos -->

# RIGHT - Check first
<% if @property.prop_photos.any? %>
  <%= opt_image_tag(@property.ordered_photo(1)) %>
<% end %>

# OR use safe navigation
<%= opt_image_tag(@property.ordered_photo(1), class: "image") if @property.ordered_photo(1) %>
```

---

### 6. Variant Generated But Not Cached

```ruby
# WRONG - Generates variant every request (slow)
photo.image.variant(resize_to_limit: [500, 500])

# RIGHT - Cached after first generation
# First request: generates file
variant = photo.image.variant(resize_to_limit: [500, 500])
url = url_for(variant)  # Generates and caches

# Subsequent requests: uses cached record
variant = photo.image.variant(resize_to_limit: [500, 500])
url = url_for(variant)  # Uses cache

# Verify in DB:
ActiveStorage::VariantRecord.where(blob_id: photo.image.blob.id)
```

---

### 7. External Image URL Mode Not Enabled

```ruby
# WRONG - Trying to save external URL when mode disabled
photo = Pwb::PropPhoto.new(
  prop: property,
  external_url: "https://cdn.example.com/image.jpg"
)
photo.external_image_mode?  # => false (website doesn't have mode enabled)
photo.save                  # Works, but not the intended pattern

# RIGHT - Enable external image mode for website
website.update(external_image_mode: true)
photo = Pwb::PropPhoto.new(
  prop: property,
  external_url: "https://cdn.example.com/image.jpg"
)
photo.external_image_mode?  # => true
photo.save
```

---

### 8. N+1 Query Loading Images

```ruby
# WRONG - N+1 queries
@properties.each do |prop|
  url = prop.prop_photos.first.image.url  # Loads photo + blob each time
end

# RIGHT - Eager load attachments
@properties = Property.includes(prop_photos: :image_attachment).all
@properties.each do |prop|
  url = prop.prop_photos.first.image.url  # Already loaded
end

# OR use specific query
@properties = Property.eager_load(prop_photos: :image_attachment).all
```

---

### 9. Picture Element Not Generating WebP

```erb
<!-- WRONG - Picture element requires explicit flag -->
<%= opt_image_tag(photo) %>
<!-- No picture element, no WebP variant -->

<!-- RIGHT - Enable picture element -->
<%= opt_image_tag(photo, use_picture: true) %>
<!-- Generates <picture><source type="image/webp">...<img>... -->
```

---

### 10. Storage Service Not Configured for Environment

```ruby
# WRONG - No storage service configured
# ActiveStorage raises error when trying to attach file

# RIGHT - Ensure config/storage.yml has all services
# And config/environments/*.rb specifies the service:
# development.rb: config.active_storage.service = :cloudflare_r2
# test.rb:        config.active_storage.service = :test
# production.rb:  config.active_storage.service = :cloudflare_r2
```

---

## Best Practices Summary

1. **Always set alt text** for accessibility and SEO
2. **Use eager loading for heroes** (above-the-fold images)
3. **Lazy load grid thumbnails** (below-the-fold)
4. **Use WebP for modern browsers** (picture element)
5. **Set explicit heights** to prevent layout shift
6. **Check `before` using helpers** on possibly nil photos
7. **Use factories with :with_image trait** in tests
8. **Eager load attachments** to prevent N+1 queries
9. **Enable external image mode deliberately** for CDN references
10. **Let variants cache** (don't regenerate unnecessarily)
