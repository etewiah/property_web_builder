# Tailwind CDN → Compiled Migration Implementation Plan

## Project Overview

Migrate PropertyWebBuilder from **Tailwind CDN with inline config** to **compiled Tailwind CSS** while preserving per-tenant customization via CSS variables.

### Key Constraints
- **3 distinct themes** with different configurations (Bologna, Brisbane, Default)
- **Per-tenant customization** via `Website.style_variables`
- **Runtime CSS generation** via ERB partials
- **Backward compatibility** required

### Success Criteria
✅ No visual changes after migration
✅ Faster page load times (no CDN, no inline config parsing)
✅ Per-tenant customization still works
✅ All tests pass
✅ Build process documented

---

## Phase 1: Preparation & Analysis (1 day)

### Task 1.1: Identify All CDN Usages
**Status**: ✅ COMPLETE (from this analysis)

**Files affected**:
```
app/themes/bologna/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/default/views/layouts/pwb/application.html.erb
```

**Work**: Search for additional Tailwind CDN references in views

```bash
grep -r "cdn.tailwindcss.com" app/
grep -r "tailwind.config" app/
grep -r "window.tailwind" app/
```

### Task 1.2: Audit CSS Variable Dependencies

**Work**: Map which components use which variables

```bash
grep -r "var(--" app/themes/ app/views/pwb/
grep -r "style_variables" app/ --include="*.rb"
```

### Task 1.3: Create Baseline Performance Metrics

**Work**: Measure current page load time, CSS size, JavaScript size

```bash
# Document metrics before migration
- LCP (Largest Contentful Paint)
- FCP (First Contentful Paint)
- CSS bundle size
- JS bundle size
- Network requests count
```

---

## Phase 2: Setup Build Infrastructure (1-2 days)

### Task 2.1: Create tailwind.config.js

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/tailwind.config.js`

**Structure**:
```javascript
module.exports = {
  content: [
    'app/**/*.{html,erb,js}',
    'app/views/**/*.erb',
    'app/themes/**/*.erb',
  ],
  theme: {
    // Theme customizations here
  },
  plugins: [],
}
```

**Approach**: Start with DEFAULT theme (simplest)

### Task 2.2: Extract Inline Configs to tailwind.config.js

**Default Theme Extraction**:
```javascript
// From app/themes/default/views/layouts/pwb/application.html.erb
// Extract this:
theme: {
  container: {
    center: true,
    padding: 'var(--container-padding)',
  },
  extend: {
    colors: {
      primary: 'var(--primary-color)',
      secondary: 'var(--secondary-color)',
      // ... more colors
    },
    fontFamily: {
      sans: ['var(--font-primary)', 'sans-serif'],
      serif: ['var(--font-secondary)', 'serif'],
    },
    borderRadius: {
      DEFAULT: 'var(--border-radius)',
      'lg': 'var(--border-radius)',
    }
  }
}
```

**Bologna Theme Extraction**:
```javascript
// From app/themes/bologna/views/layouts/pwb/application.html.erb
theme: {
  container: {
    center: true,
    padding: {
      DEFAULT: '1.5rem',
      sm: '2rem',
      lg: '3rem',
      xl: '4rem',
    },
  },
  extend: {
    colors: {
      'terra': { /* 50-900 palette */ },
      'olive': { /* 50-900 palette */ },
      // ... rest of colors
    },
    fontFamily: {
      sans: ['DM Sans', 'system-ui', 'sans-serif'],
      display: ['Outfit', 'system-ui', 'sans-serif'],
    },
    // ... rest of customizations
  }
}
```

**Brisbane Theme Extraction**: Similar to Bologna

### Task 2.3: Setup CSS Build Process

**Option A: Separate Builds (Recommended)**

Create 3 build commands:
```json
{
  "scripts": {
    "tailwind:default": "tailwindcss -i ./input.css -o ./app/assets/stylesheets/tailwind-default.css --config ./tailwind.default.js",
    "tailwind:bologna": "tailwindcss -i ./input.css -o ./app/assets/stylesheets/tailwind-bologna.css --config ./tailwind.bologna.js",
    "tailwind:brisbane": "tailwindcss -i ./input.css -o ./app/assets/stylesheets/tailwind-brisbane.css --config ./tailwind.brisbane.js",
    "tailwind:build": "npm run tailwind:default && npm run tailwind:bologna && npm run tailwind:brisbane"
  }
}
```

**Option B: Single Config with Themes (Alternative)**

Use CSS layers to separate theme-specific styles:
```javascript
module.exports = {
  content: [
    'app/themes/**/*.erb',
    'app/views/**/*.erb',
  ],
  theme: {
    extend: {
      // Colors that work for all themes (use CSS variables)
      colors: {
        primary: 'var(--primary-color)',
        secondary: 'var(--secondary-color)',
      }
    }
  },
  corePlugins: {
    preflight: false, // Let Flowbite handle reset
  }
}
```

**Recommendation**: Use Option A for maximum control and predictability

### Task 2.4: Create CSS Input File

**Location**: `/Users/etewiah/dev/sites-older/property_web_builder/app/assets/stylesheets/tailwind-input.css`

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Keep existing theme-specific CSS */
@import 'bologna_theme';
@import 'brisbane_theme';
```

