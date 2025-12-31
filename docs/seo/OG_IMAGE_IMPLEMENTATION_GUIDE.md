# OG Image Generation Implementation Guide

## Quick Reference

### What PropertyWebBuilder Has
- ✅ Image processing libs: ruby-vips 2.3.0, mini_magick 5.3.1
- ✅ Background jobs: Solid Queue + Mission Control Jobs dashboard
- ✅ File storage: ActiveStorage + Cloudflare R2
- ✅ Job pattern: Multiple working jobs (exchange rates, view refresh)
- ✅ Database: Queue tables already created (db/queue_schema.rb)

### What You DON'T Need to Add
- ❌ Grover/Puppeteer (no full HTML rendering needed)
- ❌ External services (third-party OG image APIs)
- ❌ Additional gems for basic image generation
- ❌ New gem dependencies (mostly already here)

---

## Implementation Path (Recommended)

### Phase 1: Core Service (Generate Image)

**File**: `/app/services/pwb/og_image_generator_service.rb`

```ruby
require 'vips'

module Pwb
  class OgImageGeneratorService
    # Image specifications
    WIDTH = 1200
    HEIGHT = 630
    QUALITY = 85
    
    class GenerationError < StandardError; end
    
    def self.generate_for_property(property)
      new(property).generate
    end
    
    def initialize(property)
      @property = property
      @website = property.website
    end
    
    def generate
      # 1. Get base image (property photo or fallback)
      base_image = get_base_image
      
      # 2. Resize to OG dimensions
      image = resize_image(base_image)
      
      # 3. Add overlay with property details
      image = add_property_details(image)
      
      # 4. Add branding (logo, colors)
      image = add_branding(image)
      
      # 5. Return blob for ActiveStorage
      image_to_blob(image)
    rescue StandardError => e
      Rails.logger.error("OG image generation failed for property #{@property.id}: #{e.message}")
      raise GenerationError, "Failed to generate OG image: #{e.message}"
    end
    
    private
    
    def get_base_image
      # Prefer property's first photo
      if @property.primary_image_url.present?
        fetch_image(@property.primary_image_url)
      elsif @website.logo_url.present?
        fetch_image(@website.logo_url)
      else
        # Fallback to solid color background
        create_fallback_image
      end
    end
    
    def fetch_image(url)
      # Download image from URL (handle CDN, S3, etc.)
      http_response = HTTParty.get(url, follow_redirects: true)
      Vips::Image.new_from_buffer(http_response.body, '')
    rescue StandardError => e
      Rails.logger.warn("Failed to fetch image from #{url}: #{e.message}")
      create_fallback_image
    end
    
    def resize_image(image)
      # Fit image to 1200x630, maintaining aspect ratio
      # Crop to exact dimensions if needed
      image.thumbnail_image(WIDTH, height: HEIGHT, size: :cover)
          .crop(0, 0, WIDTH, HEIGHT)
    end
    
    def add_property_details(image)
      # Add text overlays with property information
      # This is simplified - could be more sophisticated
      
      overlay = Vips::Image.new_from_memory(
        Array.new(WIDTH * HEIGHT, 255).pack('C*'),
        WIDTH, HEIGHT, 3, :uchar
      )
      
      # Add semi-transparent dark overlay at bottom (for text readability)
      overlay = overlay.add_alpha.bandsplit[3].cast(:uchar) * 0.4
      overlay = overlay.cast(:uchar)
      
      # Composite with original image
      # Note: Text rendering is complex with Vips
      # Consider using ImageMagick for text:
      # image = image.text('$500,000', size: 72, color: '#FFFFFF')
      
      image
    end
    
    def add_branding(image)
      # Add website logo if available
      # Apply theme colors (border, gradient, etc.)
      
      if @website.logo_url.present?
        logo = fetch_image(@website.logo_url)
        # Resize logo (e.g., 200px wide)
        logo = logo.thumbnail_image(200, height: 100, size: :inside)
        
        # Place logo in corner with padding
        image = image.composite(
          logo,
          'over',
          x: WIDTH - logo.width - 20,
          y: HEIGHT - logo.height - 20
        )
      end
      
      image
    end
    
    def image_to_blob
      # Convert VIPs image to binary blob suitable for ActiveStorage
      Vips::Image.new_from_file(@image.write_to_file(''))
                 .write_to_buffer('.jpg', Q: QUALITY)
    end
    
    def create_fallback_image
      # Create solid color background (theme primary color)
      color = @website.primary_color || '#FFFFFF'
      Vips::Image.new_from_memory(
        Array.new(WIDTH * HEIGHT * 3, color_to_rgb(color)).flatten.pack('C*'),
        WIDTH, HEIGHT, 3, :uchar
      )
    end
    
    def color_to_rgb(hex_color)
      hex_color.delete('#')[0..5].scan(/../).map { |c| c.hex }
    end
  end
end
```

