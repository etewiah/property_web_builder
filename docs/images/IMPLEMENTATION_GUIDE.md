# Mobile-Optimized Images - Implementation Guide

Step-by-step guide for implementing responsive image generation in PropertyWebBuilder.

## Prerequisites

Before starting, ensure you have:

- [ ] Ruby 3.2+ installed
- [ ] libvips 8.9+ (for AVIF support)
- [ ] Sidekiq configured for background jobs
- [ ] ActiveStorage configured with R2 or local storage

### Check libvips Version

```bash
vips --version
# Should be 8.9 or higher for AVIF support
```

### Check Image Processing Gem

```bash
bundle show image_processing
# Should show 1.14.0 or higher
```

---

## Phase 1: Core Infrastructure

### Step 1.1: Create ResponsiveVariants Module

```bash
mkdir -p lib/pwb
touch lib/pwb/responsive_variants.rb
```

```ruby
# lib/pwb/responsive_variants.rb

module Pwb
  module ResponsiveVariants
    WIDTHS = [320, 640, 768, 1024, 1280, 1536, 1920].freeze

    FORMATS = {
      webp: { format: :webp, saver: { quality: 80 } },
      jpeg: { format: :jpeg, saver: { quality: 85, progressive: true } }
    }.freeze

    SIZE_PRESETS = {
      hero: "(min-width: 1280px) 1280px, 100vw",
      card: "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw",
      thumbnail: "(min-width: 768px) 200px, 150px",
      content: "(min-width: 848px) 800px, calc(100vw - 48px)"
    }.freeze

    class << self
      def widths_for(original_width)
        WIDTHS.select { |w| w <= (original_width || 9999) }
      end

      def formats_to_generate
        formats = [:webp, :jpeg]
        formats.unshift(:avif) if avif_supported?
        formats
      end

      def avif_supported?
        return @avif_supported if defined?(@avif_supported)
        @avif_supported = defined?(Vips) && Vips.at_least_libvips?(8, 9)
      end

      def sizes_for(preset)
        SIZE_PRESETS[preset.to_sym] || SIZE_PRESETS[:card]
      end

      def transformations_for(width, format)
        base = { resize_to_limit: [width, nil] }
        format_config = FORMATS[format] || FORMATS[:jpeg]
        base.merge(format_config)
      end
    end
  end
end
```

### Step 1.2: Create Variant Generator Service

```bash
touch app/services/pwb/responsive_variant_generator.rb
```

```ruby
# app/services/pwb/responsive_variant_generator.rb

module Pwb
  class ResponsiveVariantGenerator
    attr_reader :attachment, :errors

    def initialize(attachment)
      @attachment = attachment
      @errors = []
    end

    def generate_all!
      return false unless valid?

      widths_to_generate.each do |width|
        formats_to_generate.each do |format|
          generate_variant(width, format)
        end
      end

      errors.empty?
    end

    def generate_variant(width, format)
      transformations = ResponsiveVariants.transformations_for(width, format)
      attachment.variant(transformations).processed

      Rails.logger.info(
        "Generated variant: #{width}w #{format} for #{attachment.blob.filename}"
      )
    rescue StandardError => e
      errors << { width: width, format: format, error: e.message }
      Rails.logger.error(
        "Variant generation failed: #{width}w #{format} - #{e.message}"
      )
    end

    private

    def valid?
      unless attachment.attached?
        errors << { error: "No attachment present" }
        return false
      end

      if external_image?
        errors << { error: "External images cannot generate variants" }
        return false
      end

      true
    end

    def external_image?
      record = attachment.record
      record.respond_to?(:external_url) && record.external_url.present?
    end

    def widths_to_generate
      ResponsiveVariants.widths_for(original_width)
    end

    def formats_to_generate
      ResponsiveVariants.formats_to_generate
    end

    def original_width
      attachment.blob.metadata[:width]
    end
  end
end
```

### Step 1.3: Create Background Job

```bash
touch app/jobs/image_variant_generator_job.rb
```

```ruby
# app/jobs/image_variant_generator_job.rb

class ImageVariantGeneratorJob < ApplicationJob
  queue_as :images

  # Retry with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry if attachment was deleted
  discard_on ActiveRecord::RecordNotFound

  def perform(model_class, model_id)
    record = model_class.constantize.find(model_id)

    # Determine the attachment field
    attachment = case record
                 when Pwb::PropPhoto, Pwb::ContentPhoto, Pwb::WebsitePhoto
                   record.image
                 when Pwb::Media
                   record.file
                 else
                   raise "Unknown model type: #{model_class}"
                 end

    return unless attachment.attached?

    generator = Pwb::ResponsiveVariantGenerator.new(attachment)

    unless generator.generate_all!
      Rails.logger.warn(
        "Variant generation had errors for #{model_class}##{model_id}: " \
        "#{generator.errors.inspect}"
      )
    end
  end
end
```

