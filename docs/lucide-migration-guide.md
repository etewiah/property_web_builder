# Lucide Icons Migration Guide

**Date:** January 7, 2026
**Commit:** 98019c0a
**Status:** Complete

---

## Overview

PropertyWebBuilder has migrated from Material Symbols (font-based icons) to Lucide Icons (SVG-based). This change reduces icon asset size by 98% while maintaining the same API.

### Key Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Icon assets | 3.7 MB | 63 KB | **98% smaller** |
| Icon count | 162 allowed | 128 included | Optimized set |
| Loading | Font + ligatures | Inline SVG | Instant |
| FOUT risk | Yes | No | Better UX |

---

## What Changed

### Files Added
- `app/assets/images/icons/*.svg` - 128 Lucide SVG icons
- `app/assets/stylesheets/icons.css` - SVG icon styling
- `scripts/copy-lucide-icons.js` - Icon management script

### Files Modified
- `app/helpers/pwb/icon_helper.rb` - Renders inline SVG
- `app/lib/pwb/liquid_filters.rb` - SVG support for Liquid templates
- `spec/helpers/pwb/icon_helper_spec.rb` - Updated tests

### Files Removed
- `app/assets/fonts/material-symbols-subset.woff2` (3.7 MB)
- `app/assets/stylesheets/material-symbols-subset.css.erb`
- `app/assets/stylesheets/material-icons.css`
- `scripts/subset-material-symbols.js`

---

## Integration Steps

### 1. Include icons.css in Asset Pipeline

Add to your main stylesheet manifest or application layout:

```css
/* In application.css (Sprockets) */
*= require icons

/* Or in your SCSS */
@import "icons";
```

### 2. Update Layout (Remove Old CSS)

Remove any references to the old Material Symbols stylesheets:

```erb
<%# REMOVE these lines if present %>
<%= stylesheet_link_tag "material-symbols-subset" %>
<%= stylesheet_link_tag "material-icons" %>

<%# The icons.css should be included via your main stylesheet %>
```

### 3. Clear Asset Cache

After deployment, clear the asset cache:

```bash
# Development
rm -rf tmp/cache
rails assets:clobber

# Production
bundle exec rails assets:precompile
```

### 4. Optional: Remove material-symbols npm Package

If you no longer need the Material Symbols npm package:

```bash
npm uninstall material-symbols
```

---

## API Reference

### icon() Helper

The API remains unchanged:

```erb
<%# Basic usage %>
<%= icon(:home) %>
<%= icon(:search) %>

<%# With size %>
<%= icon(:menu, size: :sm) %>   <%# 18px %>
<%= icon(:menu, size: :md) %>   <%# 24px (default) %>
<%= icon(:menu, size: :lg) %>   <%# 36px %>

<%# With custom classes %>
<%= icon(:star, class: "text-yellow-500") %>

<%# Accessible icon with label %>
<%= icon(:warning, aria: { label: "Warning" }) %>

<%# Filled variant %>
<%= icon(:heart, filled: true) %>
```

### Size Classes

| Size | Class | Pixels |
|------|-------|--------|
| `:xs` | `icon-xs` | 14px |
| `:sm` | `icon-sm` | 18px |
| `:md` | `icon-md` | 24px |
| `:lg` | `icon-lg` | 36px |
| `:xl` | `icon-xl` | 48px |

### Liquid Templates

```liquid
{{ "home" | material_icon }}
{{ "search" | material_icon: "lg" }}
{{ page_part.icon.content | material_icon }}
```

### Brand Icons

Brand icons (Facebook, Instagram, etc.) still work:

```erb
<%= brand_icon(:facebook) %>
<%= social_icon_link(:twitter, "https://twitter.com/example") %>
```

---

## Icon Name Mapping

The helper automatically maps Material Symbols names to Lucide equivalents:

| Material Name | Lucide Name |
|--------------|-------------|
| `home` | `house` |
| `apartment` | `building` |
| `bed` | `bed` |
| `shower` | `shower-head` |
| `directions_car` | `car` |
| `location_on` | `map-pin` |
| `expand_more` | `chevron-down` |
| `close` | `x` |
| `search` | `search` |
| `email` | `mail` |
| `phone` | `phone` |
| `edit` | `pencil` |
| `delete` | `trash-2` |

See `ICON_MAP` in `app/helpers/pwb/icon_helper.rb` for the complete mapping.

### Legacy Aliases

Font Awesome and Phosphor icon names are still supported:

```erb
<%# These all work %>
<%= icon("fa-home") %>
<%= icon("fa fa-search") %>
<%= icon("ph-house") %>
<%= icon("ph ph-magnifying-glass") %>
```

---

## Adding New Icons

### 1. Check if Icon Exists in Lucide

Browse [lucide.dev/icons](https://lucide.dev/icons) to find the icon.

### 2. Add to copy-lucide-icons.js

Add the mapping to `scripts/copy-lucide-icons.js`:

```javascript
const ICON_MAP = {
  // ... existing mappings
  'your_material_name': 'lucide-icon-name',
};
```

### 3. Run the Copy Script

```bash
node scripts/copy-lucide-icons.js
```

### 4. Add to icon_helper.rb

Add to `ICON_MAP` in `app/helpers/pwb/icon_helper.rb`:

```ruby
ICON_MAP = {
  # ... existing mappings
  "your_material_name" => "lucide-icon-name",
}.freeze
```

### 5. Add to liquid_filters.rb

If the icon will be used in Liquid templates, also add it to `LUCIDE_MAP` in `app/lib/pwb/liquid_filters.rb`.

---

## Styling Icons

### With Tailwind CSS

```erb
<%= icon(:home, class: "w-6 h-6 text-blue-500") %>
<%= icon(:star, class: "w-8 h-8 text-yellow-400 fill-current") %>
```

### Custom CSS

```css
/* Size */
.icon { width: 1.5rem; height: 1.5rem; }

/* Color */
.icon { stroke: currentColor; }

/* Filled */
.icon-filled { fill: currentColor; stroke: none; }

/* Animation */
.icon-spin { animation: spin 1s linear infinite; }
```

### Color via Parent

Icons inherit color from their parent:

```erb
<span class="text-red-500">
  <%= icon(:warning) %>
</span>
```

---

## Troubleshooting

### Icons Not Showing

1. **Check CSS is loaded**: Ensure `icons.css` is in your stylesheet manifest
2. **Clear cache**: Run `rails assets:clobber && rm -rf tmp/cache`
3. **Check file exists**: Verify SVG file exists in `app/assets/images/icons/`

### Wrong Icon Displayed

Check the mapping in `ICON_MAP`:
- Material name might not be mapped
- Add the mapping to both `icon_helper.rb` and `liquid_filters.rb`

### Icon Too Large/Small

Use size classes or Tailwind utilities:

```erb
<%= icon(:home, size: :sm) %>
<%= icon(:home, class: "w-4 h-4") %>
```

### Missing Icon Error in Development

In development/test, unknown icons raise `ArgumentError`. Add the icon to:
1. `ICON_MAP` in `icon_helper.rb`
2. Download SVG to `app/assets/images/icons/`

---

## Performance Notes

### Why SVG is Better

1. **Smaller size**: 63KB vs 3.7MB
2. **No font loading**: Icons render immediately
3. **No FOUT**: Flash of Unstyled Text eliminated
4. **No ligature issues**: Direct SVG rendering is reliable
5. **Better caching**: SVGs are part of HTML, not separate requests

### Caching Considerations

- SVG icons are inlined in HTML (no separate requests)
- `icons.css` can be cached with other CSS
- No font file to cache/invalidate

---

## Migration from Other Icon Libraries

### From Font Awesome

```erb
<%# Before %>
<i class="fa fa-home"></i>
<i class="fas fa-search"></i>

<%# After %>
<%= icon(:home) %>
<%= icon(:search) %>
```

### From Phosphor Icons

```erb
<%# Before %>
<i class="ph ph-house"></i>
<i class="ph ph-magnifying-glass"></i>

<%# After %>
<%= icon(:home) %>
<%= icon(:search) %>
```

The legacy class names are automatically mapped.

---

## Files Reference

| File | Purpose |
|------|---------|
| `app/assets/images/icons/*.svg` | SVG icon files |
| `app/assets/stylesheets/icons.css` | Icon CSS classes |
| `app/helpers/pwb/icon_helper.rb` | Ruby helper for ERB |
| `app/lib/pwb/liquid_filters.rb` | Liquid template filter |
| `scripts/copy-lucide-icons.js` | Icon sync script |

---

## Related Documentation

- [Lucide Icons](https://lucide.dev/) - Icon library documentation
- [Material Symbols Analysis](./material-symbols-complete-analysis.md) - Why we migrated
- [Icon Helper Tests](../spec/helpers/pwb/icon_helper_spec.rb) - Usage examples

---

**Document Version:** 1.0
**Last Updated:** January 7, 2026
