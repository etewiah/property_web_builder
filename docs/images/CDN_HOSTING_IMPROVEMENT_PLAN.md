# CDN & Image Hosting Improvement Plan

This document outlines improvements to PropertyWebBuilder's image and asset hosting configuration, addressing naming confusion, bug fixes, and testing requirements.

## Executive Summary

**Current Issues:**
1. **Confusing environment variable naming** - `R2_PUBLIC_URL` vs `ASSET_HOST` unclear
2. **Variant URLs bypass CDN** - `variant_url` method uses Rails redirect URLs instead of direct CDN URLs
3. **No tests for CDN URL generation** - Missing test coverage for image hosting behavior

**Proposed Solution:**
1. Clear naming convention distinguishing **images** (user uploads) from **assets** (static files)
2. Fix `variant_url` to return direct CDN URLs
3. Comprehensive test suite for image hosting

---

## 1. Environment Variable Naming Convention

### Current State (Confusing)

| Variable | Purpose | Confusion |
|----------|---------|-----------|
| `R2_PUBLIC_URL` | CDN URL for **uploaded images** | Name suggests R2-specific, not clear it's for images |
| `ASSET_HOST` | CDN URL for **static assets** (JS/CSS) | Confusing when combined with R2_PUBLIC_URL |
| `R2_BUCKET` | Storage bucket | Unclear if for images, assets, or both |
| `R2_ASSETS_BUCKET` | Assets-only bucket | Better, but inconsistent with R2_BUCKET |

### Proposed Naming Convention

**Prefix Strategy:**
- `CDN_IMAGES_*` - For user-uploaded content (property photos, media library)
- `CDN_ASSETS_*` - For static assets (JS, CSS, fonts, theme images)
- `R2_*` - For R2 API credentials only (not URLs)

### New Environment Variables

```bash
# ============================================
# R2 API CREDENTIALS (authentication only)
# ============================================
R2_ACCOUNT_ID=your_cloudflare_account_id
R2_ACCESS_KEY_ID=your_access_key
R2_SECRET_ACCESS_KEY=your_secret_key

# ============================================
# IMAGE CDN (user-uploaded content)
# ============================================
# Bucket for user uploads (property photos, media library)
CDN_IMAGES_BUCKET=pwb-prod-images

# Public URL for serving images (Cloudflare R2 public URL or custom domain)
CDN_IMAGES_URL=https://cdn-images.propertywebbuilder.com

# Optional: Separate credentials for images bucket
# CDN_IMAGES_ACCESS_KEY_ID=images_access_key
# CDN_IMAGES_SECRET_ACCESS_KEY=images_secret_key

# ============================================
# ASSET CDN (static files: JS, CSS, fonts)
# ============================================
# Bucket for compiled assets
CDN_ASSETS_BUCKET=pwb-prod-assets

# Public URL for serving assets (Rails asset_host)
CDN_ASSETS_URL=https://cdn-assets.propertywebbuilder.com

# Optional: Separate credentials for assets bucket
# CDN_ASSETS_ACCESS_KEY_ID=assets_access_key
# CDN_ASSETS_SECRET_ACCESS_KEY=assets_secret_key

# ============================================
# SEED IMAGES (development/demo data)
# ============================================
# Bucket for seed pack images (separate from production uploads)
CDN_SEED_IMAGES_BUCKET=pwb-seed-assets
CDN_SEED_IMAGES_URL=https://cdn-seed.propertywebbuilder.com
```

### Migration Plan

**Phase 1: Add aliases (backward compatible)**
```ruby
# config/initializers/cdn_aliases.rb
# Support both old and new variable names during transition

# Images CDN
ENV['CDN_IMAGES_URL'] ||= ENV['R2_PUBLIC_URL']
ENV['CDN_IMAGES_BUCKET'] ||= ENV['R2_BUCKET']

# Assets CDN
ENV['CDN_ASSETS_URL'] ||= ENV['ASSET_HOST']
ENV['CDN_ASSETS_BUCKET'] ||= ENV['R2_ASSETS_BUCKET']
```

