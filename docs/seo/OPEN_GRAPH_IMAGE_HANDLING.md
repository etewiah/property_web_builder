# Open Graph (OG) Image Handling in PropertyWebBuilder

## Overview

PropertyWebBuilder uses a **static configuration approach** for Open Graph images. OG images are **not dynamically generated** but rather configured statically through the admin UI and injected as meta tags on each page.

## Current Implementation

### 1. Meta Tags Configuration

Open Graph meta tags are generated via the SEO helper and included in all theme layouts.

**File**: `/app/helpers/seo_helper.rb` (Lines 125-175)

**Generated Meta Tags**:
```html
<meta property="og:type" content="website">
<meta property="og:title" content="Page Title">
<meta property="og:description" content="Page description">
<meta property="og:url" content="https://example.com/page">
<meta property="og:site_name" content="Company Name">
<meta property="og:image" content="https://example.com/og-image.jpg">
<meta property="og:locale" content="en_US">

<!-- Twitter Card -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Page Title">
<meta name="twitter:description" content="Page description">
<meta name="twitter:image" content="https://example.com/og-image.jpg">
```

### 2. Where Meta Tags Are Included

All theme layouts include the SEO meta tags in the `<head>` section:

**Default Theme**: `/app/themes/default/views/layouts/pwb/application.html.erb` (Line 7)
```erb
<%= seo_meta_tags %>
```

**Bologna Theme**: `/app/themes/bologna/views/layouts/pwb/application.html.erb` (Line 12)
**Brisbane Theme**: `/app/themes/brisbane/views/layouts/pwb/application.html.erb` (Line 12)

### 3. OG Image Source Hierarchy

The `seo_image` helper method (in `seo_helper.rb` lines 56-72) determines which image is used:

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
    # Fallback to website logo or default
    current_website&.logo_url.presence
  end
end
```

**Priority order**:
1. `@seo_data[:image]` - Page-specific image set via `set_seo()`
2. `current_website.logo_url` - Website logo as fallback
3. `nil` - No og:image tag if neither is available

### 4. Logo URL Source

The website logo is accessed via the `logo_url` method defined in the styleable concerns:

**Files**:
- `/app/models/concerns/pwb/website_styleable.rb` (Lines 139-144)
- `/app/models/concerns/website/styleable.rb` (Lines 71-76)

```ruby
def logo_url
  logo_content = contents.find_by_key("logo")
  if logo_content && !logo_content.content_photos.empty?
    logo_content.content_photos.first.image_url
  end
end
```

The logo is stored as a **Content** model with key `"logo"` and associated **ContentPhoto** images.

## How It Works for Different Page Types

### Property Pages (For Sale / For Rent)

**Controller**: `/app/controllers/pwb/props_controller.rb` (Lines 152-190)

Each property page calls `set_property_seo()` which:

1. Gets the property's **first image** via `property.primary_image_url`
2. Sets it as the OG image
3. Falls back to website logo if no property image exists

```ruby
def set_property_seo(property, operation_type)
  # Get first image for social sharing
  image_url = property.primary_image_url

  set_seo(
    title: seo_title_value.presence || property.title,
    description: meta_desc_value.presence || truncate_description(property.description),
    canonical_url: canonical_url,
    image: image_url,      # <-- First property image
    og_type: 'product',
    noindex: should_noindex
  )

  # Store property for JSON-LD generation in the view
  @seo_property = property
end
```

### CMS Pages

CMS pages can set their own SEO data via the `set_page_seo()` method (lines 316-335), but image handling is not explicitly shown in the current implementation.

### Fallback

If no page-specific image is set, the website's logo URL is used as the fallback.

## Admin Configuration

### Where to Set OG Images

**Location**: Site Admin → Settings → SEO Tab

**File**: `/app/views/site_admin/website/settings/_seo_tab.html.erb` (Lines 52-104)

**Configurable Fields**:
- **Open Graph Image URL** (Line 60) - Direct URL to OG image file
- **Twitter Card Type** (Line 68) - `summary` or `summary_large_image`
- **Twitter Handle** (Line 78) - Twitter/X handle
- **Facebook Page URL** (Line 85)
- **Instagram Handle** (Line 92)
- **LinkedIn URL** (Line 99)

**Recommended OG Image Specs**:
- **Size**: 1200×630 pixels
- **Format**: JPG or PNG
- **Location**: Can be uploaded anywhere and linked via URL

### Storage

These settings are stored in the `social_media` JSON column on the `Pwb::Website` model:

```ruby
# Schema
t.json "social_media", default: {}