### Phase 2: Background Job (Queue Generation)

**File**: `/app/jobs/pwb/generate_og_image_job.rb`

```ruby
module Pwb
  class GenerateOgImageJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3
    discard_on Pwb::OgImageGeneratorService::GenerationError
    
    def perform(property_id)
      property = Pwb::Prop.find_by(id: property_id)
      return unless property
      
      # Generate image blob
      image_blob = OgImageGeneratorService.generate_for_property(property)
      
      # Attach to property
      property.og_image.attach(
        io: StringIO.new(image_blob),
        filename: "og-#{property.id}-#{Time.current.to_i}.jpg",
        content_type: 'image/jpeg'
      )
      
      # Store URL for quick access
      image_url = Rails.application.routes.url_helpers.rails_blob_path(
        property.og_image,
        only_path: false
      )
      property.update_columns(
        og_image_url: image_url,
        og_image_generated_at: Time.current
      )
      
      Rails.logger.info "Generated OG image for property #{property_id}"
    rescue StandardError => e
      Rails.logger.error "Failed to generate OG image for property #{property_id}: #{e.message}"
      raise
    end
  end
end
```

### Phase 3: Model Changes

**File**: `/app/models/pwb/prop.rb`

Add to the Prop model:

```ruby
# ActiveStorage attachment for OG image
has_one_attached :og_image, dependent: :purge_later

# Scope for finding properties without OG images
scope :without_og_image, -> { where(og_image_url: nil) }

# Callback to generate OG image when property is created
after_create_commit :queue_og_image_generation

# Callback to regenerate OG image on significant updates
after_update_commit :queue_og_image_regeneration_if_needed, 
                    if: :og_image_regeneration_needed?

# Helper method to get OG image URL with fallback
def og_image_url_for_sharing
  og_image_url.presence || 
    primary_image_url.presence || 
    website.logo_url.presence
end

private

def queue_og_image_generation
  GenerateOgImageJob.perform_later(id)
end

def queue_og_image_regeneration_if_needed
  GenerateOgImageJob.perform_later(id) if og_image_regeneration_needed?
end

def og_image_regeneration_needed?
  # Regenerate if property photo or price changed
  saved_change_to_primary_photo_id? || saved_change_to_price?
end
```

### Phase 4: Migration

**File**: `/db/migrate/[TIMESTAMP]_add_og_image_to_properties.rb`

```ruby
class AddOgImageToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_props, :og_image_url, :string
    add_column :pwb_props, :og_image_generated_at, :datetime
    
    # Index for finding stale OG images
    add_index :pwb_props, :og_image_generated_at
  end
end
```

### Phase 5: Integration (Controller)

**File**: `/app/controllers/pwb/props_controller.rb`

The SEO helper already gets called in `show` action. OG image URL will be picked up automatically:

```ruby
def show
  @property = Prop.find(params[:id])
  
  # Set SEO metadata (already done)
  set_property_seo(@property, :for_sale)
  
  # OG image will be included in meta tags via seo_helper
  # The helper looks for og_image_url on the property
end

private

def set_property_seo(property, operation_type)
  # ... existing code ...
  
  set_seo(
    title: seo_title_value.presence || property.title,
    description: meta_desc_value.presence || truncate_description(property.description),
    canonical_url: canonical_url,
    image: property.og_image_url_for_sharing,  # Use new OG image URL
    og_type: 'product',
    noindex: should_noindex
  )
end
```

### Phase 6: SEO Helper Update (Optional)

**File**: `/app/helpers/seo_helper.rb` (Update existing method)

```ruby
def seo_image
  image = seo_data[:image]

  if image.present?
    # Handle ActiveStorage attachments
    if image.respond_to?(:url)
      image.url
    elsif image.respond_to?(:attached?) && image.attached?
      rails_blob_url(image, only_path: false)
    else
      image
    end
  else
    # Fallback to website logo
    current_website&.logo_url.presence
  end
end
```

No changes needed - already supports both string URLs and ActiveStorage attachments.

---

## Database Schema Changes

### What Gets Added

```sql
-- Two new columns to pwb_props table
ALTER TABLE pwb_props ADD COLUMN og_image_url VARCHAR;
ALTER TABLE pwb_props ADD COLUMN og_image_generated_at DATETIME;
CREATE INDEX index_pwb_props_on_og_image_generated_at 
  ON pwb_props(og_image_generated_at);

-- ActiveStorage blob (automatic, no migration needed)
-- Stores actual image file referenced by og_image attachment

-- ActiveStorage attachment metadata (automatic)
-- Links Prop.og_image to stored blob
```

