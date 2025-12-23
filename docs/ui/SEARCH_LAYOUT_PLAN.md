# Search Page Layout: Implementation Plan

This document provides a detailed plan for ensuring search filters display beside search results on large screens across all themes, and preventing regressions in the future.

---

## Current Status

### Compliance Audit (December 2024)

| Theme | Buy Page | Rent Page | Status |
|-------|----------|-----------|--------|
| **default** | ✅ Compliant | ✅ Compliant | Filters beside results on lg+ |
| **brisbane** | ✅ Compliant | ✅ Compliant | Filters beside results on lg+ |
| **bologna** | ✅ Compliant | ✅ Compliant | Filters beside results on lg+ |

All themes currently implement the correct side-by-side layout pattern.

---

## Required Layout Pattern

### Desktop (≥1024px / lg breakpoint)

```
+--------------------------------------------------+
|  +------------+  +----------------------------+  |
|  | Sidebar    |  | Search Results             |  |
|  | Filters    |  | (3/4 width)                |  |
|  | (1/4)      |  |                            |  |
|  +------------+  +----------------------------+  |
+--------------------------------------------------+
```

### Required HTML/Tailwind Structure

```erb
<!-- Container with flex-wrap -->
<div class="flex flex-wrap -mx-4">

  <!-- Sidebar Filters (1/4 on desktop, full on mobile) -->
  <div class="w-full lg:w-1/4 px-4 mb-6 lg:mb-0">
    <!-- Mobile toggle button -->
    <button class="lg:hidden w-full ...">
      Filter Properties
    </button>

    <!-- Filter form (hidden on mobile, visible on desktop) -->
    <div id="sidebar-filters" class="hidden lg:block">
      <%= render 'pwb/searches/search_form_...' %>
    </div>
  </div>

  <!-- Search Results (3/4 on desktop, full on mobile) -->
  <div class="w-full lg:w-3/4 px-4">
    <div id="inmo-search-results">
      <%= render 'search_results' %>
    </div>
  </div>

</div>
```

### Critical Tailwind Classes

| Element | Classes | Purpose |
|---------|---------|---------|
| Container | `flex flex-wrap` | Enables side-by-side layout |
| Sidebar | `w-full lg:w-1/4` | 100% mobile, 25% desktop |
| Results | `w-full lg:w-3/4` | 100% mobile, 75% desktop |
| Filter toggle | `lg:hidden` | Only visible on mobile |
| Filter form wrapper | `hidden lg:block` | Hidden mobile, visible desktop |

---

## Implementation Checklist for New Themes

When creating a new theme with search pages, verify these requirements:

### 1. Page Structure
- [ ] Container uses `flex flex-wrap` (or `flex flex-col lg:flex-row`)
- [ ] Sidebar div has `w-full lg:w-1/4` classes
- [ ] Results div has `w-full lg:w-3/4` classes
- [ ] Both sidebar and results are direct children of flex container

### 2. Mobile Behavior
- [ ] Filter toggle button exists with `lg:hidden`
- [ ] Filter form wrapper has `hidden lg:block`
- [ ] Stimulus controller handles toggle (`data-controller="search-form"`)
- [ ] Results display full width on mobile

### 3. Desktop Behavior
- [ ] Filters visible without interaction (no toggle needed)
- [ ] Filters and results side-by-side (not stacked)
- [ ] Optional: Sticky sidebar with `sticky top-28`

### 4. Visual Testing
- [ ] Test at 1024px width (lg breakpoint boundary)
- [ ] Test at 1280px width (common desktop)
- [ ] Test at 768px width (tablet/mobile)
- [ ] Screenshot comparison with reference themes

---

## Prevention Measures

### 1. Documentation

**Reference:** `docs/ui/SEARCH_UI_SPECIFICATION.md`

The specification now includes explicit requirements:
- Section: "Responsive Layout Requirements"
- ASCII diagrams showing expected layout
- Required Tailwind class patterns
- Checkboxes for large screen responsiveness

