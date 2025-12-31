# OG Image Generation in Rails - Research Report

## Executive Summary

PropertyWebBuilder currently uses **static OG images** for social media sharing. This document research how **dynamic OG image generation** could be implemented in Rails applications, including:

1. Existing gems and approaches
2. PropertyWebBuilder's current image processing infrastructure
3. Background job capabilities
4. Implementation approaches and their trade-offs

## Current State of PropertyWebBuilder

### Existing Image Processing Infrastructure

PropertyWebBuilder has **solid image processing capabilities already in place**:

#### 1. Image Processing Gem (Already Installed)
- **Gem**: `image_processing ~> 1.2` (Gemfile:14)
- **Dependencies**: 
  - `ruby-vips 2.3.0` (installed)
  - `mini_magick 5.3.1` (installed as fallback)
- **Status**: Full featured, handles resizing, cropping, format conversion
- **Current Use**: 
  - ActiveStorage blob analysis (dimension extraction)
  - Variant processing for Media model (thumbnails, responsive sizes)
  - See: `/app/models/pwb/media.rb` (lines 147-170)

#### 2. ActiveStorage Integration
- **Status**: Fully configured for production
- **Storage Backends**:
  - Development: Local disk storage
  - Production: Cloudflare R2 (S3-compatible)
  - Configuration: `/config/storage.yml`
- **Current Use**:
  - PropPhoto model (property images)
  - ContentPhoto model (content images)
  - WebsitePhoto model (website images)
  - Media model (media library files)

#### 3. Image Variants Configuration
The Media model supports pre-configured variants:
```ruby
# Available image variants (Media#variant_url)
:thumb/:thumbnail  => 150x150 (fill)
:small             => 300x300 (limit)
:medium            => 600x600 (limit)
:large             => 1200x1200 (limit)
```

### Background Job Infrastructure

PropertyWebBuilder has **excellent background job support** via Solid Queue:

#### 1. Solid Queue (Rails 8 Native)
- **Status**: Fully configured in production
- **Configuration**: 
  - Gem: `solid_queue ~> 1.0` (Gemfile:233)
  - Dashboard: `mission_control-jobs ~> 1.0` (Gemfile:234)
  - Auth: Basic HTTP auth (configured in `/config/initializers/mission_control_jobs.rb`)
  - Database: Uses `db/queue_schema.rb` for dedicated queue tables
- **Job Queue Adapter**: Already set in production.rb:
  ```ruby
  config.active_job.queue_adapter = :solid_queue
  ```
- **Mailer Integration**: Email delivery already uses async jobs
  ```ruby
  config.action_mailer.deliver_later_queue_name = :mailers
  ```

#### 2. Existing Jobs Pattern
PropertyWebBuilder already has working background jobs:

**Exchange Rate Job** (`/app/jobs/pwb/update_exchange_rates_job.rb`):
```ruby
class UpdateExchangeRatesJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(website_id: nil)
    # ... implementation
  end
end
```

**Cleanup Job** (`/app/jobs/cleanup_orphaned_blobs_job.rb`):
- Automated ActiveStorage cleanup

**View Refresh Job** (`/app/jobs/refresh_properties_view_job.rb`):
- Database materialized view updates

#### 3. Base Classes
- `/app/jobs/application_job.rb` - Root application job
- `/app/jobs/pwb/application_job.rb` - Pwb-namespaced jobs (inherits from root)
- Support for multi-tenancy: `/app/jobs/concerns/tenant_aware_job.rb`

#### 4. Job Capabilities
- ✅ Retry with exponential backoff
- ✅ Error handling and reporting
- ✅ Multi-tenancy support (via ActsAsTenant context)
- ✅ Async execution
- ✅ Job monitoring via Mission Control Jobs dashboard

## OG Image Generation Approaches in Rails

### Approach 1: Server-Side HTML-to-Image Rendering (Most Common)

#### Tools Available
1. **Grover** - Most popular Rails gem for Puppeteer-based HTML-to-image
   - Requires: Node.js + Puppeteer
   - Pros: HTML/CSS rendering, high quality
   - Cons: Heavy dependencies, slower, memory intensive

2. **IMGKit** - Wkhtmltoimage wrapper (legacy)
   - Requires: wkhtmltoimage binary
   - Pros: Good performance, simpler
   - Cons: Legacy, less maintenance

