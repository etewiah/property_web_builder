# OG Image Generation - Quick Start Guide

## TL;DR

PropertyWebBuilder can implement **dynamic OG image generation** using:
- **ruby-vips** (already installed) - Image processing
- **Solid Queue** (already configured) - Background jobs
- **ActiveStorage** (already set up) - File storage

**No new gems needed.** Estimated effort: 10-15 hours.

---

## Key Findings

### What's Already Here

```
Image Processing:
  ✅ image_processing ~> 1.2 (Gemfile)
  ✅ ruby-vips 2.3.0 (installed)
  ✅ mini_magick 5.3.1 (installed as fallback)

Background Jobs:
  ✅ Solid Queue ~> 1.0 (Gemfile)
  ✅ Mission Control Jobs ~> 1.0 (dashboard)
  ✅ Database queue tables (db/queue_schema.rb)
  ✅ Working jobs: UpdateExchangeRatesJob, RefreshPropertiesViewJob

File Storage:
  ✅ ActiveStorage configured
  ✅ Cloudflare R2 in production
  ✅ Used by: PropPhoto, ContentPhoto, WebsitePhoto, Media models
  ✅ Image variants support (thumb, small, medium, large)

Multi-Tenancy:
  ✅ ActsAsTenant configured
  ✅ TenantAwareJob concern available
  ✅ Proper scoping patterns established
```

### What You DON'T Need

```
❌ Grover or Puppeteer (not needed for simple image generation)
❌ External OG image services
❌ ImageMagick binary (ruby-vips doesn't require it)
❌ New gems for basic functionality
❌ Separate queue database
```

---

## How It Works (Simple Diagram)

```
Property Created/Updated
         ↓
Queue OG Image Generation Job
         ↓
Background Worker (Solid Queue)
         ↓
OgImageGeneratorService:
  - Get property photo
  - Resize to 1200×630
  - Add text overlays (price, location)
  - Add website logo/branding
         ↓
Store image in ActiveStorage
         ↓
Save URL to property.og_image_url
         ↓
Render in SEO meta tags
         ↓
Social media scraper finds og:image tag
```

---

## Implementation Overview

### 4 Core Files to Create

1. **Service** - Generates the image
   ```ruby
   Pwb::OgImageGeneratorService.generate_for_property(property)
   # Returns: image blob
   ```

2. **Job** - Queues generation asynchronously
   ```ruby
   Pwb::GenerateOgImageJob.perform_later(property_id)
   # Runs in background, retries on failure
   ```

3. **Migration** - Add columns to properties table
   ```ruby
   # Add: og_image_url, og_image_generated_at
   ```

4. **Model Callbacks** - Trigger job on property changes
   ```ruby
   after_create_commit :queue_og_image_generation
   after_update_commit :queue_og_image_regeneration_if_needed
   ```

### 3 Files to Update

1. **Model** - Add attachment and callbacks
2. **Controller** - Use new OG image URL (actually, SEO helper already supports it)
3. **Tests** - Add specs for service and job

---

## Simplified Example

### What the Service Does

```ruby
# Input
property = Property.find(123)
property.primary_image_url  # => "https://example.com/photo.jpg"
property.price              # => 500000
property.website.logo_url   # => "https://example.com/logo.png"

# Service processes
image = OgImageGeneratorService.generate_for_property(property)

# Output
image  # => binary PNG/JPEG blob (1200×630 pixels)
```

### What the Job Does

```ruby
# Queue the job
GenerateOgImageJob.perform_later(property_id)

# Job process (in background)
1. Find property
2. Call OgImageGeneratorService.generate(property)
3. Attach image to property.og_image
4. Save URL to property.og_image_url
5. Update property.og_image_generated_at
```

### What the Controller Does

```ruby
# Existing code already works!
def show
  @property = Prop.find(params[:id])
  set_property_seo(@property, :for_sale)  # Already includes OG image
end

# SEO helper already finds the image:
# 1. Checks property.og_image_url (new)
# 2. Falls back to property.primary_image_url (existing)
# 3. Falls back to website.logo_url (existing)
```

---

## File Structure