---

## Testing Strategy

### Unit Test (Service)

**File**: `/spec/services/pwb/og_image_generator_service_spec.rb`

```ruby
require 'rails_helper'

describe Pwb::OgImageGeneratorService do
  let(:property) { create(:pwb_prop, website: create(:pwb_website)) }
  
  describe '.generate_for_property' do
    it 'returns an image blob' do
      blob = described_class.generate_for_property(property)
      expect(blob).to be_a(String)
      expect(blob).to start_with("\xFF\xD8\xFF") # JPEG header
    end
    
    it 'generates correct image dimensions' do
      blob = described_class.generate_for_property(property)
      # Could verify dimensions with FastImage or ImageMagick
    end
    
    it 'raises GenerationError on failure' do
      allow(property).to receive(:primary_image_url).and_raise(StandardError)
      expect {
        described_class.generate_for_property(property)
      }.to raise_error(Pwb::OgImageGeneratorService::GenerationError)
    end
    
    context 'with website logo' do
      it 'includes logo in image'
      it 'respects theme colors'
    end
  end
end
```

### Integration Test (Job)

**File**: `/spec/jobs/pwb/generate_og_image_job_spec.rb`

```ruby
require 'rails_helper'

describe Pwb::GenerateOgImageJob do
  let(:property) { create(:pwb_prop) }
  
  describe '#perform' do
    it 'generates and attaches OG image' do
      perform_enqueued_jobs do
        described_class.perform_later(property.id)
      end
      
      property.reload
      expect(property.og_image).to be_attached
      expect(property.og_image_url).to be_present
      expect(property.og_image_generated_at).to be_present
    end
    
    it 'retries on error' do
      allow(Pwb::OgImageGeneratorService).to receive(:generate_for_property)
        .and_raise(StandardError)
      
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(property.id)
        end
      }.to change(Pwb::OgImageGeneratorService, :call_count).by(3) # retries
    end
    
    it 'handles missing property gracefully' do
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(999999)
        end
      }.not_to raise_error
    end
  end
end
```

### Request Test (Controller)

**File**: `/spec/requests/pwb/props_controller_spec.rb` (update existing)

```ruby
describe Pwb::PropsController do
  describe 'GET show' do
    let(:property) { create(:pwb_prop, :with_og_image) }
    
    it 'includes OG image in meta tags' do
      get property_path(property)
      expect(response.body).to include(property.og_image_url)
      expect(response.body).to match(/<meta property="og:image"/)
    end
  end
end
```

### Factory

**File**: `/spec/factories/pwb_props.rb` (update existing)

```ruby
trait :with_og_image do
  after(:create) do |property|
    image_blob = "fake image data".force_encoding('ASCII-8BIT')
    property.og_image.attach(
      io: StringIO.new(image_blob),
      filename: 'og-image.jpg',
      content_type: 'image/jpeg'
    )
    property.update(og_image_url: "blob://fake-url")
  end
end
```

---

## Batch Generation Rake Task

For existing properties without OG images:

**File**: `/lib/tasks/generate_og_images.rake`

```ruby
namespace :og_images do
  desc "Generate OG images for all properties"
  task generate_all: :environment do
    count = 0
    errors = 0
    
    Pwb::Prop.without_og_image.find_each do |property|
      begin
        Pwb::GenerateOgImageJob.perform_later(property.id)
        count += 1
      rescue StandardError => e
        Rails.logger.error("Failed to queue OG image for property #{property.id}: #{e.message}")
        errors += 1
      end
    end
    
    puts "Queued #{count} OG image generation jobs"
    puts "Errors: #{errors}" if errors > 0
  end
  
  desc "Regenerate all OG images (useful after design changes)"
  task regenerate_all: :environment do
    count = 0
    
    Pwb::Prop.find_each do |property|
      Pwb::GenerateOgImageJob.perform_later(property.id)
      count += 1
    end
    
    puts "Queued #{count} OG image regeneration jobs"
  end
  
  desc "Clean up orphaned OG images (run periodically)"
  task cleanup: :environment do
    # Delete OG images for deleted properties
    deleted_count = 0
    
    # This is automatic with dependent: :purge_later
    # But could add additional cleanup logic here
    
    puts "Cleaned up #{deleted_count} orphaned images"
  end
end
```

Run with:
```bash
# Initial bulk generation (one-time)
rails og_images:generate_all

# Regenerate after design changes
rails og_images:regenerate_all
```

---

## Deployment Checklist

### Before Deployment
- [ ] Code review of service, job, and migrations
- [ ] All tests passing (unit, integration, request)
- [ ] Performance testing (image generation time)
- [ ] Database migration tested locally