3. **Puppeteer/Playwright direct usage** - Browser automation
   - Already installed in PropertyWebBuilder for E2E testing!
   - Pros: Most flexible, best rendering quality
   - Cons: Requires Node.js, browser process overhead

4. **htmltoimage gem** - Python-based
   - Requires: Python 3.8+, external service
   - Pros: Lightweight
   - Cons: Requires additional environment

#### Current Status in PropertyWebBuilder
- **Playwright** is already installed for E2E tests
- Could be reused for OG image generation
- See: `/tests/e2e/` and `playwright.config.js`

### Approach 2: ImageMagick/Vips Direct Image Generation

#### Tools Available
1. **ruby-vips** (Already Installed)
   - Direct image manipulation, no rendering engine
   - Pros: Very fast, low memory, lightweight
   - Cons: Limited to image primitives (no HTML/CSS rendering)

2. **mini_magick** (Already Installed)
   - ImageMagick wrapper, similar to Vips but older
   - Pros: Flexible, lots of examples
   - Cons: Slower than Vips, requires ImageMagick binary

#### Current Status
Both are already installed and configured. Use cases:
- Overlay text on existing images
- Resize/crop property photos
- Add property data (price, location) as text
- Create simple branded templates

### Approach 3: Template-Based Generation with Pre-Rendered Assets

#### Concept
- Generate OG images using HTML templates rendered as static images
- Store generated images in ActiveStorage
- Cache with invalidation on property/website updates

#### Tools
- Ruby-VIPs/ImageMagick for compositing
- ERB templates for image layouts
- Scheduled image regeneration

#### Pros
- Very fast (pre-generated, cached)
- Reliable (no rendering engine needed)
- Cost-effective

#### Cons
- More complex setup
- Less flexible

### Approach 4: Serverless/Third-Party Service

#### Tools
1. **Vercel OG Image Generation** - Hosted service
2. **Cloudinary** - CDN + image manipulation
3. **Custom serverless function** - AWS Lambda, Google Cloud Functions

#### Pros
- No server overhead
- Professional quality
- Outsourced complexity

#### Cons
- Cost per generation
- External dependency
- May not fit PropertyWebBuilder's self-hosted model

## OG Image Generation Patterns in Rails

### Pattern 1: Generate on Demand (Request Time)

```ruby
# In controller
def show
  @property = Property.find(params[:id])
  og_image_url = OgImageService.generate_and_cache(@property)
end
```

**Pros**: Simple, no job infrastructure needed
**Cons**: Slow response times, potential timeouts, heavy CPU usage

### Pattern 2: Generate in Background Job (Async, Eager)

```ruby
# In model callback
after_update :regenerate_og_image

def regenerate_og_image
  GenerateOgImageJob.perform_later(self)
end

# In job
class GenerateOgImageJob < ApplicationJob
  def perform(property)
    image_url = OgImageService.generate(property)
    property.update(og_image_url: image_url)
  end
end
```

**Pros**: Non-blocking, better UX, cacheable
**Cons**: Storage overhead, stale images possible, database updates

### Pattern 3: Generate on Demand with Caching (Lazy Evaluation)

```ruby
# In service
class OgImageService
  def self.url_for(property)
    # Check if cached image exists
    return cached_url if cached_image_exists?(property)
    
    # Generate synchronously but cache result
    image_blob = generate_image(property)
    store_in_active_storage(property, image_blob)
    return url
  end
end
```

**Pros**: Balances performance and resource usage
**Cons**: First request slower, cache invalidation complexity

### Pattern 4: Pre-render and Cache (Scheduled)

```ruby
# In recurring job (Solid Queue config)
# Run daily at 2 AM
class RegenerateOgImagesJob < ApplicationJob
  def perform
    Pwb::Prop.find_each { |prop| generate_og_image(prop) }
  end
end
```

**Pros**: All images pre-generated, instant on request, predictable load
**Cons**: Storage overhead, stale on new properties, complex scheduling

## Recommended Approach for PropertyWebBuilder

### Hybrid Approach: On-Demand with Background Job Cache

Given PropertyWebBuilder's constraints and infrastructure:

#### 1. Technology Stack
- **Image Generation**: Ruby-VIPs (already installed) + ERB templates
- **Background Jobs**: Solid Queue (already configured)
- **Storage**: ActiveStorage with Cloudflare R2
- **Rendering**: Simple text-on-image overlays (not full HTML rendering)

#### 2. Architecture