---

## Phase 3: Build for First Theme (1-2 days)

### Task 3.1: Compile Default Theme

```bash
cd /Users/etewiah/dev/sites-older/property_web_builder

# Install if needed
npm install

# Build Default theme
npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-default.css \
                --config tailwind.default.js
```

**Verify**: Check output file exists and has reasonable size

```bash
ls -lh app/assets/stylesheets/tailwind-default.css
# Should be ~80-150KB unminified
```

### Task 3.2: Update Default Theme Layout

**Current**:
```erb
<script src="https://cdn.tailwindcss.com"></script>
<script>
  tailwind.config = { ... }
</script>
```

**New**:
```erb
<%= stylesheet_link_tag "tailwind-default", media: "all" %>
```

**File**: `app/themes/default/views/layouts/pwb/application.html.erb`

### Task 3.3: Keep CSS Variable Injection

**Important**: Keep the custom_styles helper call

```erb
<style>
  <%= custom_styles "default" %>
</style>
```

This generates per-tenant CSS variables at request time.

### Task 3.4: Test Default Theme

**Manual Testing**:
```bash
# Start Rails server
rails s

# Visit a default theme website
# Verify:
# - Page loads without Tailwind CDN request
# - CSS is properly applied
# - Colors customize based on Website.style_variables
# - No console errors about missing Tailwind
```

**Automated Testing**:
```bash
# Run existing specs
rspec spec/themes/default_spec.rb

# Check CSS is included
grep -i tailwind-default spec/themes/default_spec.rb
```

### Task 3.5: Measure Performance Improvement

```bash
# Compare metrics with Phase 1 baseline
- Check LCP/FCP improvement
- Count network requests
- Measure CSS parse time
```

---

## Phase 4: Build for Bologna & Brisbane (1-2 days each)

### Task 4.1: Compile Bologna Theme

```bash
npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-bologna.css \
                --config tailwind.bologna.js
```

### Task 4.2: Update Bologna Layout

**File**: `app/themes/bologna/views/layouts/pwb/application.html.erb`

```erb
<!-- Remove: -->
<script src="https://cdn.tailwindcss.com"></script>
<script>
  tailwind.config = { ... }
</script>

<!-- Add: -->
<%= stylesheet_link_tag "tailwind-bologna", media: "all" %>

<!-- Keep: -->
<style>
  <%= custom_styles "bologna" %>
</style>
```

### Task 4.3: Test Bologna Theme

```bash
# Manual testing with a Bologna theme website
# Verify all colors, fonts, custom styles work
```

### Task 4.4: Compile Brisbane Theme

```bash
npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-brisbane.css \
                --config tailwind.brisbane.js
```

### Task 4.5: Update Brisbane Layout

**File**: `app/themes/brisbane/views/layouts/pwb/application.html.erb`

Similar to Bologna.

### Task 4.6: Test Brisbane Theme

```bash
# Manual testing with a Brisbane theme website
```

---

## Phase 5: Cleanup & Optimization (1 day)

### Task 5.1: Remove Inline Tailwind Config

Remove from all three layouts:
```erb
<script>
  tailwind.config = { ... }
</script>
```

### Task 5.2: Remove Flowbite CSS from CDN

