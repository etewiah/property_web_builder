# Media Library - Code Examples

## Current Code Patterns to Understand

### Example 1: Understanding PropPhoto Model

```ruby
# From: app/models/pwb/prop_photo.rb
module Pwb
  class PropPhoto < ApplicationRecord
    include ExternalImageSupport

    has_one_attached :image, dependent: :purge_later
    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true
    belongs_to :realty_asset, optional: true

    # Check if website is in external image mode
    def external_image_mode?
      prop&.website&.external_image_mode || false
    end
  end
end
```

**Key Points**:
- Uses `ExternalImageSupport` concern for URL/external image support
- `has_one_attached :image` = ActiveStorage integration
- `dependent: :purge_later` = async deletion
- Two parent associations for backwards compatibility
- Method to check if website uses external images

### Example 2: ExternalImageSupport Concern

```ruby
# From: app/models/concerns/external_image_support.rb
module ExternalImageSupport
  extend ActiveSupport::Concern

  included do
    validates :external_url, format: {
      with: /\A(https?:\/\/)[\w\-._~:\/?#\[\]@!$&'()*+,;=%]+\z/i,
      message: "must be a valid HTTP or HTTPS URL"
    }, allow_blank: true
  end

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
      external_url
    elsif image.attached? && image.variable?
      Rails.application.routes.url_helpers.rails_representation_path(
        image.variant(resize_to_limit: size),
        only_path: true
      )
    elsif image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end

  def has_image?
    external? || image.attached?
  end

  private

  def active_storage_url(variant_options: nil)
    return nil unless image.attached?

    if variant_options && image.variable?
      Rails.application.routes.url_helpers.rails_representation_path(
        image.variant(variant_options),
        only_path: true
      )
    else
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end
end
```

**Key Learning Points**:
- Concern pattern for shared behavior
- URL validation with regex
- Conditional logic for external vs uploaded images
- Helper method generation for URLs
- Variant support for ActiveStorage images

### Example 3: ImageGalleryBuilder Service

```ruby
# From: app/services/pwb/image_gallery_builder.rb
module Pwb
  class ImageGalleryBuilder
    DEFAULT_LIMITS = {
      content: 50,
      website: 20,
      property: 30
    }.freeze

    THUMBNAIL_SIZE = [150, 150].freeze

    def initialize(website, url_helper:, limits: {})
      @website = website
      @url_helper = url_helper
      @limits = DEFAULT_LIMITS.merge(limits)
    end

    def build
      images = []
      images.concat(content_photos)
      images.concat(website_photos)
      images.concat(property_photos)
      images
    end

    def content_photos
      photos = ContentPhoto.joins(:content)
                           .where(pwb_contents: { website_id: @website&.id })
                           .order(created_at: :desc)
                           .limit(@limits[:content])

      build_photo_hashes(photos, type: 'content', id_prefix: 'content') do |photo|
        photo.description
      end
    end

    private

    def build_photo_hashes(photos, type:, id_prefix:)
      photos.filter_map do |photo|
        next unless photo.image.attached?

        build_single_photo_hash(photo, type: type, id_prefix: id_prefix) do
          yield(photo) if block_given?
        end
      end
    end

    def build_single_photo_hash(photo, type:, id_prefix:)
      {
        id: "#{id_prefix}_#{photo.id}",
        type: type,
        url: @url_helper.url_for(photo.image),
        thumb_url: thumbnail_url(photo.image),
        filename: photo.image.filename.to_s,
        description: block_given? ? yield : nil
      }
    rescue StandardError => e
      Rails.logger.warn "Error processing #{type} photo #{photo.id}: #{e.message}"
      nil
    end

    def thumbnail_url(image)
      return @url_helper.url_for(image) unless image.variable?
      @url_helper.url_for(image.variant(resize_to_limit: THUMBNAIL_SIZE))
    rescue StandardError => e
      Rails.logger.warn "Error generating thumbnail: #{e.message}"
      @url_helper.url_for(image)
    end
  end
end
```

**Key Learning Points**:
- Service object pattern for business logic
- Composition over inheritance
- Error handling with fallbacks
- Hash construction with metadata
- Filter mapping pattern (filter_map)
- Query optimization (limits)

### Example 4: Site Admin Images Controller