**Phase 2: Update documentation**
- Update all docs to reference new variable names
- Add deprecation notices for old names

**Phase 3: Remove old aliases (future release)**
- Remove backward compatibility after transition period

---

## 2. Variant URL Bug Fix

### Current Bug

In `app/models/pwb/media.rb:146`:

```ruby
def variant_url(variant_name)
  # ... variant generation ...

  # BUG: This always generates Rails redirect URLs, bypassing CDN
  Rails.application.routes.url_helpers.rails_representation_url(variant, only_path: true)
end
```

**Result:** Images served via `/rails/active_storage/representations/redirect/...` instead of direct CDN URLs.

### Root Cause Analysis

| Helper Method | Result | CDN Used? |
|---------------|--------|-----------|
| `rails_representation_url` | `/rails/active_storage/representations/redirect/...` | No - goes through Rails |
| `rails_blob_url` | `/rails/active_storage/blobs/redirect/...` | No - goes through Rails |
| `variant.processed.url` | Direct storage URL with `public_url` | Yes - direct CDN |
| `blob.url` | Direct storage URL with `public_url` | Yes - direct CDN |

### Fix

```ruby
# app/models/pwb/media.rb

def variant_url(variant_name)
  return url unless image? && file.attached?

  variant = case variant_name.to_sym
            when :thumb, :thumbnail
              file.variant(resize_to_fill: [150, 150])
            when :small
              file.variant(resize_to_limit: [300, 300])
            when :medium
              file.variant(resize_to_limit: [600, 600])
            when :large
              file.variant(resize_to_limit: [1200, 1200])
            else
              file
            end

  # FIX: Use processed variant's direct URL (respects CDN_IMAGES_URL)
  if variant.is_a?(ActiveStorage::Variant) || variant.is_a?(ActiveStorage::VariantWithRecord)
    variant.processed.url
  else
    # For non-variant (original file), use blob URL
    file.url
  end
rescue StandardError => e
  Rails.logger.warn "Failed to generate variant URL for Media##{id}: #{e.message}"
  url
end

# Also update the base `url` method to use direct URLs
def url
  return nil unless file.attached?
  file.url
rescue StandardError
  nil
end
```

### Similar Fixes Needed

**1. ExternalImageSupport concern** (`app/models/concerns/external_image_support.rb`):

```ruby
def thumbnail_url(size: [200, 200])
  if external?
    external_url
  elsif image.attached? && image.variable?
    # FIX: Use direct URL instead of rails_representation_path
    image.variant(resize_to_limit: size).processed.url
  end
end

def active_storage_url(variant_options: nil)
  return nil unless image.attached?

  if variant_options.present? && image.variable?
    # FIX: Use direct URL
    image.variant(variant_options).processed.url
  else
    image.url
  end
end
```

**2. ContentPhoto model** (`app/models/pwb/content_photo.rb`):

```ruby
def optimized_image_url
  return external_url if external?
  return nil unless image.attached?

  if image.variable?
    # FIX: Use direct URL
    image.variant(resize_to_limit: [800, 600]).processed.url
  else
    image.url
  end
end
```

---

## 3. Configuration Updates

### storage.yml

```yaml
# config/storage.yml

cloudflare_r2:
  service: R2
  access_key_id: <%= ENV['R2_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['R2_SECRET_ACCESS_KEY'] %>
  region: auto
  bucket: <%= ENV['CDN_IMAGES_BUCKET'] || ENV['R2_BUCKET'] %>
  endpoint: <%= "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com" %>
  force_path_style: true
  public: true
  # Use new variable name with fallback
  public_url: <%= ENV['CDN_IMAGES_URL'] || ENV['R2_PUBLIC_URL'] %>
```

### production.rb

```ruby
# config/environments/production.rb

# Static assets CDN (JS, CSS, fonts)
# Use new variable name with fallback
config.asset_host = ENV['CDN_ASSETS_URL'] || ENV['ASSET_HOST'] if (ENV['CDN_ASSETS_URL'] || ENV['ASSET_HOST']).present?
```

### assets_cdn.rake

