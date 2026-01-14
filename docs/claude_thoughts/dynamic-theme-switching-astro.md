# Dynamic Theme Switching in Astro Frontend

**Date**: 2026-01-13  
**Status**: Research & Planning  
**Related Error**: `Cannot find module '@/styles/themes/biarritz.css'`

## Executive Summary

This document analyzes options for implementing dynamic theme switching in the Astro frontend, balancing the need for **production performance** with **development flexibility** for theme experimentation.

**Recommendation**: Implement a **hybrid SSG/SSR system** where:
- Production pages are statically generated (maximum performance)
- Preview mode uses SSR with query parameters for dynamic theme switching
- No performance penalty in production

---

## Current State Analysis

### What Already Exists

1. **Theme-Specific Layouts** (`src/layouts/`)
   - `BrisbanePageLayout.astro`, `BarcelonaPageLayout.astro`, `BiarritzPageLayout.astro`, etc.
   - Each theme has its own layout, header, footer, and CSS
   - `ThemePageLayout.astro` acts as a router, selecting the correct theme layout

2. **Theme CSS Files** (`src/styles/themes/`)
   - `barcelona.css`, `biarritz.css`, `bologna.css`, `brisbane.css`, `brussels.css`
   - Each uses CSS custom properties for colors
   - Themes define typography, spacing, shadows, and component styles

3. **Partial Dynamic Support**
   - `BiarritzLayout.astro` already accepts `?palette_id=` and `?palette_preview=1`
   - Theme colors are fetched from Rails API via `getTheme()`
   - `ThemePaletteSelector.astro` component exists for color switching

4. **Theme API** (`src/lib/api/site.ts`)
   - `getTheme(options?)` fetches theme configuration from Rails
   - Supports `paletteId` parameter for palette switching

### Current Architecture Flow

```
URL Request
    │
    ▼
[locale]/[...slug].astro (catch-all route)
    │
    ▼
ThemePageLayout.astro
    │
    ├─► getTheme() API call
    │
    ▼
Switch on theme.name:
    ├─► 'brisbane'  → BrisbanePageLayout
    ├─► 'barcelona' → BarcelonaPageLayout  
    ├─► 'biarritz'  → BiarritzPageLayout
    ├─► 'bologna'   → BolognaPageLayout
    ├─► 'brussels'  → BrusselsPageLayout
    └─► default     → ThemeLayout + ThemeHeader/Footer
```

### The Immediate Error

The error `Cannot find module '@/styles/themes/biarritz.css'` is likely a Vite cache issue:
- `BiarritzLayout.astro` line 4 uses correct relative path: `../styles/themes/biarritz.css`
- The file exists at `src/styles/themes/biarritz.css`
- **Fix**: Clear `.astro` cache and restart dev server

---

## Theme Switching Complexity

### Why This Is Non-Trivial

Unlike simple color theming, PWB themes differ in:

| Aspect | Example Differences |
|--------|---------------------|
| **Layout Structure** | Brisbane has two-tier header; Barcelona has wave decoration |
| **Typography** | Biarritz uses Playfair Display; Brisbane uses Inter |
| **Component Styling** | Cards, buttons, forms styled differently per theme |
| **Header/Footer** | Each theme has custom header/footer components |
| **CSS Architecture** | Different shadow styles, border radii, animations |

This means **switching themes requires swapping entire component trees**, not just CSS variables.

---

## Architecture Options Analyzed

### Option 1: Build-Time Only (Current Approach)

**How it works**: Theme is determined by Rails API at build time. All pages pre-rendered with that theme.

| Pros | Cons |
|------|------|
| ✅ Maximum performance (static HTML) | ❌ Must rebuild to change themes |
| ✅ CDN cacheable | ❌ No runtime experimentation |
| ✅ Excellent Lighthouse scores | ❌ Slow iteration during design phase |

### Option 2: Fully Dynamic (Client-Side)

**How it works**: Load all theme CSS, switch via JavaScript on client.

| Pros | Cons |
|------|------|
| ✅ Instant switching | ❌ Large CSS bundle (all themes) |
| ✅ No server round-trip | ❌ Flash of Unstyled Content (FOUC) |
| | ❌ Can't swap layout components |
| | ❌ Poor Core Web Vitals |

### Option 3: Hybrid SSG/SSR (Recommended)

**How it works**:
- Default: Static generation (SSG) with configured theme
- Preview mode: Server-side rendering (SSR) with requested theme
- Query parameter triggers SSR mode

| Pros | Cons |
|------|------|
| ✅ Production performance maintained | ⚠️ Slightly more complex routing |
| ✅ Full theme switching in preview | ⚠️ Preview pages not cached |
| ✅ No FOUC | |
| ✅ Can swap entire component trees | |
| ✅ Works with Astro's hybrid mode | |

---

## Performance Analysis

### Measured/Expected Performance

