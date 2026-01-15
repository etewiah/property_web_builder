# Design Tokens System

PropertyWebBuilder uses a centralized design tokens system to ensure consistent styling across both Rails and Astro rendering pipelines.

## Overview

Design tokens are the single source of truth for colors, typography, spacing, and other visual properties. They are defined in JSON and automatically transformed into platform-specific CSS.

```
config/design/tokens.json     <-- Single source of truth
        │
        ▼
scripts/build-tokens.js        <-- Transforms tokens
        │
        ├──► Rails CSS (_tokens.css.erb)
        │
        └──► Astro CSS (tokens.css)
```

## Token Categories

| Category | Examples | Usage |
|----------|----------|-------|
| **Colors** | `primary`, `secondary`, `accent`, `background`, `text` | Brand colors, UI states |
| **Typography** | `fontFamily`, `fontSize`, `lineHeight`, `fontWeight` | Text styling |
| **Spacing** | `xs`, `sm`, `md`, `lg`, `xl` | Margins, padding, gaps |
| **Layout** | `container.maxWidth`, `container.padding` | Page structure |
| **Border Radius** | `sm`, `default`, `lg`, `full` | Component corners |
| **Shadows** | `sm`, `default`, `lg`, `inner` | Elevation effects |
| **Transitions** | `fast`, `normal`, `slow` | Animation timing |
| **Z-Index** | `dropdown`, `modal`, `tooltip` | Layering |

## File Locations

| File | Purpose |
|------|---------|
| `config/design/tokens.json` | Token definitions (DTCG format) |
| `scripts/build-tokens.js` | Build script |
| `app/views/pwb/custom_css/_tokens.css.erb` | Generated Rails CSS |
| `pwb-frontend-clients/pwb-astrojs-client/src/styles/tokens.css` | Generated Astro CSS |

## Usage

### Editing Tokens

1. Open `config/design/tokens.json`
2. Modify token values following the DTCG format:

```json
{
  "color": {
    "primary": {
      "$value": "#3b82f6",
      "$description": "Primary brand color",
      "$type": "color"
    }
  }
}
```

3. Regenerate CSS:

```bash
node scripts/build-tokens.js
```

### Using Tokens in Rails

Tokens are available as CSS custom properties with dynamic override support:

```erb
<%# The ERB file allows website.style_variables to override defaults %>
<div style="color: var(--pwb-color-primary);">
  Primary colored text
</div>
```

**Dynamic Overrides**: When a website has custom `style_variables`, they automatically override the token defaults.

### Using Tokens in Astro

Import the generated CSS in your global styles:

```css
/* In global.css */
@import './tokens.css';

/* Use tokens */
.my-component {
  color: var(--pwb-color-primary);
  font-family: var(--pwb-typography-font-family-primary);
  padding: var(--pwb-spacing-md);
}
```

The Astro tokens file also includes Tailwind v4 `@theme` mappings for utility classes:

```css
/* These work automatically */
<div class="text-pwb-primary bg-pwb-surface">
```

## Token Naming Convention

All tokens use the `--pwb-` prefix followed by category and name:

```
--pwb-{category}-{subcategory}-{name}

Examples:
--pwb-color-primary
--pwb-color-text-secondary
--pwb-typography-font-size-lg
--pwb-spacing-xl
--pwb-border-radius-default
```

## Adding New Tokens

1. Add to `tokens.json` with proper metadata:

```json
{
  "myCategory": {
    "myToken": {
      "$value": "value-here",
      "$description": "What this token is for",
      "$type": "color|dimension|fontFamily|number|shadow|duration"
    }
  }
}
```

2. Run the build script
3. The token will be available in both Rails and Astro

## Theming with Tokens

Website admins can override tokens via the admin panel. The Rails ERB template checks `@current_website.style_variables` for overrides:

```erb
--pwb-color-primary: <%= vars["color_primary"] || "#3b82f6" %>;
```

This allows per-tenant theming without modifying code.