```
app/
├── services/pwb/
│   └── og_image_generator_service.rb       [NEW]
├── jobs/pwb/
│   └── generate_og_image_job.rb            [NEW]
└── models/pwb/
    └── prop.rb                             [UPDATE]

db/
└── migrate/
    └── [timestamp]_add_og_image_to_properties.rb  [NEW]

lib/tasks/
└── generate_og_images.rake                 [NEW]

spec/
├── services/pwb/
│   └── og_image_generator_service_spec.rb  [NEW]
├── jobs/pwb/
│   └── generate_og_image_job_spec.rb       [NEW]
└── factories/
    └── pwb_props.rb                        [UPDATE]
```

---

## Step-by-Step Implementation

### Step 1: Create the Service
```ruby
# app/services/pwb/og_image_generator_service.rb
class OgImageGeneratorService
  WIDTH = 1200
  HEIGHT = 630
  
  def self.generate_for_property(property)
    new(property).generate
  end
  
  def initialize(property)
    @property = property
    @website = property.website
  end
  
  def generate
    # 1. Get base image (property photo)
    # 2. Resize to 1200×630
    # 3. Add text overlays (price, beds, location)
    # 4. Add website branding (logo, colors)
    # 5. Return binary blob
  end
end
```

### Step 2: Create the Job
```ruby
# app/jobs/pwb/generate_og_image_job.rb
class GenerateOgImageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(property_id)
    property = Pwb::Prop.find(property_id) || return
    
    # Generate image
    image_blob = OgImageGeneratorService.generate_for_property(property)
    
    # Attach to property
    property.og_image.attach(
      io: StringIO.new(image_blob),
      filename: "og-#{property_id}.jpg",
      content_type: 'image/jpeg'
    )
    
    # Save URL for quick access
    property.update_columns(
      og_image_url: url,
      og_image_generated_at: Time.current
    )
  end
end
```

### Step 3: Update the Model
```ruby
# app/models/pwb/prop.rb
class Prop < ApplicationRecord
  # Add attachment
  has_one_attached :og_image, dependent: :purge_later
  
  # Add callbacks
  after_create_commit :queue_og_image_generation
  after_update_commit :queue_og_image_regeneration_if_needed, 
                      if: :og_image_regeneration_needed?
  
  # Helper for SEO
  def og_image_url_for_sharing
    og_image_url.presence || primary_image_url.presence
  end
  
  private
  
  def queue_og_image_generation
    GenerateOgImageJob.perform_later(id)
  end
  
  def queue_og_image_regeneration_if_needed
    GenerateOgImageJob.perform_later(id) if og_image_regeneration_needed?
  end
  
  def og_image_regeneration_needed?
    saved_change_to_primary_photo_id? || saved_change_to_price?
  end
end
```

### Step 4: Add Migration
```ruby
# db/migrate/[timestamp]_add_og_image_to_properties.rb
class AddOgImageToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :pwb_props, :og_image_url, :string
    add_column :pwb_props, :og_image_generated_at, :datetime
    add_index :pwb_props, :og_image_generated_at
  end
end
```

### Step 5: Add Tests
```ruby
# spec/services/pwb/og_image_generator_service_spec.rb
describe Pwb::OgImageGeneratorService do
  it 'generates image blob' do
    property = create(:pwb_prop)
    blob = described_class.generate_for_property(property)
    expect(blob).to start_with("\xFF\xD8\xFF")  # JPEG header
  end
end

# spec/jobs/pwb/generate_og_image_job_spec.rb
describe Pwb::GenerateOgImageJob do
  it 'attaches image and saves URL' do
    property = create(:pwb_prop)
    perform_enqueued_jobs do
      described_class.perform_later(property.id)
    end
    property.reload
    expect(property.og_image_url).to be_present
  end
end
```

---

## How It Uses Existing Infrastructure

### Solid Queue Integration
```ruby
# Job automatically uses configured queue adapter
# (config/environments/production.rb)
config.active_job.queue_adapter = :solid_queue

# Job will be:
# - Persisted to database (solid_queue_jobs table)
# - Retried on failure (3 attempts)
# - Visible in Mission Control Jobs dashboard
# - Monitored by solid_queue workers
```

### ActiveStorage Integration
```ruby
# Image attached same way as existing photo models
has_one_attached :og_image, dependent: :purge_later

# Stored in same backend as other images:
# - Dev: Local disk (storage/ directory)
# - Prod: Cloudflare R2 (S3-compatible)

# URL generated automatically:
rails_blob_path(property.og_image, only_path: false)
```

