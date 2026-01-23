# Image URL Generation

This document explains the correct pattern for generating image URLs in PropertyWebBuilder.

## Overview

PropertyWebBuilder uses ActiveStorage for file uploads with optional CDN integration (Cloudflare R2). All image URL generation should use the direct URL methods provided by ActiveStorage, which respect the configured CDN settings.

## Correct Pattern

### For Original Images

```ruby
# Correct: Use image.url directly
image.url
```

### For Image Variants

```ruby
# Correct: Process variant and call .url
image.variant(resize_to_limit: [600, 400]).processed.url
```

## Why NOT to Use rails_blob_url/rails_representation_url

The `rails_blob_url` and `rails_representation_url` helpers require a static host parameter:

```ruby
# WRONG: This bypasses CDN configuration
Rails.application.routes.url_helpers.rails_blob_url(
  image,
  host: ENV['ASSET_HOST'] || 'http://localhost:3000'
)
```

Problems with this approach:

1. **Bypasses R2Service CDN configuration** - The CDN_IMAGES_URL and R2_PUBLIC_URL environment variables are ignored
2. **Inconsistent URLs** - Different code paths generate different URLs for the same image
3. **Static host fallback** - Falls back to localhost:3000 instead of the configured CDN

## How ActiveStorage's .url Method Works

When you call `image.url`, ActiveStorage:

1. Checks the configured storage service (local, S3, R2, etc.)
2. Uses the service's `url` method which respects configured public URLs
3. For R2, uses the R2Service which checks CDN_IMAGES_URL/R2_PUBLIC_URL
4. Returns a direct CDN URL when configured, or a signed URL otherwise

## Models Using This Pattern

### PropPhoto (via ExternalImageSupport concern)

```ruby
# app/models/concerns/external_image_support.rb
def image_url(variant_options: nil)
  if external?
    external_url
  elsif image.attached?
    active_storage_url(variant_options: variant_options)
  end
end

private

def active_storage_url(variant_options: nil)
  if variant_options && image.variable?
    image.variant(variant_options).processed.url
  else
    image.url
  end
end
```

### ListedProperty

```ruby
# app/models/pwb/listed_property.rb
def absolute_image_url(image)
  return nil unless image.attached?
  image.url
end

def variant_url(image, transformations)
  return nil unless image.attached? && image.variable?
  image.variant(transformations).processed.url
end
```

### PhotoAccessors Concern

```ruby
# app/models/concerns/listed_property/photo_accessors.rb
def primary_image_url
  first_photo = ordered_photo(1)
  return "" unless first_photo&.has_image?

  if first_photo.external?
    first_photo.external_url
  elsif first_photo.image.attached?
    first_photo.image.url
  else
    ""
  end
end
```

## External Image Support

For images hosted externally (not uploaded to ActiveStorage):

1. Check `external?` first
2. Return `external_url` directly
3. No variant support for external images

## Configuration

CDN URLs are configured via environment variables:

- `CDN_IMAGES_URL` - Primary CDN URL for images
- `R2_PUBLIC_URL` - Cloudflare R2 public bucket URL (fallback)

These are read by the R2Service when generating URLs.

## Testing

When testing image URL generation:

```ruby
# Stub the url method to return predictable values
allow(image).to receive(:url).and_return("https://cdn.example.com/image.jpg")
allow(image).to receive_message_chain(:variant, :processed, :url)
  .and_return("https://cdn.example.com/image_variant.jpg")
```

## See Also

- [CURRENT_ARCHITECTURE.md](./CURRENT_ARCHITECTURE.md) - Overall image architecture
- [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) - Quick reference for common patterns
- [ExternalImageSupport concern](../../app/models/concerns/external_image_support.rb)