**Current**:
```erb
<link href="https://cdnjs.cloudflare.com/ajax/libs/flowbite/2.3.0/flowbite.min.css" rel="stylesheet" />
```

**Options**:
1. Keep Flowbite CDN (simpler)
2. Install Flowbite via npm and compile together
3. Replace with custom components

**Recommendation**: Keep CDN for now, can optimize later

### Task 5.3: Minify Compiled CSS

Create production-ready minified versions:

```bash
npm install -D cssnano

npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-default.min.css \
                --minify \
                --config tailwind.default.js
```

### Task 5.4: Add to Asset Pipeline

**File**: `app/assets/config/manifest.js`

```javascript
//= link tailwind-default.css
//= link tailwind-bologna.css
//= link tailwind-brisbane.css
```

Or keep Rails asset pipeline to handle this automatically.

### Task 5.5: Update Precompile List

**File**: `config/initializers/assets.rb`

```ruby
Rails.application.config.assets.precompile += %w(
  tailwind-default.css
  tailwind-bologna.css
  tailwind-brisbane.css
)
```

### Task 5.6: Documentation

Create `docs/` files explaining:
- How to rebuild CSS after changes
- How to add new theme
- CSS variable customization guide
- Build process setup

---

## Phase 6: Testing & Validation (2-3 days)

### Task 6.1: Visual Regression Testing

```bash
# Automated visual testing with Percy, BackstopJS, or similar
# Compare before/after screenshots
```

### Task 6.2: Cross-Browser Testing

Test on:
- Chrome/Edge (latest)
- Firefox (latest)
- Safari (latest)
- Mobile browsers

### Task 6.3: Per-Tenant Customization Testing

```bash
# For each theme:
# 1. Update Website.style_variables with custom colors
# 2. Verify colors appear correctly
# 3. Test with multiple color combinations

# Test cases:
- primary_color override
- secondary_color override
- font_primary override
- border_radius override
- footer_bg_color override
- All custom_styles variables
```

### Task 6.4: Performance Testing

```bash
# Production build performance
# Measure with Lighthouse
# Measure with WebPageTest
# Compare with CDN baseline
```

### Task 6.5: Responsive Design Testing

Test on:
- Desktop (1920px)
- Tablet (768px)
- Mobile (320px)

### Task 6.6: Component Testing

Run full test suite:
```bash
rspec spec/ --tag theme
```

### Task 6.7: Accessibility Testing

- WCAG contrast ratios
- Keyboard navigation
- Screen reader compatibility

---

## Phase 7: Deployment & Monitoring (1 day)

### Task 7.1: Build CSS in CI/CD

Add to GitHub Actions / CI workflow:

```yaml
- name: Build Tailwind CSS
  run: npm run tailwind:build

- name: Commit compiled CSS
  run: |
    git add app/assets/stylesheets/tailwind-*.css
    git commit -m "Rebuild Tailwind CSS" || true
    git push
```

### Task 7.2: Deploy to Staging

```bash
# Deploy to staging environment
# Monitor for issues
# Get stakeholder approval
```

### Task 7.3: Monitor Metrics

After deployment, monitor:
- Page load time (LCP, FCP)
- CSS file size
- JavaScript size
- Error rates
- Conversion rates (ensure no impact)

### Task 7.4: Rollback Plan

If issues occur:
1. Revert to CDN layouts
2. Keep compiled CSS as option for future
3. Document learnings

### Task 7.5: Deploy to Production

```bash
# Staged deployment
# Monitor metrics
# Celebrate improvement!
```

---

## File Changes Summary

### New Files to Create
```
tailwind.config.js                    (root)
tailwind.default.js                   (root)
tailwind.bologna.js                   (root)
tailwind.brisbane.js                  (root)
app/assets/stylesheets/tailwind-input.css

docs/styling/tailwind-migration.md
docs/styling/css-variable-reference.md
docs/styling/build-process.md
```

### Files to Modify
```
app/themes/bologna/views/layouts/pwb/application.html.erb
app/themes/brisbane/views/layouts/pwb/application.html.erb
app/themes/default/views/layouts/pwb/application.html.erb
config/initializers/assets.rb
package.json (add build scripts)
```

