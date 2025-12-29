# Page Parts Color System

This document describes the color system used in page_parts templates and how to maintain color consistency across themes.

## Overview

Page parts use a **semantic color system** that adapts to each tenant's color palette. Instead of hardcoded Tailwind colors (like `text-gray-900`), page parts use PWB semantic color classes that reference CSS custom properties.

## The PWB Color System

### Three Semantic Color Types

| Color Type | Purpose | CSS Variable | Replaces |
|------------|---------|--------------|----------|
| `pwb-primary` | Brand/theme primary color | `--pwb-primary` | `blue-*`, `indigo-*` |
| `pwb-secondary` | Neutral colors (text, backgrounds) | `--pwb-secondary` | `gray-*`, `slate-*`, `zinc-*` |
| `pwb-accent` | Highlights, CTAs, emphasis | `--pwb-accent` | `amber-*`, `orange-*` |

### Shade Scale (50-900)

Each color type supports a full shade scale:

```
50   -> Lightest (subtle backgrounds)
100  -> Very light
200  -> Light (card backgrounds)
300  -> Light-medium (borders)
400  -> Medium-light (secondary text)
500  -> Base shade
600  -> Medium-dark (body text)
700  -> Dark (headings)
800  -> Very dark
900  -> Darkest (dark backgrounds)
```

## Usage Guidelines

### Text Colors

```html
<!-- DO: Use PWB semantic colors -->
<h2 class="text-pwb-secondary-900">Heading</h2>
<p class="text-pwb-secondary-600">Body text</p>
<span class="text-pwb-primary">Accent link</span>

<!-- DON'T: Use hardcoded colors -->
<h2 class="text-gray-900">Heading</h2>
<p class="text-gray-600">Body text</p>
<span class="text-blue-600">Accent link</span>
```

### Background Colors

```html
<!-- DO: Use PWB semantic colors -->
<section class="bg-pwb-secondary-50">Light background</section>
<section class="bg-pwb-secondary-900">Dark background</section>
<button class="bg-pwb-primary">Primary button</button>

<!-- DON'T: Use hardcoded colors -->
<section class="bg-gray-50">Light background</section>
<section class="bg-gray-900">Dark background</section>
<button class="bg-blue-600">Primary button</button>
```

### Interactive States

```html
<!-- DO: Use PWB colors for hover/focus -->
<button class="bg-pwb-primary hover:bg-pwb-primary/90">
  Click me
</button>
<a class="text-pwb-primary hover:text-pwb-primary-700">
  Learn more
</a>
<input class="border-pwb-secondary-300 focus:border-pwb-primary focus:ring-pwb-primary">

<!-- DON'T: Mix hardcoded hover states -->
<button class="bg-pwb-primary hover:bg-blue-700">
  Click me
</button>
```

### Opacity Modifiers

Use Tailwind's opacity modifier syntax for transparency:

```html
<div class="bg-pwb-primary/90">90% opacity</div>
<div class="text-pwb-secondary-900/50">50% opacity text</div>
<div class="border-pwb-secondary-200/80">80% opacity border</div>
```

## Color Mapping Reference

### Converting Hardcoded Colors

When updating page_parts, use this mapping:

| Old (Hardcoded) | New (PWB Semantic) |
|-----------------|-------------------|
| `text-gray-900` | `text-pwb-secondary-900` |
| `text-gray-700` | `text-pwb-secondary-700` |
| `text-gray-600` | `text-pwb-secondary-600` |
| `text-gray-500` | `text-pwb-secondary-500` |
| `text-gray-400` | `text-pwb-secondary-400` |
| `bg-gray-50` | `bg-pwb-secondary-50` |
| `bg-gray-100` | `bg-pwb-secondary-100` |
| `bg-gray-200` | `bg-pwb-secondary-200` |
| `bg-gray-900` | `bg-pwb-secondary-900` |
| `border-gray-200` | `border-pwb-secondary-200` |
| `border-gray-300` | `border-pwb-secondary-300` |
| `text-blue-600` | `text-pwb-primary` |
| `bg-blue-600` | `bg-pwb-primary` |
| `text-amber-600` | `text-pwb-accent` |
| `bg-amber-500` | `bg-pwb-accent` |
| `text-primary` | `text-pwb-primary` |
| `bg-primary` | `bg-pwb-primary` |

## Contrast Guidelines

### Light Backgrounds (50-200)

Use dark text for readability:

```html
<section class="bg-pwb-secondary-50">
  <h2 class="text-pwb-secondary-900">Dark heading</h2>
  <p class="text-pwb-secondary-600">Dark body text</p>
</section>
```