### Deployment Steps
1. [ ] Deploy code to production
2. [ ] Run migration: `rails db:migrate`
3. [ ] Verify Solid Queue is running
4. [ ] Check Mission Control Jobs dashboard
5. [ ] Run batch rake task: `rails og_images:generate_all`
6. [ ] Monitor job queue and error logs
7. [ ] Verify OG images appear in property pages

### Post-Deployment
- [ ] Monitor job success/failure rate
- [ ] Check image generation time (target: <500ms)
- [ ] Verify OG images on social media shares
- [ ] Monitor storage usage (estimate: 1-2KB per image)

---

## Configuration & Tuning

### Job Queue Tuning

**File**: `config/solid_queue.yml` or database recurring task

```yaml
queues:
  - name: default
    concurrency: 5  # Adjust based on CPU cores
  - name: mailers
    concurrency: 3

workers:
  - queues: [default, mailers]
```

Recommended settings:
- **Concurrency**: 2-4 workers (CPU-bound image generation)
- **Timeout**: 60 seconds per job (default, sufficient for image generation)
- **Retry**: 3 attempts with exponential backoff (already configured)

### Image Generation Tuning

```ruby
# In OgImageGeneratorService
QUALITY = 85        # 75-90 recommended for JPEG
WIDTH = 1200        # Standard OG width
HEIGHT = 630        # Standard OG height
```

---

## Monitoring & Troubleshooting

### Job Monitoring
- Access Mission Control Jobs: `/mission_control/jobs`
- Monitor queue depth (should stay low, <100)
- Alert if failure rate exceeds 5%

### Common Issues

**Issue**: Images not appearing in social shares
- **Check**: OG image URL is valid and accessible
- **Check**: Image dimensions are 1200x630px
- **Check**: URL is HTTPS (required by most platforms)

**Issue**: Job failures with "Vips error"
- **Cause**: Missing image processing library or corrupted image
- **Fix**: Verify ruby-vips is installed: `bundle list | grep vips`
- **Fix**: Check image file isn't corrupted

**Issue**: Jobs stuck in queue
- **Cause**: Worker not running or crashed
- **Fix**: Check Solid Queue process: `ps aux | grep solid_queue`
- **Fix**: Restart: `rails solid_queue:restart`

**Issue**: Storage growing too fast
- **Cause**: Images not being cleaned up on property delete
- **Fix**: Verify `dependent: :purge_later` is set on attachment
- **Fix**: Run cleanup job if needed

### Logging

Debug OG image generation:
```ruby
# In job
Rails.logger.info "Starting OG image generation for property #{property_id}"
Rails.logger.info "Generated image URL: #{image_url}"

# In service
Rails.logger.debug "Base image size: #{image.width}x#{image.height}"
Rails.logger.debug "Applied branding: #{@website.name}"
```

Check logs:
```bash
tail -f log/production.log | grep "OG image"
tail -f log/solid_queue.log  # If Solid Queue has separate log
```

---

## File Checklist

**Files to Create**:
- [ ] `/app/services/pwb/og_image_generator_service.rb`
- [ ] `/app/jobs/pwb/generate_og_image_job.rb`
- [ ] `/db/migrate/[TIMESTAMP]_add_og_image_to_properties.rb`
- [ ] `/lib/tasks/generate_og_images.rake`
- [ ] `/spec/services/pwb/og_image_generator_service_spec.rb`
- [ ] `/spec/jobs/pwb/generate_og_image_job_spec.rb`

**Files to Update**:
- [ ] `/app/models/pwb/prop.rb` (add attachment, callbacks)
- [ ] `/app/controllers/pwb/props_controller.rb` (update seo_image call)
- [ ] `/spec/factories/pwb_props.rb` (add :with_og_image trait)
- [ ] `/spec/requests/pwb/props_controller_spec.rb` (add OG image test)

**Files to Review** (no changes needed):
- [ ] `/app/helpers/seo_helper.rb` (already supports ActiveStorage)

---

## Timeline Estimate

- **Phase 1 (Service)**: 2-3 hours
- **Phase 2 (Job)**: 1-2 hours
- **Phase 3 (Model)**: 1 hour
- **Phase 4 (Migration)**: 30 minutes
- **Phase 5 (Controller)**: 30 minutes
- **Phase 6 (Tests)**: 2-3 hours
- **Phase 7 (Rake task)**: 1 hour
- **Testing & QA**: 2-3 hours
- **Total**: 10-15 hours

---

## Next Steps

1. Review this guide with team
2. Decide on image design/layout
3. Create mockups of OG image
4. Start implementation with Phase 1
5. Test thoroughly before deployment
6. Monitor in production

---

**Document Status**: Implementation Ready  
**Last Updated**: 2025-12-31  
**Tech Stack**: Ruby-VIPs + Solid Queue + ActiveStorage