### Files to Remove (Optional)
```
# These could be removed if replacing with compiled version
# But keeping them doesn't hurt
app/assets/stylesheets/bologna_theme.css (keep for now)
app/assets/stylesheets/brisbane_theme.css (keep for now)
```

---

## Risk Mitigation

### Risk 1: CSS Differences
**Likelihood**: Medium
**Impact**: High (visual differences)

**Mitigation**:
- Use visual regression testing
- Keep old CSS for comparison
- Test thoroughly before production

### Risk 2: Performance Regression
**Likelihood**: Low
**Impact**: High (user experience)

**Mitigation**:
- Monitor Core Web Vitals
- Prepare rollback plan
- Test with production data

### Risk 3: Per-Tenant Customization Broken
**Likelihood**: Low
**Impact**: High (customer-facing)

**Mitigation**:
- Test all customization variables
- Add automated tests for overrides
- Document variable changes

### Risk 4: Build Process Breaks
**Likelihood**: Medium
**Impact**: Medium (development friction)

**Mitigation**:
- Document build process clearly
- Add to CI/CD pipeline
- Create troubleshooting guide

### Risk 5: Theme Updates Forgotten
**Likelihood**: Medium
**Impact**: Low

**Mitigation**:
- Add pre-commit hook to rebuild CSS
- Document in CONTRIBUTING.md
- Automated CI check

---

## Commands Reference

### Build All Themes
```bash
npm run tailwind:build
```

### Build Single Theme
```bash
npm run tailwind:default
npm run tailwind:bologna
npm run tailwind:brisbane
```

### Watch for Changes (Development)
```bash
npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-default.css \
                --config tailwind.default.js \
                --watch
```

### Minify for Production
```bash
npx tailwindcss -i app/assets/stylesheets/tailwind-input.css \
                -o app/assets/stylesheets/tailwind-default.min.css \
                --minify \
                --config tailwind.default.js
```

### Analyze CSS Size
```bash
ls -lh app/assets/stylesheets/tailwind-*.css
gzip -c app/assets/stylesheets/tailwind-default.css | wc -c  # Gzipped size
```

---

## Estimated Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| 1. Preparation | 1 day | Analysis & metrics |
| 2. Setup Build | 1-2 days | Infrastructure |
| 3. Default Theme | 1-2 days | First full test |
| 4. Bologna & Brisbane | 2 days | Each theme |
| 5. Cleanup | 1 day | Optimization |
| 6. Testing | 2-3 days | QA & validation |
| 7. Deployment | 1 day | Production release |
| **Total** | **9-12 days** | Can be parallelized |

**With 2 developers**: 5-7 days
**With 3+ developers**: 3-4 days

---

## Success Metrics

### Technical Metrics
- ✅ All 3 themes building without errors
- ✅ No console errors on page load
- ✅ CSS file size < 150KB per theme (unminified)
- ✅ Network requests reduced by 1 (no CDN)
- ✅ Zero visual regressions

### Performance Metrics
- ✅ LCP improvement ≥ 10%
- ✅ CSS load time < 100ms
- ✅ JavaScript parsing reduced by 50%

### Functionality Metrics
- ✅ All existing tests pass
- ✅ Per-tenant customization works
- ✅ No user-reported issues after 1 week

---

## Post-Migration Improvements

After successful migration:

1. **Tree-shake unused utilities**
   - Reduce CSS by 20-30%
   - Add tailwindcss safelist for dynamic classes

2. **Consolidate theme CSS**
   - Combine with compiled Tailwind
   - Remove old static theme stylesheets

3. **Optimize Flowbite**
   - Compile with Tailwind instead of CDN
   - Share Tailwind config

4. **Implement CSS layers**
   - Better specificity control
   - Easier customization

5. **Add pre-commit hooks**
   - Auto-rebuild CSS before commits
   - Prevent stale files

---

## Questions & Support

If you need help during migration:

1. **Check existing Tailwind docs**: https://tailwindcss.com/docs
2. **Review code in this analysis**: `docs/claude_thoughts/`
3. **Test CSS variable behavior**: Check `_base_variables.css.erb`
4. **Consult theme configs**: `app/themes/*/views/layouts/`

---

**Document Version**: 1.0
**Last Updated**: 2025-12-17
**Status**: Ready for implementation
**Author**: Claude Code Analysis