### Ruby-VIPs Integration
```ruby
# Already installed and used elsewhere
require 'vips'

image = Vips::Image.new_from_file('photo.jpg')
image = image.resize(width: 1200, height: 630)
blob = image.write_to_buffer('.jpg', Q: 85)
```

---

## Database Impact

Minimal:
- 2 new columns: `og_image_url` (string), `og_image_generated_at` (datetime)
- 1 new index on `og_image_generated_at`
- New ActiveStorage blobs (automatic, ~1-2KB per image)
- No new tables

---

## Performance

- **Image Generation Time**: 100-500ms per image (very fast with Vips)
- **Memory Usage**: 50-100MB per concurrent job
- **Storage**: ~1-2KB per generated image
- **CPU**: Single-threaded, offloaded to background jobs
- **Network**: One CDN request to fetch source photo

### Recommended Setup
- **Workers**: 2-4 concurrent (CPU-bound)
- **Queue Depth**: Monitor, keep under 100
- **Timeout**: 60 seconds (sufficient for image generation)

---

## Monitoring

### Mission Control Jobs Dashboard
```
URL: /mission_control/jobs
Shows:
  - Job queue depth
  - Success/failure rates
  - Job execution time
  - Error messages
  - Retry attempts
```

### Logs
```bash
# Watch for OG image generation
tail -f log/production.log | grep "og_image"

# Check job status
rails dbconsole  # Query solid_queue_jobs table
```

---

## Common Scenarios

### When Property is Created
```
User creates property → 
  after_create_commit callback fires →
  GenerateOgImageJob.perform_later(id) →
  Background worker processes →
  Image stored, URL saved →
  Next social share includes custom image
```

### When Property is Updated
```
User changes photo or price →
  after_update_commit callback fires (if relevant fields changed) →
  GenerateOgImageJob.perform_later(id) →
  Old image replaced with new one →
  Social media preview updated
```

### Bulk Generation (Initial)
```bash
# For all existing properties without OG images
rails og_images:generate_all

# This queues jobs for all properties
# Background workers process during off-peak hours
```

---

## Deployment

1. **Create files** (service, job, etc.)
2. **Add migration** and run: `rails db:migrate`
3. **Deploy code** to production
4. **Verify Solid Queue** is running
5. **Run bulk generation**: `rails og_images:generate_all`
6. **Monitor** Mission Control Jobs dashboard
7. **Test** by sharing property on social media

---

## Success Criteria

- [ ] Job processes without errors
- [ ] Images stored in ActiveStorage
- [ ] URLs saved to property.og_image_url
- [ ] SEO meta tags include og:image
- [ ] Social media preview shows custom image
- [ ] New properties auto-generate images
- [ ] Updated properties regenerate images
- [ ] Job queue stays healthy (<100 depth)

---

## Troubleshooting Quick Guide

| Problem | Cause | Fix |
|---------|-------|-----|
| Jobs not running | Solid Queue worker stopped | `rails solid_queue:restart` |
| Images not showing | ruby-vips not installed | `bundle list \| grep vips` |
| Slow image generation | Too many concurrent jobs | Reduce worker concurrency |
| Storage growing fast | Cleanup not working | Verify `dependent: :purge_later` |
| Old images persisting | Regeneration not triggering | Check callback conditions |

---

## References

**Documentation Files**:
- Full research: `/docs/seo/OG_IMAGE_GENERATION_RESEARCH.md`
- Implementation guide: `/docs/seo/OG_IMAGE_IMPLEMENTATION_GUIDE.md`
- This file: `/docs/seo/OG_IMAGE_QUICK_START.md`

**Related Code**:
- Existing jobs: `/app/jobs/pwb/`
- Image model: `/app/models/pwb/media.rb`
- SEO helper: `/app/helpers/seo_helper.rb`
- Storage config: `/config/storage.yml`

**External Resources**:
- Open Graph Spec: https://ogp.me/
- Twitter Cards: https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/summary-card-with-large-image
- ruby-vips: https://github.com/libvips/ruby-vips
- Solid Queue: https://github.com/rails/solid_queue

---

## Next Steps

1. **Review** this guide with the team
2. **Design** the OG image layout (what to include, colors, fonts)
3. **Create mockups** for approval
4. **Start coding** with Phase 1 (service)
5. **Add tests** incrementally
6. **Deploy** to production
7. **Monitor** and optimize

---

**Status**: Ready to implement  
**Updated**: 2025-12-31  
**Questions?**: See the full research and implementation guides
