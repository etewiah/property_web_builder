# Search Engine Verification Feature

**Status:** ENABLED
**Date:** 2026-01-01
**Previous Status:** DISABLED (pending proper testing and validation)

## Overview

This feature allows website owners to add Google Search Console and Bing Webmaster verification meta tags to their sites for site ownership verification.

## What Was Implemented

1. **Helper method** (`app/helpers/seo_helper.rb`)
   - `verification_meta_tags` - generates meta tags for Google and Bing verification
   - Returns nil if no verification codes are set (no empty meta tags)

2. **Admin UI** (`app/views/site_admin/website/settings/_seo_tab.html.erb`)
   - Form fields for Google and Bing verification codes
   - Instructions on where to find verification codes
   - Visual icons for each search engine

3. **Theme layouts** - verification_meta_tags calls:
   - `app/themes/brisbane/views/layouts/pwb/application.html.erb`
   - `app/themes/bologna/views/layouts/pwb/application.html.erb`
   - `app/themes/barcelona/views/layouts/pwb/application.html.erb`
   - Default and biarritz themes use `seo_meta_tags` which includes verification_meta_tags

4. **Specs** (`spec/helpers/seo_helper_spec.rb`)
   - Tests for verification_meta_tags helper
   - Covers: empty values, Google only, Bing only, both, nil website

## Storage

Verification codes are stored in `website.social_media` JSON field:
- `social_media['google_site_verification']`
- `social_media['bing_site_verification']`

## How It Works

1. Admin enters verification code in Website Settings > SEO tab
2. Code is saved to `website.social_media` JSON field
3. `verification_meta_tags` helper reads the codes and generates meta tags
4. Meta tags appear in the HTML `<head>` section of all pages
5. Search engines detect the meta tags to verify site ownership

## Generated Meta Tags

When verification codes are set, the following meta tags are rendered:

```html
<!-- Google Search Console -->
<meta name="google-site-verification" content="YOUR_GOOGLE_CODE">

<!-- Bing Webmaster Tools -->
<meta name="msvalidate.01" content="YOUR_BING_CODE">
```

## Testing Checklist (Completed)

- [x] Test that meta tags render correctly in HTML head
- [x] Verify empty values don't add empty meta tags
- [x] Test across all themes (default, brisbane, bologna, barcelona, biarritz)
- [x] Unit tests pass

## Related Files

- `app/helpers/seo_helper.rb` - Main implementation
- `app/views/site_admin/website/settings/_seo_tab.html.erb` - Admin UI
- `app/themes/*/views/layouts/pwb/application.html.erb` - Theme layouts
- `spec/helpers/seo_helper_spec.rb` - Test coverage