| Rendering Mode | Time to First Byte | First Contentful Paint | Strategy |
|----------------|-------------------|------------------------|----------|
| **SSG (Static)** | ~50-100ms | ~200-400ms | Pre-built at edge CDN |
| **SSR (Dynamic)** | ~150-300ms | ~350-600ms | Server renders per request |
| **CSR (Client)** | ~50-100ms | ~500-800ms + FOUC | JS hydration required |

### Why SSR for Preview Mode?

1. **No FOUC**: HTML arrives fully styled
2. **Full Component Switching**: Can swap headers, footers, layouts
3. **SEO Preserved**: Search engines see complete page
4. **Acceptable Latency**: 200-400ms extra is fine for preview/experimentation
5. **No Bundle Bloat**: Only requested theme CSS is sent

---

## Detailed Implementation Plan

### Phase 1: Fix Immediate Issues (30 min)

#### Task 1.1: Clear Vite Cache
```bash
cd pwb-frontend-clients/pwb-astrojs-client
rm -rf node_modules/.vite
rm -rf .astro
npm run dev
```

#### Task 1.2: Verify All Theme CSS Imports
Check each theme layout uses correct import paths:
- `BrisbaneLayout.astro` → `../styles/themes/brisbane.css`
- `BarcelonaLayout.astro` → `../styles/themes/barcelona.css`
- etc.

### Phase 2: Enable Astro Hybrid Mode (1 hour)

#### Task 2.1: Update Astro Config

```javascript
// astro.config.mjs
export default defineConfig({
  output: 'hybrid', // Enable SSG + SSR hybrid
  adapter: node({ mode: 'standalone' }), // or your preferred adapter
  // ...
});
```

#### Task 2.2: Create Preview Detection Utility

```typescript
// src/lib/utils/preview.ts
export function isPreviewMode(url: URL): boolean {
  return url.searchParams.has('theme_preview') ||
         url.searchParams.has('theme');
}

export function getPreviewTheme(url: URL): string | null {
  return url.searchParams.get('theme') || null;
}
```

### Phase 3: Implement Theme Override System (2-3 hours)

#### Task 3.1: Update getTheme() to Accept Override

```typescript
// src/lib/api/site.ts
export async function getTheme(options?: {
  paletteId?: string;
  themeOverride?: string;  // NEW: Force specific theme
}): Promise<Theme> {
  const { paletteId, themeOverride } = options || {};

  // If theme override specified, fetch that theme's config
  if (themeOverride) {
    // Fetch theme by name from Rails API
    // Or return local theme defaults
  }

  // ... existing logic
}
```

#### Task 3.2: Create SSR-Enabled Preview Layout

```astro
---
// src/layouts/PreviewThemePageLayout.astro
export const prerender = false; // Force SSR for this layout

import { getTheme } from '@/lib/api/site';
import { getPreviewTheme } from '@/lib/utils/preview';

// Import all theme layouts
import BrisbanePageLayout from './BrisbanePageLayout.astro';
import BarcelonaPageLayout from './BarcelonaPageLayout.astro';
// ... etc

const requestedTheme = getPreviewTheme(Astro.url);
const theme = await getTheme({ themeOverride: requestedTheme });
const themeName = theme.name?.toLowerCase() || 'default';
---

<!-- Theme switcher UI for preview mode -->
<div class="fixed top-4 right-4 z-50 bg-white shadow-lg rounded-lg p-4">
  <label>Preview Theme:</label>
  <select onchange="window.location.search = '?theme=' + this.value">
    <option value="brisbane">Brisbane</option>
    <option value="barcelona">Barcelona</option>
    <option value="biarritz">Biarritz</option>
    <!-- etc -->
  </select>
</div>

{themeName === 'brisbane' ? (
  <BrisbanePageLayout {...Astro.props}><slot /></BrisbanePageLayout>
) : themeName === 'barcelona' ? (
  <!-- etc -->
)}
```

#### Task 3.3: Update Catch-All Route for Preview Detection

```astro
---
// src/pages/[locale]/[...slug].astro
import { isPreviewMode } from '@/lib/utils/preview';
import ThemePageLayout from '@/layouts/ThemePageLayout.astro';
import PreviewThemePageLayout from '@/layouts/PreviewThemePageLayout.astro';

// Determine if this is preview mode
const previewMode = isPreviewMode(Astro.url);

// Use appropriate layout
const Layout = previewMode ? PreviewThemePageLayout : ThemePageLayout;
---

<Layout {...props}>
  <!-- page content -->
</Layout>
```

### Phase 4: Theme Switcher UI Component (1-2 hours)

#### Task 4.1: Create ThemeSwitcher Component