```
Request Flow:
    Property Page Request
         ↓
    Check if OG image cached
         ↓
    If cached → Use cached URL
    If not cached → Queue generation job + Return placeholder
         ↓
    GenerateOgImageJob
         ↓
    Render image (Vips + text overlay)
         ↓
    Store in ActiveStorage
         ↓
    Update property og_image_url
```

#### 3. Data Model Changes
```ruby
# Add to Property model
has_one_attached :og_image, dependent: :purge_later
# Also add column for URL caching (for quick access)
t.string :og_image_url
```

#### 4. Service Layer
```ruby
# app/services/pwb/og_image_generator.rb
class OgImageGeneratorService
  def self.generate(property)
    # 1. Get base image (property photo or default)
    # 2. Draw text overlays (price, location, beds/baths)
    # 3. Apply website branding (logo, colors)
    # 4. Return VIPs image blob
  end
end

# app/jobs/pwb/generate_og_image_job.rb
class GenerateOgImageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  
  def perform(property_id)
    property = Pwb::Prop.find(property_id)
    image_blob = OgImageGeneratorService.generate(property)
    property.og_image.attach(image_blob)
    property.update(og_image_url: url)
  end
end
```

#### 5. Controller Integration
```ruby
# In PropsController
def show
  @property = Prop.find(params[:id])
  set_property_seo(@property, :for_sale)
  
  # Queue OG image generation if not cached
  GenerateOgImageJob.perform_later(@property.id) unless @property.og_image.attached?
end
```

### Pros of This Approach
- ✅ Uses existing infrastructure (Vips, Solid Queue, ActiveStorage)
- ✅ Non-blocking (async generation)
- ✅ Cacheable and reusable
- ✅ Scalable (background jobs handle load)
- ✅ Cost-effective (no third-party services)
- ✅ Customizable (full control of design)

### Cons of This Approach
- ✅ First request gets placeholder (acceptable, cached after)
- ✅ Storage overhead (1-2 KB images per property)
- ✅ Cache invalidation needed on property updates

## Alternative: Lightweight Approach (Minimal Changes)

If database/storage overhead is a concern:

### Generate URL on Demand (No Storage)
```ruby
# In helper
def og_image_url_for(property)
  # Instead of storing, generate URL dynamically
  # /api/og-images/properties/#{property.id}.png
end

# In controller
def og_image
  @property = Prop.find(params[:property_id])
  image = OgImageGeneratorService.generate(@property)
  send_data image, type: 'image/png', disposition: 'inline'
end
```

**Pros**: No storage overhead
**Cons**: Slower response, every request regenerates (unless cached by CDN)

## Implementation Considerations

### 1. Image Specifications
OG images should be:
- **Size**: 1200×630 pixels (recommended by Facebook/Twitter)
- **Aspect Ratio**: 1.91:1
- **Format**: PNG or JPEG
- **Max Size**: 5 MB (Twitter), 8 MB (Facebook)

### 2. Content to Include
For property listings:
- Property photo (base image)
- Price (prominent)
- Address/Location
- Bedrooms, Bathrooms, Square Footage
- Website logo/branding
- Website colors (theme)

### 3. Text Rendering
Using ruby-vips or ImageMagick with text overlays:
```ruby
image = Vips::Image.new_from_file('property.jpg')
            .crop(x, y, width, height)
            .text('$500,000', options)
            .text('3 bed, 2 bath', options)
```

Alternatively, use **Prawn** (PDF generation) as image source.

### 4. Caching Strategy
- Store generated image URL in property record
- Invalidate on: property update, photo change, price change
- Regenerate on demand if missing

### 5. Testing
```ruby
# spec/jobs/pwb/generate_og_image_job_spec.rb
describe Pwb::GenerateOgImageJob do
  it 'generates OG image for property'
  it 'attaches image to property'
  it 'retries on transient failures'
  it 'handles image generation errors gracefully'
end

# spec/services/pwb/og_image_generator_service_spec.rb
describe OgImageGeneratorService do
  it 'returns image blob'
  it 'includes property details'
  it 'applies website branding'
  it 'respects theme colors'
end
```

## Multi-Tenancy Considerations

PropertyWebBuilder is multi-tenant. OG image generation must:

1. **Scope images per website** (tenant)
   - Each website has unique branding/colors
   - Store og_image per property with website context

2. **Use ActsAsTenant**
   ```ruby
   class GenerateOgImageJob < ApplicationJob
     include TenantAwareJob
     
     def perform(property_id, website_id: nil)
       Pwb::Current.website = Pwb::Website.find(website_id)
       # ... generation
     end
   end
   ```