### Step 1.4: Add Autoload Path

```ruby
# config/application.rb

module PropertyWebBuilder
  class Application < Rails::Application
    # ... existing config ...

    # Add lib to autoload paths
    config.autoload_paths << Rails.root.join('lib')
  end
end
```

---

## Phase 2: Helper Methods

### Step 2.1: Create Responsive Images Helper

```bash
touch app/helpers/pwb/responsive_images_helper.rb
```

```ruby
# app/helpers/pwb/responsive_images_helper.rb

module Pwb
  module ResponsiveImagesHelper
    # Generate a responsive image with srcset and modern formats
    #
    # @param photo [PropPhoto, ContentPhoto, etc.] Photo model with image attachment
    # @param sizes [String, Symbol] CSS sizes attribute or preset name (:hero, :card, etc.)
    # @param options [Hash] Additional options
    # @option options [Boolean] :eager (false) Load eagerly for above-fold images
    # @option options [String] :alt Alt text for accessibility
    # @option options [String] :class CSS classes
    # @option options [Boolean] :avif (true) Include AVIF sources
    # @option options [String] :fallback_url URL for placeholder if no image
    #
    # @return [ActiveSupport::SafeBuffer] HTML picture element
    #
    # @example Basic usage
    #   <%= responsive_image_tag @property.primary_photo, sizes: :card %>
    #
    # @example Hero image (above fold)
    #   <%= responsive_image_tag @property.primary_photo, sizes: :hero, eager: true %>
    #
    # @example With custom sizes
    #   <%= responsive_image_tag @photo, sizes: "(min-width: 800px) 400px, 100vw" %>
    #
    def responsive_image_tag(photo, sizes: :card, **options)
      # Handle nil/missing photo
      return placeholder_image_tag(options) if photo.blank?

      # Handle external URLs (no srcset possible)
      if external_url?(photo)
        return external_responsive_image_tag(photo, options)
      end

      # Handle missing attachment
      attachment = photo_attachment(photo)
      return placeholder_image_tag(options) unless attachment&.attached?

      # Build the picture element
      build_picture_element(attachment, sizes, options)
    end

    private

    def build_picture_element(attachment, sizes, options)
      sizes_value = resolve_sizes(sizes)
      include_avif = options.fetch(:avif, true) && ResponsiveVariants.avif_supported?

      content_tag(:picture, class: options[:picture_class]) do
        sources = []

        # AVIF source (best compression, newest browsers)
        if include_avif
          sources << build_source_tag(attachment, :avif, sizes_value)
        end

        # WebP source (good compression, wide support)
        sources << build_source_tag(attachment, :webp, sizes_value)

        # Fallback img with JPEG srcset
        sources << build_img_tag(attachment, sizes_value, options)

        safe_join(sources)
      end
    end

    def build_source_tag(attachment, format, sizes)
      srcset = build_srcset(attachment, format)
      mime_type = format == :avif ? 'image/avif' : 'image/webp'

      tag.source(
        srcset: srcset,
        sizes: sizes,
        type: mime_type
      )
    end

    def build_img_tag(attachment, sizes, options)
      srcset = build_srcset(attachment, :jpeg)
      default_url = attachment.url # Original as ultimate fallback

      tag.img(
        src: default_url,
        srcset: srcset,
        sizes: sizes,
        alt: options[:alt] || '',
        class: options[:class],
        loading: options[:eager] ? 'eager' : 'lazy',
        decoding: 'async',
        fetchpriority: options[:eager] ? 'high' : nil,
        width: options[:width],
        height: options[:height]
      )
    end

    def build_srcset(attachment, format)
      original_width = attachment.blob.metadata[:width] || 9999
      widths = ResponsiveVariants.widths_for(original_width)

      widths.map do |width|
        url = variant_url(attachment, width, format)
        "#{url} #{width}w"
      end.join(', ')
    end

    def variant_url(attachment, width, format)
      transformations = ResponsiveVariants.transformations_for(width, format)
      attachment.variant(transformations).url
    rescue StandardError => e
      Rails.logger.warn("Variant URL failed: #{e.message}")
      attachment.url # Fallback to original
    end

    def resolve_sizes(sizes)
      return sizes if sizes.is_a?(String)
      ResponsiveVariants.sizes_for(sizes)
    end

    def external_url?(photo)
      photo.respond_to?(:external_url) && photo.external_url.present?
    end

    def photo_attachment(photo)
      case photo
      when Pwb::PropPhoto, Pwb::ContentPhoto, Pwb::WebsitePhoto
        photo.image
      when Pwb::Media
        photo.file
      else
        photo.try(:image) || photo.try(:file)
      end
    end

    def external_responsive_image_tag(photo, options)
      tag.img(
        src: photo.external_url,
        alt: options[:alt] || '',
        class: options[:class],
        loading: options[:eager] ? 'eager' : 'lazy',
        decoding: 'async'
      )
    end

    def placeholder_image_tag(options)
      placeholder_url = options[:fallback_url] || asset_path('placeholder.jpg')

      tag.img(
        src: placeholder_url,
        alt: options[:alt] || 'Image not available',
        class: options[:class],
        loading: 'lazy'
      )
    end
  end
end
```