```ruby
# lib/tasks/assets_cdn.rake

# Update to use new variable names with fallbacks
def r2_client
  Aws::S3::Client.new(
    access_key_id: ENV['CDN_ASSETS_ACCESS_KEY_ID'] || ENV['R2_ASSETS_ACCESS_KEY_ID'] || ENV['R2_ACCESS_KEY_ID'],
    secret_access_key: ENV['CDN_ASSETS_SECRET_ACCESS_KEY'] || ENV['R2_ASSETS_SECRET_ACCESS_KEY'] || ENV['R2_SECRET_ACCESS_KEY'],
    endpoint: "https://#{ENV['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
    region: 'auto'
  )
end

def assets_bucket
  ENV['CDN_ASSETS_BUCKET'] || ENV['R2_ASSETS_BUCKET'] || ENV['R2_BUCKET']
end
```

---

## 4. Test Specifications

### Unit Tests

#### R2 Service URL Generation

```ruby
# spec/services/active_storage/service/r2_service_spec.rb

RSpec.describe ActiveStorage::Service::R2Service do
  let(:public_url) { "https://cdn-images.example.com" }
  let(:service) { described_class.new(public_url: public_url, public: true, **r2_config) }

  describe "#url" do
    context "when public_url is configured" do
      it "returns direct CDN URL" do
        url = service.url("abc123", expires_in: 1.hour, filename: "test.jpg", disposition: :inline, content_type: "image/jpeg")
        expect(url).to eq("https://cdn-images.example.com/abc123")
      end

      it "does not include Rails redirect path" do
        url = service.url("abc123", expires_in: 1.hour, filename: "test.jpg", disposition: :inline, content_type: "image/jpeg")
        expect(url).not_to include("/rails/active_storage")
      end
    end

    context "when public_url is not configured" do
      let(:public_url) { nil }

      it "falls back to signed S3 URL" do
        url = service.url("abc123", expires_in: 1.hour, filename: "test.jpg", disposition: :inline, content_type: "image/jpeg")
        expect(url).to include("r2.cloudflarestorage.com")
      end
    end
  end
end
```

#### Media Model Variant URLs

```ruby
# spec/models/pwb/media_spec.rb

RSpec.describe Pwb::Media do
  describe "#variant_url" do
    let(:website) { create(:website) }
    let(:media) { create(:media, :with_image, website: website) }

    before do
      # Configure R2 with public URL
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CDN_IMAGES_URL').and_return('https://cdn-images.test.com')
      allow(ENV).to receive(:[]).with('R2_PUBLIC_URL').and_return('https://cdn-images.test.com')
    end

    context "with CDN configured" do
      it "returns direct CDN URL for :thumb variant" do
        url = media.variant_url(:thumb)
        expect(url).to start_with("https://cdn-images.test.com/")
        expect(url).not_to include("/rails/active_storage")
      end

      it "returns direct CDN URL for :medium variant" do
        url = media.variant_url(:medium)
        expect(url).to start_with("https://cdn-images.test.com/")
      end
    end

    context "without CDN configured" do
      before do
        allow(ENV).to receive(:[]).with('CDN_IMAGES_URL').and_return(nil)
        allow(ENV).to receive(:[]).with('R2_PUBLIC_URL').and_return(nil)
      end

      it "returns storage service URL" do
        url = media.variant_url(:thumb)
        expect(url).to be_present
      end
    end

    context "with non-image file" do
      let(:media) { create(:media, :with_document, website: website) }

      it "returns nil or base URL" do
        url = media.variant_url(:thumb)
        expect(url).to eq(media.url)
      end
    end
  end
end
```

#### External Image Support