# Stored data structure
{
  "og_image": "https://example.com/og-image.jpg",
  "twitter_card": "summary_large_image",
  "twitter_handle": "@company",
  "facebook_url": "https://facebook.com/company",
  "instagram_handle": "@company",
  "linkedin_url": "https://linkedin.com/company"
}
```

## Current Limitations

### 1. No Dynamic Image Generation

PropertyWebBuilder **does NOT dynamically generate OG images**. All images are:
- Manually uploaded or linked
- Configured statically in the admin UI
- The same for all pages (unless property pages use their primary image)

### 2. Static Website-Level Image

The admin UI only provides one `og_image` field, which applies to:
- CMS pages
- Search/listing pages
- Any page that doesn't explicitly set its own image

### 3. Image Type/Dimensions Not Validated

The admin form does not:
- Validate image dimensions
- Check image content type
- Provide image upload functionality
- Preview the configured image

### 4. Property Pages Use Primary Image Only

For property listings, the OG image is always the **first photo** of the property. There's no way to:
- Select a different photo as the OG image
- Customize the image per listing
- Use a themed/branded image instead

## Architecture Decisions

### Why Static vs. Dynamic?

1. **Performance**: No image processing/rendering on each request
2. **Simplicity**: Images served from CDN or static file storage
3. **Consistency**: Same behavior as traditional Rails apps
4. **No External Dependencies**: No need for image generation libraries

### Alternative Approaches (Not Implemented)

- **Dynamic Generation** (e.g., using ImageMagick, Puppeteer, or a library like OgImage): Generate branded images with property details
- **Database-Driven**: Store different images per page/property in the database
- **S3 Integration**: Automatically upload and manage images in cloud storage
- **Template-Based**: Use image templates with dynamic text overlays

## Related Files

### Helpers & Views
- `/app/helpers/seo_helper.rb` - Meta tag generation
- `/app/themes/*/views/layouts/pwb/application.html.erb` - Meta tag inclusion (3 theme layouts)
- `/app/views/site_admin/website/settings/_seo_tab.html.erb` - Admin UI
- `/app/views/pwb/shared/_social_sharing.html.erb` - Social sharing buttons (different from OG tags)

### Models & Controllers
- `/app/controllers/pwb/props_controller.rb` - Property page SEO setup
- `/app/models/concerns/pwb/website_styleable.rb` - Logo URL method
- `/app/models/concerns/website/styleable.rb` - Legacy logo URL method

### Admin Controller
- `/app/controllers/site_admin/website/settings_controller.rb` - Handles SEO settings updates

## Future Enhancements

If PropertyWebBuilder were to add dynamic OG image generation:

1. **Property-Level OG Images**
   - Store selected OG image per property
   - Admin UI to choose from existing property photos
   - Fallback to first photo

2. **Branded OG Images**
   - Generate images with property details (price, bedrooms, location)
   - Use website's theme colors/branding
   - Add property photos with text overlays

3. **Image Generation Service**
   - Create background jobs to generate OG images
   - Cache generated images
   - Regenerate on property updates

4. **Admin Image Upload**
   - Add file upload to the SEO tab
   - Store in ActiveStorage
   - Preview before saving

## Testing

See `/spec/helpers/seo_helper_spec.rb` for SEO helper tests, though specific OG image testing is limited.

## Summary Table

| Aspect | Current Implementation | Notes |
|--------|----------------------|-------|
| **Image Type** | Static | No generation |
| **Website OG Image** | Configured in Admin UI | One URL for all pages |
| **Property OG Image** | First photo of property | Automatic, no customization |
| **Image Storage** | External URL | No built-in upload |
| **Admin UI** | Text input field | No preview or upload |
| **Fallback** | Website logo | If no image set |
| **Format Support** | Any (not validated) | Should be JPG/PNG |
| **Size Requirements** | Recommended 1200×630px | Not enforced |