### Step 2.2: Include Helper in Application

```ruby
# app/helpers/application_helper.rb

module ApplicationHelper
  include Pwb::ResponsiveImagesHelper

  # ... existing helpers ...
end
```

---

## Phase 3: Model Integration

### Step 3.1: Add Callback to PropPhoto

```ruby
# app/models/pwb/prop_photo.rb

module Pwb
  class PropPhoto < ApplicationRecord
    # ... existing code ...

    has_one_attached :image

    # Trigger variant generation after image is attached
    after_commit :schedule_variant_generation, on: :create

    private

    def schedule_variant_generation
      return unless image.attached?
      return if external_url.present?  # Skip external images

      ImageVariantGeneratorJob.perform_later(self.class.name, id)
    end
  end
end
```

### Step 3.2: Add to Other Photo Models

Apply the same callback pattern to:

- `Pwb::ContentPhoto`
- `Pwb::WebsitePhoto`
- `Pwb::Media`

```ruby
# app/models/pwb/content_photo.rb

module Pwb
  class ContentPhoto < ApplicationRecord
    has_one_attached :image

    after_commit :schedule_variant_generation, on: :create

    private

    def schedule_variant_generation
      return unless image.attached?
      ImageVariantGeneratorJob.perform_later(self.class.name, id)
    end
  end
end
```

---

## Phase 4: Update Views

### Step 4.1: Property Card Partial

```erb
<%# app/views/pwb/properties/_property_card.html.erb %>

<div class="property-card">
  <div class="property-card__image">
    <%= responsive_image_tag(
      property.primary_photo,
      sizes: :card,
      alt: property.title,
      class: "w-full h-48 object-cover rounded-t-lg"
    ) %>
  </div>

  <div class="property-card__content">
    <h3><%= property.title %></h3>
    <p class="price"><%= property.formatted_price %></p>
  </div>
</div>
```

### Step 4.2: Property Detail Hero

```erb
<%# app/views/pwb/properties/show.html.erb %>

<div class="property-hero">
  <%= responsive_image_tag(
    @property.primary_photo,
    sizes: :hero,
    eager: true,  # Above the fold
    alt: @property.title,
    class: "w-full h-96 object-cover"
  ) %>
</div>
```

### Step 4.3: Property Gallery

```erb
<%# app/views/pwb/properties/_gallery.html.erb %>

<div class="property-gallery grid grid-cols-2 md:grid-cols-3 gap-4">
  <% property.prop_photos.each do |photo| %>
    <div class="gallery-item">
      <%= responsive_image_tag(
        photo,
        sizes: :card,
        alt: "#{property.title} - Photo",
        class: "w-full h-40 object-cover rounded cursor-pointer"
      ) %>
    </div>
  <% end %>
</div>
```

---

## Phase 5: Background Job Configuration

### Step 5.1: Configure Sidekiq Queue

```yaml
# config/sidekiq.yml

:concurrency: 5

:queues:
  - [critical, 5]
  - [default, 3]
  - [images, 2]
  - [mailers, 1]
```

### Step 5.2: Add Job Timeout

```ruby
# app/jobs/image_variant_generator_job.rb

class ImageVariantGeneratorJob < ApplicationJob
  queue_as :images

  # Limit execution time (variants can be slow for large images)
  sidekiq_options timeout: 120  # 2 minutes max

  # ... rest of job ...
end
```

---

## Phase 6: Backfill Existing Images

### Step 6.1: Create Rake Task