```ruby
# spec/models/concerns/external_image_support_spec.rb

RSpec.describe ExternalImageSupport do
  let(:photo_class) do
    Class.new(ApplicationRecord) do
      self.table_name = 'pwb_prop_photos'
      include ExternalImageSupport
      has_one_attached :image
    end
  end

  describe "#thumbnail_url" do
    context "with external URL" do
      let(:photo) { photo_class.new(external_url: "https://external-cdn.com/photo.jpg") }

      it "returns external URL directly" do
        expect(photo.thumbnail_url).to eq("https://external-cdn.com/photo.jpg")
      end
    end

    context "with attached image and CDN configured" do
      let(:photo) { create(:prop_photo, :with_image) }

      before do
        allow(ENV).to receive(:[]).with('CDN_IMAGES_URL').and_return('https://cdn.test.com')
      end

      it "returns direct CDN variant URL" do
        url = photo.thumbnail_url
        expect(url).to start_with("https://cdn.test.com/")
        expect(url).not_to include("/rails/active_storage")
      end
    end
  end
end
```

### Integration Tests

#### Image Display in Views

```ruby
# spec/helpers/pwb/images_helper_spec.rb

RSpec.describe Pwb::ImagesHelper, type: :helper do
  describe "#opt_image_tag" do
    let(:photo) { create(:prop_photo, :with_image) }

    context "with CDN configured" do
      before do
        allow(ENV).to receive(:[]).with('CDN_IMAGES_URL').and_return('https://cdn.test.com')
      end

      it "generates img tag with CDN src" do
        html = helper.opt_image_tag(photo, width: 600)
        expect(html).to include('src="https://cdn.test.com/')
      end

      it "does not use Rails redirect URLs" do
        html = helper.opt_image_tag(photo, width: 600)
        expect(html).not_to include('/rails/active_storage/representations')
      end
    end

    context "with lazy loading" do
      it "includes loading='lazy' by default" do
        html = helper.opt_image_tag(photo)
        expect(html).to include('loading="lazy"')
      end
    end

    context "with eager loading" do
      it "includes loading='eager' and fetchpriority='high'" do
        html = helper.opt_image_tag(photo, eager: true)
        expect(html).to include('loading="eager"')
        expect(html).to include('fetchpriority="high"')
      end
    end
  end
end
```

### E2E Tests (Playwright)

```javascript
// tests/e2e/images/cdn-delivery.spec.js

const { test, expect } = require('@playwright/test');

test.describe('Image CDN Delivery', () => {
  test('property images load from CDN', async ({ page }) => {
    await page.goto('/buy');

    // Wait for property cards to load
    await page.waitForSelector('.property-card img');

    // Check image sources
    const images = await page.locator('.property-card img').all();
    for (const img of images) {
      const src = await img.getAttribute('src');

      // Should be CDN URL, not Rails redirect
      expect(src).not.toContain('/rails/active_storage/representations/redirect');

      // In production, should be CDN domain
      if (process.env.RAILS_ENV === 'production') {
        expect(src).toMatch(/^https:\/\/cdn/);
      }
    }
  });

  test('hero images have eager loading', async ({ page }) => {
    await page.goto('/');

    // Hero image should have eager loading
    const heroImg = page.locator('.hero-section img').first();
    await expect(heroImg).toHaveAttribute('loading', 'eager');
    await expect(heroImg).toHaveAttribute('fetchpriority', 'high');
  });

  test('below-fold images have lazy loading', async ({ page }) => {
    await page.goto('/buy');

    // Property card images should have lazy loading
    const cardImages = page.locator('.property-card img');
    const firstCard = cardImages.nth(3); // Below fold
    await expect(firstCard).toHaveAttribute('loading', 'lazy');
  });

  test('media library thumbnails load from CDN', async ({ page }) => {
    // Login as admin
    await page.goto('/users/sign_in');
    await page.fill('#user_email', 'admin@example.com');
    await page.fill('#user_password', 'password');
    await page.click('button[type="submit"]');

    // Navigate to media library
    await page.goto('/site_admin/media_library');

    // Check thumbnail sources
    const thumbnails = await page.locator('.media-grid img').all();
    for (const thumb of thumbnails) {
      const src = await thumb.getAttribute('src');
      expect(src).not.toContain('/rails/active_storage/representations/redirect');
    }
  });
});
```

### Performance Tests