```ruby
# From: app/controllers/site_admin/images_controller.rb
module SiteAdmin
  class ImagesController < ::SiteAdminController
    skip_before_action :verify_authenticity_token, only: [:create]

    def index
      gallery_builder = Pwb::ImageGalleryBuilder.new(current_website, url_helper: self)
      render json: { images: gallery_builder.build }
    end

    def create
      if params[:image].present?
        content = find_or_create_uploads_content
        content_photo = Pwb::ContentPhoto.new(content: content)
        content_photo.image.attach(params[:image])

        if content_photo.save
          render json: {
            success: true,
            image: {
              id: "content_#{content_photo.id}",
              type: 'content',
              url: url_for(content_photo.image),
              thumb_url: thumbnail_url(content_photo.image),
              filename: content_photo.image.filename.to_s
            }
          }
        else
          render json: { 
            success: false, 
            errors: content_photo.errors.full_messages 
          }, status: :unprocessable_entity
        end
      else
        render json: { 
          success: false, 
          errors: ['No image provided'] 
        }, status: :bad_request
      end
    end

    private

    def thumbnail_url(image)
      return url_for(image) unless image.variable?
      url_for(image.variant(resize_to_limit: [150, 150]))
    rescue StandardError => e
      Rails.logger.warn "Error generating thumbnail: #{e.message}"
      url_for(image)
    end

    def find_or_create_uploads_content
      Pwb::Content.find_or_create_by!(
        website_id: current_website.id,
        tag: 'site_admin_uploads'
      )
    end
  end
end
```

**Key Learning Points**:
- Skip CSRF for API endpoints
- JSON responses for AJAX
- Error handling with status codes
- find_or_create_by for default records
- Helper method extraction

### Example 5: Images Helper - Rendering Patterns

```ruby
# From: app/helpers/pwb/images_helper.rb

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

# Image tag with WebP support
def opt_image_tag(photo, options = {})
  return nil unless photo

  use_picture = options.delete(:use_picture)
  width = options.delete(:width)
  height = options.delete(:height)

  if photo.respond_to?(:external?) && photo.external?
    return image_tag(photo.external_url, options)
  end

  return nil unless photo.respond_to?(:image) && photo.image.attached?

  variant_options = {}
  variant_options[:resize_to_limit] = [width, height].compact if width || height

  if use_picture && photo.image.variable?
    optimized_image_picture(photo, variant_options, options)
  elsif variant_options.present? && photo.image.variable?
    image_tag photo.image.variant(variant_options), options
  else
    image_tag url_for(photo.image), options
  end
end

# Picture element with WebP
def optimized_image_picture(photo, variant_options = {}, html_options = {})
  webp_options = variant_options.merge(format: :webp)
  fallback_url = variant_options.present? ? 
    url_for(photo.image.variant(variant_options)) : 
    url_for(photo.image)

  content_tag(:picture) do
    webp_source = tag(:source,
                      srcset: url_for(photo.image.variant(webp_options)),
                      type: "image/webp")
    fallback_img = image_tag(fallback_url, html_options)
    safe_join([webp_source, fallback_img])
  end
rescue StandardError => e
  Rails.logger.warn("Failed to generate optimized image: #{e.message}")
  image_tag url_for(photo.image), html_options
end

# Simple URL getter
def photo_url(photo)
  return nil unless photo

  if photo.respond_to?(:external?) && photo.external?
    photo.external_url
  elsif photo.respond_to?(:image) && photo.image.attached?
    url_for(photo.image)
  end
end

# Check if photo has image
def photo_has_image?(photo)
  return false unless photo

  if photo.respond_to?(:has_image?)
    photo.has_image?
  elsif photo.respond_to?(:external?) && photo.external?
    true
  elsif photo.respond_to?(:image)
    photo.image.attached?
  else
    false
  end
end
```

**Key Learning Points**:
- Helper method composition
- Conditional rendering
- Rails tag helpers (image_tag, tag, content_tag)
- HTML safety (.html_safe)
- safe_join for combining HTML elements
- Graceful degradation with rescue blocks

## Patterns to Follow in Media Library Implementation

### 1. Model with ActiveStorage and Concern

```ruby
# Good pattern
module Pwb
  class Media < ApplicationRecord
    include ActsAsTenant::TenantModel
    
    has_one_attached :file, dependent: :purge_later
    belongs_to :website, class_name: 'Pwb::Website'
    
    validates :file_name, presence: true
    
    scope :not_deleted, -> { where(deleted_at: nil) }
  end
end
```

### 2. Service Object for Business Logic

```ruby
# Good pattern
module Pwb
  class MediaService
    def initialize(website)
      @website = website
    end
    
    def upload(file:, metadata: {})
      validate_file(file)
      media = create_media_record(file, metadata)
      optimize_and_store(media, file)
      media
    end
    
    private
    
    def validate_file(file)
      # Validation logic
    end
    
    def create_media_record(file, metadata)
      # Create media record
    end
    
    def optimize_and_store(media, file)
      # Optimization logic
    end
  end
end
```

### 3. API Controller with JSON Response

```ruby
# Good pattern
class SiteAdmin::Api::MediaController < SiteAdminController
  skip_before_action :verify_authenticity_token, only: [:create]
  
  def index
    media = Pwb::Media.where(website_id: current_website.id)
                      .not_deleted
                      .page(params[:page])
                      .per(50)
    
    render json: {
      media: media.as_json,
      total: media.total_count,
      page: media.current_page
    }
  end
  
  def create
    service = Pwb::MediaService.new(current_website)
    media = service.upload(file: params[:file], metadata: params[:metadata])
    
    render json: { success: true, media: media.as_json }, status: :created
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end
end
```

