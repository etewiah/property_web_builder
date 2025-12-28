# TODO: Search Engine Verification Feature

**Status:** DISABLED (hidden from UI, code commented out)
**Date:** 2025-12-27
**Reason:** Feature implemented but disabled pending proper testing and validation

## Overview

This feature allows website owners to add Google Search Console and Bing Webmaster verification meta tags to their sites. The implementation is complete but has been disabled to avoid any potential performance impact until it can be properly tested in production.

## What Was Implemented

1. **Helper method** (`app/helpers/seo_helper.rb`)
   - `verification_meta_tags` - generates meta tags for Google and Bing verification
   - Currently stubbed to return `nil`

2. **Admin UI** (`app/views/site_admin/website/settings/_seo_tab.html.erb`)
   - Form fields for Google and Bing verification codes
   - Currently hidden with ERB comments

3. **Theme layouts** - verification_meta_tags calls added but commented out:
   - `app/themes/brisbane/views/layouts/pwb/application.html.erb`
   - `app/themes/bologna/views/layouts/pwb/application.html.erb`
   - `app/themes/barcelona/views/layouts/pwb/application.html.erb`
   - Default and biarritz themes use `seo_meta_tags` which has the call commented out

4. **Specs** (`spec/helpers/seo_helper_spec.rb`)
   - Tests for verification_meta_tags helper
   - Currently will fail since the method is stubbed - update specs when re-enabling

## Storage

Verification codes are stored in `website.social_media` JSON field:
- `social_media['google_site_verification']`
- `social_media['bing_site_verification']`

## How to Re-Enable

1. **Uncomment the helper method** in `app/helpers/seo_helper.rb`:
   - Find the commented `verification_meta_tags` implementation
   - Uncomment it and remove the stub method

2. **Uncomment the call in seo_meta_tags**:
   - In the same file, find `# tags << verification_meta_tags`
   - Uncomment it

3. **Uncomment in theme layouts**:
   - `app/themes/brisbane/views/layouts/pwb/application.html.erb`
   - `app/themes/bologna/views/layouts/pwb/application.html.erb`
   - `app/themes/barcelona/views/layouts/pwb/application.html.erb`
   - Find `<%# <%= verification_meta_tags %> %>` and uncomment

4. **Uncomment admin UI**:
   - `app/views/site_admin/website/settings/_seo_tab.html.erb`
   - Find the "Search Engine Verification" section and uncomment

5. **Run the specs**:
   ```bash
   bundle exec rspec spec/helpers/seo_helper_spec.rb
   ```

## Testing Checklist

Before re-enabling in production:

- [ ] Test that meta tags render correctly in HTML head
- [ ] Verify Google Search Console can detect the verification tag
- [ ] Verify Bing Webmaster Tools can detect the verification tag
- [ ] Check that empty values don't add empty meta tags
- [ ] Performance test - ensure no impact on page load time
- [ ] Test across all themes (default, brisbane, bologna, barcelona, biarritz)

## Performance Notes

The feature was disabled out of caution. The actual performance impact is minimal:
- One hash lookup per page load (`website.social_media`)
- Only renders meta tags if verification codes are set
- No database queries beyond what's already loaded

When re-enabling, the impact should be negligible, but always verify with real measurements.

## Related Files

- `app/helpers/seo_helper.rb` - Main implementation
- `app/views/site_admin/website/settings/_seo_tab.html.erb` - Admin UI
- `app/themes/*/views/layouts/pwb/application.html.erb` - Theme layouts
- `spec/helpers/seo_helper_spec.rb` - Test coverage
