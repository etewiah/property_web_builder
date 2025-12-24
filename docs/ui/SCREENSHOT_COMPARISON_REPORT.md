# Screenshot Comparison Report: Dev vs Production

**Date:** December 24, 2024

## Summary

Comparison of local development screenshots with production (https://demo.propertywebbuilder.com/) revealed significant issues with theme deployment.

## Folder Structure

```
docs/screenshots/
├── dev/           # Local development screenshots
│   ├── default/
│   ├── brisbane/
│   └── bologna/
├── prod/          # Production screenshots
│   ├── default/
│   ├── brisbane/
│   └── bologna/
└── COMPARISON_REPORT.md
```

## Findings

### Issue 1: Bologna Theme Not Working in Production

**Severity:** High

**Status:** FIXED (commit 4bd1db4a)

**Description:** The `?theme=bologna` URL parameter was being ignored in production. All "bologna" screenshots from production showed the default theme instead.

**Root Cause:** Bologna was not included in the `ALLOWED_THEMES` whitelist in `app/controllers/pwb/application_controller.rb`. The whitelist only had `default` and `brisbane`.

**Fix Applied:**
```ruby
# Before (line 12):
if %w(default brisbane).include? params[:theme]

# After:
ALLOWED_THEMES = %w[default brisbane bologna].freeze
# ...
if ALLOWED_THEMES.include?(params[:theme])
```

**Action Required:** Deploy the fix to production. After deployment, re-run production screenshots to verify.

---

### Issue 2: Brisbane Theme Working Correctly

**Status:** OK

**Description:** The `?theme=brisbane` parameter IS working correctly in production. Screenshots show green Brisbane theme styling.

---

### Issue 3: Local Screenshot Script Bug (Fixed)

**Status:** Fixed

**Description:** The local screenshot script (`take-screenshots.js`) was not passing the `?theme=` parameter in URLs, causing all local screenshots to use the default theme regardless of `SCREENSHOT_THEME` env var.

**Fix Applied:** Updated script to use `buildUrl()` function that appends `?theme=` parameter for non-default themes.

---

## Theme Comparison Matrix

| Theme | Dev | Prod | Status |
|-------|-----|------|--------|
| default | ✅ Working | ✅ Working | OK |
| brisbane | ✅ Working | ✅ Working | OK |
| bologna | ✅ Working | ✅ Fixed (pending deploy) | **FIXED** |

## Visual Differences by Page

### Contact Page
| Environment | Bologna Theme Applied? |
|-------------|----------------------|
| Dev | ✅ Yes - Orange card layout, integrated map |
| Prod | ❌ No - Blue default theme, different layout |

### Buy/Rent Search Pages
| Environment | Bologna Theme Applied? |
|-------------|----------------------|
| Dev | ✅ Yes - Terra cotta colors, styled filters |
| Prod | ❌ No - Default blue theme |

### Home Page
| Environment | Bologna Theme Applied? |
|-------------|----------------------|
| Dev | ✅ Yes - Warm color palette |
| Prod | ❌ No - Default styling |

## Recommended Actions

1. ~~**Deploy Bologna theme to production**~~ **FIXED**
   - ~~Ensure `app/themes/bologna/` is included in deployment~~
   - ~~Verify theme CSS is compiled (`tailwind-bologna.css`)~~
   - ~~Register theme in production website settings~~
   - **Fix:** Added `bologna` to `ALLOWED_THEMES` in `app/controllers/pwb/application_controller.rb`

2. ~~**Verify theme switching mechanism**~~ **FIXED**
   - ~~Check `?theme=` parameter handler in production~~
   - ~~Ensure Bologna is in the allowed themes list~~
   - **Fix:** `ALLOWED_THEMES = %w[default brisbane bologna].freeze`

3. **Re-run production screenshots after deployment**
   ```bash
   node scripts/take-screenshots-prod.js
   ```

4. **Compare again to verify fix**
   - All Bologna screenshots should show orange/terra cotta styling
   - Contact page should have card layout with map

## Scripts Used

- `scripts/take-screenshots.js` - Local dev screenshots (saves to `docs/screenshots/dev/`)
- `scripts/take-screenshots-prod.js` - Production screenshots (saves to `docs/screenshots/prod/`)

## How to Re-run Comparison

```bash
# Local dev (requires server running on localhost:3000)
SCREENSHOT_THEME=default node scripts/take-screenshots.js
SCREENSHOT_THEME=brisbane node scripts/take-screenshots.js
SCREENSHOT_THEME=bologna node scripts/take-screenshots.js

# Production
node scripts/take-screenshots-prod.js
```