### 4. Polymorphic Association for Usage Tracking

```ruby
# Good pattern for tracking where media is used
class SiteAdmin::Api::MediaUsageController < SiteAdminController
  def show
    media = Pwb::Media.find(params[:id])
    usage = media.attachments.group_by(&:attachable_type)
    
    render json: { usage: usage }
  end
end

# In Media model:
# has_many :attachments, class_name: 'Pwb::MediaAttachment'

# In MediaAttachment:
# belongs_to :media
# belongs_to :attachable, polymorphic: true
```

## Testing Patterns

### Model Spec

```ruby
require 'rails_helper'

module Pwb
  describe Media, type: :model do
    let(:website) { create(:pwb_website) }
    
    describe 'associations' do
      it { is_expected.to belong_to(:website) }
      it { is_expected.to have_one_attached(:file) }
    end
    
    describe 'validations' do
      it { is_expected.to validate_presence_of(:file_name) }
      it { is_expected.to validate_presence_of(:mime_type) }
    end
    
    describe '#image?' do
      it 'returns true for image mime types' do
        media = build(:pwb_media, mime_type: 'image/jpeg')
        expect(media.image?).to be true
      end
      
      it 'returns false for non-image mime types' do
        media = build(:pwb_media, mime_type: 'video/mp4')
        expect(media.image?).to be false
      end
    end
  end
end
```

### Service Spec

```ruby
require 'rails_helper'

module Pwb
  describe MediaService do
    let(:website) { create(:pwb_website) }
    let(:service) { described_class.new(website) }
    let(:file) { fixture_file_upload('test.jpg', 'image/jpeg') }
    
    describe '#upload' do
      it 'creates a media record' do
        expect {
          service.upload(file: file, metadata: { title: 'Test' })
        }.to change(Media, :count).by(1)
      end
      
      it 'attaches the file' do
        media = service.upload(file: file, metadata: { title: 'Test' })
        expect(media.file).to be_attached
      end
      
      it 'raises error for invalid file' do
        expect {
          service.upload(file: nil, metadata: {})
        }.to raise_error(StandardError)
      end
    end
  end
end
```

### Controller Spec

```ruby
require 'rails_helper'

describe SiteAdmin::Api::MediaController, type: :controller do
  let(:website) { create(:pwb_website) }
  let(:user) { create(:pwb_user) }
  
  before { sign_in user }
  
  describe 'GET #index' do
    it 'returns media list' do
      create(:pwb_media, website: website)
      get :index
      expect(response).to be_successful
      expect(json_response[:media]).to be_present
    end
  end
  
  describe 'POST #create' do
    it 'uploads media' do
      file = fixture_file_upload('test.jpg', 'image/jpeg')
      post :create, params: { 
        file: file, 
        metadata: { title: 'Test' }
      }
      expect(response).to be_successful
      expect(json_response[:success]).to be true
    end
  end
end
```

## Migration Example

```ruby
# db/migrate/[timestamp]_create_pwb_media.rb
class CreatePwbMedia < ActiveRecord::Migration[7.0]
  def change
    create_table :pwb_media, id: :uuid do |t|
      # Core fields
      t.references :website, type: :bigint, foreign_key: { to_table: :pwb_websites }
      
      # File information
      t.string :file_name, null: false
      t.string :mime_type, null: false
      t.integer :file_size
      
      # Image metadata
      t.integer :width
      t.integer :height
      
      # Organization
      t.references :folder, type: :bigint, foreign_key: { to_table: :pwb_media_folders }
      
      # Content
      t.string :title
      t.text :description
      t.string :alt_text
      
      # Tracking
      t.references :created_by_user, type: :bigint, foreign_key: { to_table: :pwb_users }
      
      # Soft delete
      t.datetime :deleted_at
      
      t.timestamps
    end
    
    add_index :pwb_media, :website_id
    add_index :pwb_media, :folder_id
    add_index :pwb_media, [:website_id, :deleted_at]
    add_index :pwb_media, :created_at
  end
end
```

## Factory Pattern

```ruby
# spec/factories/pwb/media.rb
FactoryBot.define do
  factory :pwb_media, class: 'Pwb::Media' do
    website
    sequence(:file_name) { |n| "test_#{n}.jpg" }
    mime_type { 'image/jpeg' }
    file_size { 1024 }
    width { 800 }
    height { 600 }
    title { 'Test Image' }
    description { 'A test image' }
    
    after(:build) do |media|
      media.file.attach(
        io: File.open(Rails.root.join('spec/fixtures/files/test.jpg')),
        filename: media.file_name,
        content_type: media.mime_type
      )
    end
  end
end
```
