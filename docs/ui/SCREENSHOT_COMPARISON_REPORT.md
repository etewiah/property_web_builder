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

**Description:** The `?theme=bologna` URL parameter is being ignored in production. All "bologna" screenshots from production show the default theme instead.

**Evidence:**
- `prod/bologna/contact-desktop.png` shows blue default theme styling
- `dev/bologna/contact-desktop.png` shows orange/terra cotta Bologna theme styling
- Same issue affects all Bologna pages (buy, rent, sell, about, etc.)

**Likely Causes:**
1. Bologna theme not deployed to production
2. Theme not registered/whitelisted in production environment
3. Theme CSS not compiled for production

**Action Required:** Deploy Bologna theme to production and verify theme registration.

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
| bologna | ✅ Working | ❌ Shows default | **NEEDS FIX** |

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

1. **Deploy Bologna theme to production**
   - Ensure `app/themes/bologna/` is included in deployment
   - Verify theme CSS is compiled (`tailwind-bologna.css`)
   - Register theme in production website settings

2. **Verify theme switching mechanism**
   - Check `?theme=` parameter handler in production
   - Ensure Bologna is in the allowed themes list

3. **Re-run production screenshots after fix**
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