### 2. Theme Creation Skill

When using the `theme-creation` skill, the generated search pages MUST follow the layout pattern documented above.

**Add to theme-creation skill instructions:**
```
Search Page Requirements:
- Filters MUST display beside results on lg+ screens
- Use `flex flex-wrap` container
- Sidebar: `w-full lg:w-1/4`
- Results: `w-full lg:w-3/4`
- Include mobile filter toggle
```

### 3. Code Review Checklist

Add to PR review process for search page changes:

```markdown
## Search Page Layout Review
- [ ] Verified filters beside results at lg+ breakpoint
- [ ] Tested at 1024px, 1280px, and 768px widths
- [ ] Mobile filter toggle works correctly
- [ ] Layout matches specification diagrams
```

### 4. Automated Testing (Future)

Consider adding Playwright tests:

```javascript
// tests/search-layout.spec.js
test('filters beside results on desktop', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/buy');

  const sidebar = page.locator('[data-testid="search-filters"]');
  const results = page.locator('[data-testid="search-results"]');

  const sidebarBox = await sidebar.boundingBox();
  const resultsBox = await results.boundingBox();

  // Filters should be to the left of results (not above)
  expect(sidebarBox.y).toBe(resultsBox.y); // Same vertical position
  expect(sidebarBox.x).toBeLessThan(resultsBox.x); // Sidebar on left
});
```

### 5. Visual Regression Testing (Future)

Configure Percy or similar for search page screenshots:
- Capture at mobile (375px), tablet (768px), desktop (1280px)
- Compare against baseline
- Alert on layout changes

---

## Fixing Non-Compliant Themes

If a theme is found to have filters above results on desktop:

### Step 1: Identify the Issue

```bash
# Search for layout classes in theme
grep -n "lg:w-1/4\|lg:w-3/4" app/themes/THEME_NAME/views/pwb/search/
```

### Step 2: Check Container

Ensure parent container has `flex flex-wrap` or `flex flex-col lg:flex-row`.

### Step 3: Fix Width Classes

Update sidebar and results divs:
```diff
- <div class="w-full">
+ <div class="w-full lg:w-1/4">
    <!-- filters -->
  </div>
- <div class="w-full">
+ <div class="w-full lg:w-3/4">
    <!-- results -->
  </div>
```

### Step 4: Test at Breakpoints

1. Open `/buy` page
2. Resize browser to 1024px width
3. Verify filters appear beside (not above) results
4. Resize to 768px, verify filters collapse

---

## Reference Implementation

### Default Theme (Canonical Example)

**File:** `app/themes/default/views/pwb/search/buy.html.erb`

Key structure (lines 40-70):
```erb
<div class="flex flex-wrap -mx-4">
  <div class="w-full lg:w-1/4 px-4 lg:order-last mb-6 lg:mb-0">
    <!-- Mobile toggle -->
    <button class="lg:hidden ...">Filter</button>
    <!-- Filter form -->
    <div id="sidebar-filters" class="hidden lg:block">
      <%= render 'pwb/searches/search_form_for_sale' %>
    </div>
  </div>
  <div class="w-full lg:w-3/4 px-4">
    <div id="inmo-search-results">
      <%= render 'search_results' %>
    </div>
  </div>
</div>
```

---

## Summary

| Action | Status | Owner |
|--------|--------|-------|
| Add explicit requirement to specification | ✅ Done | - |
| Audit existing themes | ✅ Done (all compliant) | - |
| Create implementation plan | ✅ Done | - |
| Update theme-creation skill | 📋 Recommended | Developer |
| Add to PR review checklist | 📋 Recommended | Team |
| Implement automated tests | 📋 Future | Developer |

---

**Document Version:** 1.0
**Created:** 2024-12-23
**Related:** `docs/ui/SEARCH_UI_SPECIFICATION.md`
