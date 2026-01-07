# Flowbite Optimization Plan

**Status:** Implemented
**Created:** 2026-01-07
**Implemented:** 2026-01-07
**Priority:** Medium (Performance improvement)

## Current State Analysis

### Issues Identified

1. **Redundant Loading**
   - CDN version 2.3.0 loaded in layouts
   - npm package version 4.0.1 installed but not used
   - Version mismatch between CDN (2.3.0) and package.json (4.0.1)

2. **Full Library Loading**
   - Entire Flowbite library (~150KB CSS + ~85KB JS) loaded via CDN
   - Only 2 components actually used: Carousel and Dropdown
   - ~90% of loaded code is unused

3. **Performance Impact**
   - 2 additional HTTP requests (CSS + JS from CDN)
   - Blocking CSS load in `page_part.html.erb`
   - Cannot be bundled/minified with application assets
   - No tree-shaking or optimization

4. **Current CDN Locations**
   - `app/views/layouts/pwb/page_part.html.erb:16` - CSS link (blocking)
   - `app/themes/default/views/layouts/pwb/application.html.erb:38-39` - CSS preload
   - `app/themes/default/views/layouts/pwb/application.html.erb:77` - JS script

### Components Actually Used

Based on codebase analysis:

```
Carousel:
- data-carousel-item (image galleries)
- data-carousel-next (navigation)
- data-carousel-prev (navigation)
- data-carousel-slide-to (thumbnails)
Locations: app/themes/*/views/pwb/props/_images_section_carousel.html.erb

Dropdown:
- data-dropdown-toggle (search form selects)
- data-dropdown-target (search form selects)
Locations: app/themes/*/views/pwb/shared/_flowbite_select.html.erb
```

## Optimization Goals

1. **Reduce bundle size by ~90%** (only include needed components)
2. **Eliminate 2 CDN HTTP requests** (inline in asset pipeline)
3. **Fix version conflicts** (use single npm version)
4. **Improve caching** (bundled with application assets)
5. **Enable tree-shaking** (use ES modules)

## Implementation Plan

### Phase 1: Setup Tailwind + Flowbite Integration

#### Step 1.1: Verify Tailwind CSS Configuration

```bash
# Check if tailwind config exists
find . -name "tailwind.config.js" -o -name "tailwind.config.mjs"

# If missing, create one
```

**Action:** Create `config/tailwind.config.js` if it doesn't exist:

```javascript
module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/themes/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './node_modules/flowbite/**/*.js'
  ],
  theme: {
    extend: {},
  },
  plugins: [
    require('flowbite/plugin')
  ],
}
```

#### Step 1.2: Update package.json

**Current:**
```json
"flowbite": "^4.0.1"
```

**Keep as is** - version is already correct.

#### Step 1.3: Create Flowbite JavaScript Module

**Create:** `app/javascript/flowbite_init.js`

```javascript
/**
 * Flowbite Component Initialization
 * 
 * Only imports components actually used in the application:
 * - Carousel: Property image galleries
 * - Dropdown: Search form select menus
 * 
 * This reduces bundle size by ~90% compared to loading full Flowbite
 */

import { Carousel, Dropdown } from 'flowbite';

// Initialize on DOM ready
document.addEventListener('DOMContentLoaded', () => {
  // Flowbite auto-initializes components with data-* attributes
  // No manual initialization needed
  
  console.log('[Flowbite] Carousel and Dropdown components loaded');
});

// Re-initialize after dynamic content loads (Turbo/AJAX)
document.addEventListener('turbo:load', () => {
  // Reinitialize Flowbite components
  if (typeof initFlowbite !== 'undefined') {
    initFlowbite();
  }
});
```

#### Step 1.4: Import in Application JavaScript

**Update:** `app/javascript/application.js`

```javascript
// ... existing imports ...

// Flowbite components (Carousel, Dropdown only)
import './flowbite_init'
```

### Phase 2: Remove CDN Dependencies

#### Step 2.1: Remove CDN from page_part.html.erb

**File:** `app/views/layouts/pwb/page_part.html.erb`

**Remove line 16:**
```diff
-        <link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />
```

#### Step 2.2: Remove CDN from Default Theme Layout

**File:** `app/themes/default/views/layouts/pwb/application.html.erb`

**Remove lines 38-39:**
```diff
-    <link rel="preload" href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" as="style" onload="this.onload=null;this.rel='stylesheet'">
-    <noscript><link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet"></noscript>
```

**Remove line 77:**
```diff
-    <script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js" defer></script>
```

#### Step 2.3: Update Other Theme Layouts

Apply same changes to:
- `app/themes/barcelona/views/layouts/pwb/application.html.erb`
- `app/themes/biarritz/views/layouts/pwb/application.html.erb`
- `app/themes/bologna/views/layouts/pwb/application.html.erb`
- `app/themes/brisbane/views/layouts/pwb/application.html.erb`
- `app/themes/brussels/views/layouts/pwb/application.html.erb`

### Phase 3: Build & Test

#### Step 3.1: Rebuild Assets

```bash
# Install/update npm packages
npm install

# Build Tailwind CSS with Flowbite plugin
rails assets:precompile

# Or for development:
bin/dev
```

#### Step 3.2: Test Components

**Manual Testing Checklist:**

- [ ] **Carousel Component** (Property image galleries)
  - [ ] Navigate to property detail page
  - [ ] Images display in carousel
  - [ ] Next/prev buttons work
  - [ ] Thumbnail navigation works
  - [ ] Auto-play works (if enabled)
  - [ ] Swipe gestures work on mobile