```ruby
# spec/performance/image_loading_spec.rb

RSpec.describe "Image Loading Performance", type: :request do
  let(:property) { create(:property, :with_photos, photo_count: 5) }

  it "property page loads within acceptable time" do
    start_time = Time.current
    get property_path(property)
    elapsed = Time.current - start_time

    expect(elapsed).to be < 0.5 # 500ms max
    expect(response).to be_successful
  end

  it "does not make multiple storage service calls per image" do
    # Track S3 calls
    s3_calls = []
    allow_any_instance_of(Aws::S3::Client).to receive(:get_object) do |*args|
      s3_calls << args
    end

    get property_path(property)

    # Each image should only make 1 call (variant is cached)
    expect(s3_calls.length).to be <= property.prop_photos.count
  end
end
```

---

## 5. Implementation Timeline

### Week 1: Foundation
- [ ] Create `config/initializers/cdn_aliases.rb` for backward compatibility
- [ ] Update `storage.yml` to use new variable names with fallbacks
- [ ] Update `production.rb` asset_host configuration

### Week 2: Bug Fixes
- [ ] Fix `Media#variant_url` to use `variant.processed.url`
- [ ] Fix `ExternalImageSupport#thumbnail_url`
- [ ] Fix `ContentPhoto#optimized_image_url`
- [ ] Update `assets_cdn.rake` with new variable names

### Week 3: Testing
- [ ] Add R2 service unit tests
- [ ] Add Media model variant URL tests
- [ ] Add ExternalImageSupport concern tests
- [ ] Add images helper tests

### Week 4: E2E & Documentation
- [ ] Add Playwright E2E tests for CDN delivery
- [ ] Update all documentation with new variable names
- [ ] Add deprecation notices for old variable names
- [ ] Update deployment guides

---

## 6. Quick Reference

### Environment Variables Summary

| Variable | Type | Purpose | Example |
|----------|------|---------|---------|
| `R2_ACCOUNT_ID` | Credential | Cloudflare account ID | `abc123def456` |
| `R2_ACCESS_KEY_ID` | Credential | R2 API access key | `72ff48...` |
| `R2_SECRET_ACCESS_KEY` | Credential | R2 API secret key | `secret...` |
| `CDN_IMAGES_URL` | URL | User uploads CDN | `https://cdn-images.example.com` |
| `CDN_IMAGES_BUCKET` | Bucket | User uploads bucket | `pwb-prod-images` |
| `CDN_ASSETS_URL` | URL | Static assets CDN | `https://cdn-assets.example.com` |
| `CDN_ASSETS_BUCKET` | Bucket | Static assets bucket | `pwb-prod-assets` |
| `CDN_SEED_IMAGES_URL` | URL | Seed data images | `https://cdn-seed.example.com` |
| `CDN_SEED_IMAGES_BUCKET` | Bucket | Seed data bucket | `pwb-seed-assets` |

### URL Generation Cheat Sheet

| Use Case | Method | Result |
|----------|--------|--------|
| Original image | `attachment.url` | Direct CDN URL |
| Resized variant | `attachment.variant(...).processed.url` | Direct CDN variant URL |
| Thumbnail (150x150) | `media.variant_url(:thumb)` | Direct CDN variant URL |
| Property photo | `photo.image.url` | Direct CDN URL |
| External image | `photo.external_url` | External URL (no CDN) |

### DO NOT USE (generates redirect URLs)

```ruby
# AVOID - generates Rails redirect URLs
rails_blob_url(attachment)
rails_representation_url(variant)
url_for(attachment)  # in some contexts
```

### USE INSTEAD

```ruby
# CORRECT - generates direct CDN URLs
attachment.url
attachment.variant(...).processed.url
```

---

## 7. Verification Checklist

After implementation, verify:

- [ ] Media library thumbnails load from CDN URL
- [ ] Property photos load from CDN URL
- [ ] Hero images have `loading="eager"` and `fetchpriority="high"`
- [ ] Grid images have `loading="lazy"`
- [ ] No requests to `/rails/active_storage/representations/redirect/`
- [ ] Lighthouse performance score improved
- [ ] All tests pass
- [ ] Old environment variables still work (backward compatibility)