### Dark Backgrounds (700-900)

Use white or very light text:

```html
<section class="bg-pwb-secondary-900">
  <h2 class="text-white">White heading</h2>
  <p class="text-pwb-secondary-300">Light body text</p>
  <span class="text-pwb-accent">Accent for highlights</span>
</section>
```

## Testing

The color system is enforced by automated tests in:

```
spec/views/themes/page_parts_colors_spec.rb
```

### Test Coverage

| Test | Description |
|------|-------------|
| No hardcoded gray colors | Fails if `text-gray-*`, `bg-gray-*` found |
| No hardcoded hover/focus | Fails if `hover:text-gray-*` etc. found |
| PWB colors used | Ensures files with colors use PWB system |
| Valid shade scales | Only 50-900 shades allowed |
| Valid opacity values | Opacity must be 0-100 |
| Contrast safety | Dark backgrounds have light text |
| All color types used | Primary, secondary, accent all present |
| Valid CSS syntax | No double spaces, unclosed brackets |
| Balanced Liquid | Matching if/endif, for/endfor pairs |

### Running Tests

```bash
# Run all page_parts color tests
bundle exec rspec spec/views/themes/page_parts_colors_spec.rb

# Run with documentation format
bundle exec rspec spec/views/themes/page_parts_colors_spec.rb --format documentation
```

## How Colors Are Applied

### 1. Palette Definition

Each theme defines colors in a palette JSON file:

```json
{
  "primary": "#3B82F6",
  "secondary": "#64748B",
  "accent": "#F59E0B"
}
```

### 2. CSS Variables

The palette colors become CSS custom properties:

```css
:root {
  --pwb-primary: #3B82F6;
  --pwb-secondary: #64748B;
  --pwb-accent: #F59E0B;
}
```

### 3. Shade Generation

Shades are generated using `color-mix()`:

```css
.bg-pwb-secondary-900 {
  background-color: color-mix(in srgb, var(--pwb-secondary) 40%, black);
}

.bg-pwb-secondary-50 {
  background-color: color-mix(in srgb, var(--pwb-secondary) 10%, white);
}
```

### 4. Template Usage

Page parts reference the semantic classes:

```liquid
<section class="bg-pwb-secondary-50 py-16">
  <h2 class="text-pwb-secondary-900">{{ page_part["title"]["content"] }}</h2>
</section>
```

## Adding New Page Parts

When creating new page parts:

1. **Never use hardcoded Tailwind colors** - Always use `pwb-primary`, `pwb-secondary`, or `pwb-accent`

2. **Follow the shade scale convention**:
   - Headings: `text-pwb-secondary-900`
   - Body text: `text-pwb-secondary-600` or `text-pwb-secondary-700`
   - Secondary text: `text-pwb-secondary-500` or `text-pwb-secondary-400`
   - Light backgrounds: `bg-pwb-secondary-50` or `bg-pwb-secondary-100`
   - Dark backgrounds: `bg-pwb-secondary-900` (use `text-white`)
   - CTAs/buttons: `bg-pwb-primary` with `text-white`
   - Highlights: `text-pwb-accent` or `bg-pwb-accent`

3. **Test your changes**:
   ```bash
   bundle exec rspec spec/views/themes/page_parts_colors_spec.rb
   ```

4. **Verify visually** across different theme palettes

## Troubleshooting

### "White on white" or invisible text

**Cause**: CSS variable mismatch or missing utility class definition.

**Fix**: Ensure `tailwind-input.css` defines the utility class and uses correct variable names (e.g., `--pwb-secondary` not `--pwb-secondary-color`).

### Tests failing with "hardcoded color" violations

**Cause**: Using `text-gray-*` instead of `text-pwb-secondary-*`.

**Fix**: Replace all hardcoded colors using the mapping table above.

### Colors not changing with palette

**Cause**: Page part using hardcoded colors instead of PWB semantic colors.

**Fix**: Audit the page part template and replace hardcoded colors.

## Related Files

- `app/assets/stylesheets/tailwind-input.css` - PWB utility class definitions
- `app/views/pwb/custom_css/_base_variables.css.erb` - CSS variable generation
- `spec/views/themes/page_parts_colors_spec.rb` - Color system tests
- `spec/views/themes/css_utilities_spec.rb` - CSS utility tests
- `db/yml_seeds/page_parts/*.yml` - Page part templates

## Changelog

- **2024-12-29**: Initial documentation
  - Converted all page_parts to PWB semantic color system
  - Added comprehensive test coverage
  - Documented color mapping and usage guidelines