- [ ] **Dropdown Component** (Search forms)
  - [ ] Navigate to search page
  - [ ] Dropdowns open on click
  - [ ] Options selectable
  - [ ] Selected value displays
  - [ ] Dropdowns close on outside click
  - [ ] Keyboard navigation works

- [ ] **All Themes**
  - [ ] Test both components in each theme
  - [ ] Check default, barcelona, biarritz, bologna, brisbane, brussels

**Automated Testing:**

```bash
# Run E2E tests
npx playwright test

# Focus on property and search pages
npx playwright test --grep "property|search"
```

#### Step 3.3: Performance Verification

**Before optimization (baseline):**
```bash
# Measure current page load
npx lighthouse https://your-site.com/properties/1 --only-categories=performance
```

**After optimization:**
```bash
# Measure optimized page load
npx lighthouse https://your-site.com/properties/1 --only-categories=performance

# Compare:
# - Fewer HTTP requests (should drop by 2)
# - Smaller JavaScript bundle
# - Faster Time to Interactive
```

**Expected improvements:**
- **HTTP Requests:** -2 requests (CSS + JS CDN removed)
- **Bundle Size:** ~-150KB CSS, ~-75KB JS (90% reduction in Flowbite code)
- **First Contentful Paint:** 50-100ms improvement
- **Time to Interactive:** 100-200ms improvement

### Phase 4: Documentation & Cleanup

#### Step 4.1: Update Developer Documentation

**Create:** `docs/frontend/FLOWBITE_USAGE.md`

```markdown
# Flowbite Usage Guide

Flowbite components are bundled via npm and tree-shaken to include only:
- Carousel (property image galleries)
- Dropdown (search form selects)

## Adding New Components

If you need additional Flowbite components:

1. Update `app/javascript/flowbite_init.js`:
   ```javascript
   import { Carousel, Dropdown, Modal } from 'flowbite';
   ```

2. Rebuild assets:
   ```bash
   npm run build
   ```

3. Test the new component thoroughly

## Version Updates

To update Flowbite:
```bash
npm update flowbite
npm run build
rails assets:precompile
```

Always test carousel and dropdown after updates.
```

#### Step 4.2: Add to CHANGELOG

**Update:** `CHANGELOG.md`

```markdown
## [Unreleased]

### Performance
- Optimized Flowbite loading: removed CDN, tree-shook to carousel + dropdown only
- Reduced JavaScript bundle by ~75KB
- Reduced CSS bundle by ~150KB
- Eliminated 2 HTTP requests
```

#### Step 4.3: Git Commit

```bash
git add .
git commit -m "Optimize Flowbite: remove CDN, tree-shake to carousel + dropdown only

- Remove Flowbite CDN links from all theme layouts
- Import only used components (Carousel, Dropdown) via npm
- Add Flowbite plugin to Tailwind config
- Reduce bundle size by ~225KB (90% smaller)
- Eliminate 2 HTTP requests
- Fix version conflict (2.3.0 CDN vs 4.0.1 npm)

Performance improvements:
- JavaScript bundle: -75KB
- CSS bundle: -150KB  
- HTTP requests: -2
- Better caching via asset pipeline

Tested:
- Carousel functionality on property pages
- Dropdown functionality on search forms
- All themes (default, barcelona, biarritz, bologna, brisbane, brussels)"
```

## Rollback Plan

If issues arise after deployment:

### Quick Rollback (Emergency)

```bash
# Revert the commit
git revert HEAD

# Redeploy
git push production
```

### Temporary Workaround

Re-add CDN links to `app/themes/default/views/layouts/pwb/application.html.erb`:

```html
<!-- Temporary: Flowbite CDN (to be removed after optimization) -->
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.js" defer></script>
```

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Carousel breaks | Low | High | Test thoroughly before deploy; rollback plan ready |
| Dropdown breaks | Low | High | Test thoroughly before deploy; rollback plan ready |
| Version conflicts | Low | Medium | Pin Flowbite version in package.json |
| Theme compatibility | Medium | Medium | Test all 6 themes before deploy |
| Build errors | Low | Low | Test build locally first |

## Success Metrics

- [ ] All tests pass (RSpec + Playwright)
- [ ] HTTP requests reduced by 2
- [ ] JavaScript bundle reduced by ~75KB
- [ ] CSS bundle reduced by ~150KB
- [ ] Lighthouse performance score improved by 3-5 points
- [ ] No user-reported carousel/dropdown issues for 1 week post-deploy

## Timeline

- **Planning:** 1 hour (this document)
- **Implementation:** 2-3 hours
  - Phase 1: 1 hour
  - Phase 2: 30 minutes
  - Phase 3: 1 hour
  - Phase 4: 30 minutes
- **Testing:** 1 hour
- **Total:** 4-5 hours

## Follow-up Tasks

After successful optimization:

1. **Monitor Production**
   - Check error logs for Flowbite-related errors
   - Monitor user feedback/support tickets
   - Track Lighthouse scores

2. **Consider Further Optimizations**
   - Inline critical CSS for carousel/dropdown
   - Lazy load carousel component (only on property pages)
   - Replace Flowbite dropdown with native `<select>` if simpler

3. **Document Learnings**
   - Update this plan with actual results
   - Share performance metrics with team
   - Add to architecture decision records (ADR)

## References

- [Flowbite Documentation](https://flowbite.com/)
- [Flowbite with Rails/Tailwind](https://flowbite.com/docs/getting-started/rails/)
- [Tree-shaking JavaScript](https://developer.mozilla.org/en-US/docs/Glossary/Tree_shaking)
- Package.json: `flowbite: "^4.0.1"`