```astro
---
// src/components/astro/preview/ThemeSwitcher.astro
interface Props {
  currentTheme: string;
}

const { currentTheme } = Astro.props;
const themes = ['brisbane', 'barcelona', 'biarritz', 'bologna', 'brussels', 'default'];
const currentUrl = Astro.url;
---

<div class="fixed bottom-4 right-4 z-[9999] bg-white/95 backdrop-blur
            shadow-2xl rounded-xl p-4 border border-gray-200
            font-sans text-sm" id="theme-switcher">
  <div class="flex items-center gap-3 mb-3">
    <span class="font-semibold text-gray-700">🎨 Theme Preview</span>
    <button onclick="document.getElementById('theme-switcher').remove()"
            class="text-gray-400 hover:text-gray-600">✕</button>
  </div>

  <div class="grid grid-cols-2 gap-2">
    {themes.map(theme => {
      const url = new URL(currentUrl);
      url.searchParams.set('theme', theme);
      return (
        <a href={url.toString()}
           class:list={[
             "px-3 py-2 rounded-lg text-center transition",
             theme === currentTheme
               ? "bg-blue-600 text-white"
               : "bg-gray-100 hover:bg-gray-200 text-gray-700"
           ]}>
          {theme.charAt(0).toUpperCase() + theme.slice(1)}
        </a>
      );
    })}
  </div>

  <div class="mt-3 pt-3 border-t border-gray-200 text-xs text-gray-500">
    Preview mode • <a href={currentUrl.pathname} class="underline">Exit preview</a>
  </div>
</div>
```

### Phase 5: Rails API Integration (Optional, 1-2 hours)

#### Task 5.1: Add Theme List Endpoint (if needed)

```ruby
# app/controllers/api/v1/themes_controller.rb
def index
  themes = [
    { name: 'brisbane', display_name: 'Brisbane', description: 'Luxury coastal' },
    { name: 'barcelona', display_name: 'Barcelona', description: 'Mediterranean warmth' },
    # ...
  ]
  render json: { themes: themes }
end
```

#### Task 5.2: Update Astro to Fetch Available Themes

```typescript
// src/lib/api/site.ts
export async function getAvailableThemes(): Promise<ThemeInfo[]> {
  const response = await fetch(`${API_BASE_URL}/api/v1/themes`);
  return response.json();
}
```

---

## File Changes Summary

| File | Action | Purpose |
|------|--------|---------|
| `astro.config.mjs` | Modify | Enable hybrid output mode |
| `src/lib/utils/preview.ts` | Create | Preview mode detection utilities |
| `src/lib/api/site.ts` | Modify | Add theme override support |
| `src/layouts/PreviewThemePageLayout.astro` | Create | SSR layout for preview mode |
| `src/components/astro/preview/ThemeSwitcher.astro` | Create | Theme selection UI |
| `src/pages/[locale]/[...slug].astro` | Modify | Route to preview layout when needed |

---

## Testing Plan

### Manual Testing
1. Visit `/en/home` → Should use static (SSG) rendering with default theme
2. Visit `/en/home?theme=barcelona` → Should SSR with Barcelona theme
3. Theme switcher should appear and allow cycling through themes
4. Removing `?theme=` param should return to static version

### Performance Testing
1. Run Lighthouse on production URL (no query params) → Target 90+ performance
2. Run Lighthouse on preview URL → Acceptable if 70+ performance
3. Verify no FOUC on theme switch

---

## Future Enhancements

1. **Persist Theme Choice**: Store selected theme in cookie/localStorage
2. **A/B Testing**: Randomly serve different themes to users
3. **Per-Page Themes**: Allow different themes for different page types
4. **Color Palette Live Editor**: Extend beyond theme switching to real-time color editing
5. **Theme Comparison Mode**: Side-by-side theme comparison view

---

## Appendix: Theme Component Inventory

### Per-Theme Components Required

| Theme | Layout | Header | Footer | CSS |
|-------|--------|--------|--------|-----|
| Brisbane | ✅ BrisbaneLayout | ✅ BrisbaneHeader | ✅ BrisbaneFooter | ✅ brisbane.css |
| Barcelona | ✅ BarcelonaLayout | ✅ BarcelonaHeader | ✅ BarcelonaFooter | ✅ barcelona.css |
| Biarritz | ✅ BiarritzLayout | ✅ BiarritzHeader | ✅ BiarritzFooter | ✅ biarritz.css |
| Bologna | ✅ BolognaLayout | ✅ BolognaHeader | ✅ BolognaFooter | ✅ bologna.css |
| Brussels | ✅ BrusselsLayout | ✅ BrusselsHeader | ✅ BrusselsFooter | ✅ brussels.css |
| Default | ✅ ThemeLayout | ✅ ThemeHeader | ✅ ThemeFooter | ✅ default.css |

### Shared Components (Theme-Agnostic)

- `PropertyCard.astro` - Uses CSS variables, works with any theme
- `PropertyGrid.astro` - Layout component, theme-agnostic
- `SearchFilters.astro` - Form component, inherits theme styles
- `Map.astro` - Third-party component, minimal styling