3. **Separate image storage**
   - Images per property/website combination
   - Efficient querying with proper indexes

## Performance Implications

### CPU/Memory Impact
- Image generation: ~100-500ms per image (Vips is very efficient)
- Memory: ~50-100MB per concurrent job (minimal with Vips)
- Disk/Storage: ~1-2KB per generated image

### Database Impact
- 2 new columns: `og_image_url`, `og_image_regenerated_at`
- New ActiveStorage blobs: 1 per property
- Minimal query impact

### CDN Impact
- Serves cached images (static, immutable URLs)
- Cache headers: 1 year (same as property photos)
- No impact on origin server after generation

## Deployment/Infrastructure Requirements

### System Dependencies
Already installed:
- ✅ Ruby-VIPs (for image processing)
- ✅ Solid Queue (for background jobs)
- ✅ ActiveStorage (for file storage)
- ✅ PostgreSQL (for queue tables)

Optional additions:
- ❓ ImageMagick binary (if using MiniMagick instead of Vips)
- ❓ Fonts library (for text rendering, usually pre-installed)

### Environment Variables
None required (uses existing configurations)

### Monitoring/Alerting
- Monitor job queue via Mission Control Jobs dashboard
- Alert on high failure rates
- Track image generation time (prometheus metrics)

## Gem Candidates (If Additional Features Needed)

### Text Rendering on Images
- **ruby-vips** (already installed) - Native support, most efficient
- **ChunkyPNG** - Pure Ruby, slower but no dependencies
- **ImageMagick** (mini_magick) - Slower but more flexible

### HTML-to-Image (If needed for complex layouts)
- **Grover** - Puppeteer wrapper (requires Node.js)
- **HTMLToImage** - External service wrapper

### Ready-Made OG Image Gems
- **og-image** - Limited, not maintained
- **meta-tags** - Meta tag generation only, not image generation

## References & Resources

### Rails Image Processing
- ActiveStorage Variants: https://guides.rubyonrails.org/active_storage_overview.html#transforming-images-and-generating-image-variants
- image_processing gem: https://github.com/janko/image_processing

### Background Jobs
- Solid Queue: https://github.com/rails/solid_queue
- Mission Control Jobs: https://github.com/rails/mission_control-jobs

### Image Generation Libraries
- ruby-vips: https://github.com/libvips/ruby-vips
- Prawn (PDF/Image): https://github.com/prawnpdf/prawn

### OG Image Best Practices
- Open Graph Protocol: https://ogp.me/
- Twitter Card Summary: https://developer.twitter.com/en/docs/twitter-for-websites/cards/overview/summary-card
- Facebook OG Image Guide: https://developers.facebook.com/docs/sharing/webmasters/images/

## Next Steps

To implement dynamic OG image generation:

1. **Design Phase**
   - Define OG image layout/design
   - Choose text and styling
   - Approve mockups

2. **Implementation**
   - Create service class (`Pwb::OgImageGeneratorService`)
   - Create background job (`Pwb::GenerateOgImageJob`)
   - Add model changes (og_image attachment)
   - Integration into PropsController

3. **Testing**
   - Unit tests for service
   - Integration tests for job
   - E2E tests for property page rendering

4. **Deployment**
   - Migrate database (add columns/attachments)
   - Deploy code
   - Monitor job queue
   - Batch generate for existing properties (rake task)

5. **Optimization**
   - CDN caching strategy
   - Background job tuning
   - Performance monitoring

## Summary Table

| Aspect | Current State | Capability | Impact |
|--------|--------------|-----------|--------|
| **Image Processing** | Ruby-VIPs + Mini-Magick installed | Can generate images | Low |
| **Background Jobs** | Solid Queue configured | Can queue generation | Low |
| **Storage** | ActiveStorage + R2 | Can store generated images | Low-Medium |
| **Database** | PostgreSQL | Queue tables ready | None |
| **Scalability** | Production-ready | Can handle 1000s of jobs | Good |
| **Multi-Tenancy** | ActsAsTenant configured | Per-website branding possible | None |
| **Monitoring** | Mission Control Jobs | Job visibility | None |
| **Cost** | Self-hosted | No per-image fees | Minimal |

---

**Document Status**: Research Complete  
**Last Updated**: 2025-12-31  
**Prepared For**: PropertyWebBuilder OG Image Generation Feature