```ruby
# lib/tasks/images.rake

namespace :images do
  desc "Generate responsive variants for all existing property photos"
  task generate_variants: :environment do
    puts "Starting variant generation for PropPhoto..."

    total = Pwb::PropPhoto.count
    processed = 0
    skipped = 0

    Pwb::PropPhoto.find_each do |photo|
      if photo.image.attached? && photo.external_url.blank?
        ImageVariantGeneratorJob.perform_later('Pwb::PropPhoto', photo.id)
        processed += 1
      else
        skipped += 1
      end

      print "\rProcessed: #{processed + skipped}/#{total} (#{skipped} skipped)"
    end

    puts "\nEnqueued #{processed} jobs for variant generation."
    puts "Skipped #{skipped} photos (no attachment or external URL)."
  end

  desc "Generate variants for a single photo"
  task :generate_single, [:model, :id] => :environment do |_t, args|
    model = args[:model].constantize
    record = model.find(args[:id])

    attachment = record.image rescue record.file

    generator = Pwb::ResponsiveVariantGenerator.new(attachment)
    if generator.generate_all!
      puts "Successfully generated all variants"
    else
      puts "Errors: #{generator.errors.inspect}"
    end
  end
end
```

### Step 6.2: Run Backfill

```bash
# Enqueue all jobs (runs in background)
bundle exec rake images:generate_variants

# Monitor progress
bundle exec sidekiq

# Or run synchronously for testing
INLINE_JOBS=true bundle exec rake images:generate_variants
```

---

## Phase 7: Testing

### Step 7.1: Unit Tests for Generator

```ruby
# spec/services/pwb/responsive_variant_generator_spec.rb

require 'rails_helper'

RSpec.describe Pwb::ResponsiveVariantGenerator do
  let(:photo) { create(:pwb_prop_photo, :with_image) }
  let(:generator) { described_class.new(photo.image) }

  describe '#generate_all!' do
    it 'generates variants for all widths and formats' do
      expect { generator.generate_all! }.not_to raise_error
      expect(generator.errors).to be_empty
    end

    it 'skips widths larger than original' do
      # Create small image (e.g., 400px wide)
      small_photo = create(:pwb_prop_photo, :with_small_image)
      gen = described_class.new(small_photo.image)

      gen.generate_all!

      # Should not have tried to generate 1920px variant
      expect(gen.errors).to be_empty
    end
  end

  describe '#generate_variant' do
    it 'creates variant with correct transformations' do
      generator.generate_variant(640, :webp)

      variant = photo.image.variant(
        resize_to_limit: [640, nil],
        format: :webp,
        saver: { quality: 80 }
      )

      expect(variant).to be_present
    end
  end
end
```

### Step 7.2: Helper Tests

```ruby
# spec/helpers/pwb/responsive_images_helper_spec.rb

require 'rails_helper'

RSpec.describe Pwb::ResponsiveImagesHelper, type: :helper do
  describe '#responsive_image_tag' do
    let(:photo) { create(:pwb_prop_photo, :with_image) }

    it 'returns a picture element' do
      result = helper.responsive_image_tag(photo)

      expect(result).to have_css('picture')
      expect(result).to have_css('picture > source[type="image/webp"]')
      expect(result).to have_css('picture > img[loading="lazy"]')
    end

    it 'includes srcset attribute' do
      result = helper.responsive_image_tag(photo)

      expect(result).to have_css('img[srcset]')
    end

    it 'uses eager loading when specified' do
      result = helper.responsive_image_tag(photo, eager: true)

      expect(result).to have_css('img[loading="eager"]')
      expect(result).to have_css('img[fetchpriority="high"]')
    end

    it 'returns placeholder for nil photo' do
      result = helper.responsive_image_tag(nil)

      expect(result).to have_css('img[src*="placeholder"]')
    end
  end
end
```

---

## Verification Checklist

After implementation, verify:

- [ ] Variants generate on new image upload
- [ ] srcset contains all expected widths
- [ ] WebP sources appear in picture element
- [ ] Lazy loading works (check Network tab)
- [ ] Eager loading works for hero images
- [ ] External images still display correctly
- [ ] Placeholder shows for missing images
- [ ] Background job processes without errors
- [ ] Storage usage is within expectations

---

## Troubleshooting

### Variants Not Generating

```ruby
# Check job queue
Sidekiq::Queue.new('images').size

# Check for failed jobs
Sidekiq::DeadSet.new.size

# Manually trigger for debugging
photo = Pwb::PropPhoto.find(123)
generator = Pwb::ResponsiveVariantGenerator.new(photo.image)
generator.generate_all!
puts generator.errors
```

### AVIF Not Working

```ruby
# Check libvips version
puts `vips --version`

# Check Ruby binding
puts Vips.at_least_libvips?(8, 9)

# AVIF requires libvips 8.9+ compiled with AVIF support
# On macOS: brew install vips
# On Ubuntu: apt install libvips-dev
```

### Memory Issues

```ruby
# Reduce concurrency for large images
# config/sidekiq.yml
:concurrency: 2

# Or process synchronously for testing
Sidekiq::Testing.inline! do
  ImageVariantGeneratorJob.perform_now('Pwb::PropPhoto', photo.id)
end
```
