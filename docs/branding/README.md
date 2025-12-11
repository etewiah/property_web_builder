# PropertyWebBuilder Brand Guidelines

This document outlines the official brand guidelines for PropertyWebBuilder (PWB). These guidelines apply to the PWB platform itself, not to tenant websites which have their own customizable branding.

## Logo

### Concept

The PWB logo combines two core concepts:
- **House silhouette** (roof and wall) - representing "Property Web"
- **Code brackets `< />`** - representing "Builder" and web development

This visual metaphor communicates that PWB is a tool for building property websites.

### Logo Files

| File | Location | Usage |
|------|----------|-------|
| `icon.svg` | `/public/icon.svg` | Master vector logo (scalable) |
| `icon.png` | `/public/icon.png` | General use (192x192) |
| `favicon.ico` | `/public/favicon.ico` | Browser tab icon (multi-size) |

### Icon Sizes

All icons are located in `/public/icons/`:

| File | Size | Purpose |
|------|------|---------|
| `favicon-16x16.png` | 16x16 | Browser favicon (small) |
| `favicon-32x32.png` | 32x32 | Browser favicon (standard) |
| `favicon-48x48.png` | 48x48 | Browser favicon (high-DPI) |
| `apple-touch-icon.png` | 180x180 | iOS home screen |
| `icon-192.png` | 192x192 | Android/PWA icon |
| `icon-512.png` | 512x512 | PWA splash screen |

### Clear Space

Maintain a minimum clear space around the logo equal to the height of the house roof element.

### Minimum Size

- **Digital**: 32px minimum width
- **Print**: 12mm minimum width

---

## Color Palette

### Primary Colors

The primary brand color is a vibrant green, representing growth, success, and the "green light" to build.

| Name | Hex | RGB | Tailwind | Usage |
|------|-----|-----|----------|-------|
| **Primary Light** | `#4ADE80` | 74, 222, 128 | green-400 | Highlights, gradients |
| **Primary** | `#22C55E` | 34, 197, 94 | green-500 | Main brand color |
| **Primary Dark** | `#16A34A` | 22, 163, 74 | green-600 | Hover states, emphasis |

### Gradient

The signature PWB gradient flows from light to dark green:

```css
background: linear-gradient(135deg, #4ADE80 0%, #22C55E 50%, #16A34A 100%);
```

### Neutral Colors (Slate)

| Name | Hex | RGB | Tailwind | Usage |
|------|-----|-----|----------|-------|
| **Slate 50** | `#F8FAFC` | 248, 250, 252 | slate-50 | Page backgrounds |
| **Slate 200** | `#E2E8F0` | 226, 232, 240 | slate-200 | Borders, dividers |
| **Slate 500** | `#64748B` | 100, 116, 139 | slate-500 | Muted text |
| **Slate 600** | `#475569` | 71, 85, 105 | slate-600 | Secondary text, icons |
| **Slate 700** | `#334155` | 51, 65, 85 | slate-700 | Primary text |

### Semantic Colors

| Purpose | Color | Hex |
|---------|-------|-----|
| Success | Green | `#22C55E` |
| Warning | Amber | `#F59E0B` |
| Error | Red | `#EF4444` |
| Info | Blue | `#3B82F6` |

---

## Typography

### Font Stack

PWB uses system fonts for optimal performance and native feel:

```css
font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
             'Helvetica Neue', Arial, sans-serif;
```

For headings where a custom font is desired:
- **Primary**: Inter
- **Alternative**: Poppins, Manrope

### Type Scale

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| H1 | 2.25rem (36px) | 700 | 1.2 |
| H2 | 1.875rem (30px) | 600 | 1.3 |
| H3 | 1.5rem (24px) | 600 | 1.4 |
| H4 | 1.25rem (20px) | 600 | 1.4 |
| Body | 1rem (16px) | 400 | 1.6 |
| Small | 0.875rem (14px) | 400 | 1.5 |

---

## Design Elements

### Border Radius

PWB uses rounded corners throughout for a friendly, modern feel:

| Size | Value | Usage |
|------|-------|-------|
| Small | 6px | Buttons, inputs |
| Medium | 12px | Cards, panels |
| Large | 16px | Modals, feature cards |
| XL | 24px | Hero sections |

### Shadows

```css
/* Subtle */
box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

/* Default */
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.06);

/* Medium */
box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1), 0 2px 4px rgba(0, 0, 0, 0.06);

/* Large */
box-shadow: 0 10px 15px rgba(0, 0, 0, 0.1), 0 4px 6px rgba(0, 0, 0, 0.05);
```

### Spacing

Use an 8px base grid system:
- 4px (0.25rem) - Tight spacing
- 8px (0.5rem) - Default small
- 16px (1rem) - Default medium
- 24px (1.5rem) - Section gaps
- 32px (2rem) - Large gaps
- 48px (3rem) - Section padding

---

## UI Components

### Buttons

**Primary Button**
```css
background: linear-gradient(135deg, #4ADE80, #22C55E, #16A34A);
color: white;
border-radius: 8px;
padding: 10px 20px;
font-weight: 500;
```

**Secondary Button**
```css
background: #F8FAFC;
border: 1px solid #E2E8F0;
color: #334155;
border-radius: 8px;
padding: 10px 20px;
```

**Ghost Button**
```css
background: transparent;
color: #22C55E;
border-radius: 8px;
padding: 10px 20px;
```

### Cards

```css
background: white;
border: 1px solid #E2E8F0;
border-radius: 12px;
box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
padding: 24px;
```

### Form Inputs

```css
background: white;
border: 1px solid #E2E8F0;
border-radius: 6px;
padding: 10px 14px;
font-size: 16px;

/* Focus state */
border-color: #22C55E;
box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.1);
```

---

## Usage in HTML

### Favicon Implementation

Add these tags to your HTML `<head>`:

```html
<link rel="icon" type="image/svg+xml" href="/icon.svg">
<link rel="icon" type="image/png" sizes="32x32" href="/icons/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="16x16" href="/icons/favicon-16x16.png">
<link rel="apple-touch-icon" sizes="180x180" href="/icons/apple-touch-icon.png">
<link rel="manifest" href="/site.webmanifest">
<meta name="theme-color" content="#22C55E">
```

---

## Tenant Branding vs PWB Branding

**Important**: These brand guidelines apply to the PropertyWebBuilder platform itself (admin interface, documentation, marketing).

Tenant websites have their own independent branding controlled through:
- Theme settings
- Custom logos uploaded by tenants
- Style variables (colors, fonts)
- Custom CSS

The PWB favicon and icons serve as **defaults** when a tenant has not configured their own branding.

---

## Asset Generation

To regenerate icons from the master SVG:

```bash
# Requires librsvg (for SVG with gradients) and ImageMagick
# Install on macOS: brew install librsvg imagemagick
cd public

# Generate PNGs using rsvg-convert (handles gradients correctly)
rsvg-convert -w 16 -h 16 icon.svg -o icons/favicon-16x16.png
rsvg-convert -w 32 -h 32 icon.svg -o icons/favicon-32x32.png
rsvg-convert -w 48 -h 48 icon.svg -o icons/favicon-48x48.png
rsvg-convert -w 180 -h 180 icon.svg -o icons/apple-touch-icon.png
rsvg-convert -w 192 -h 192 icon.svg -o icons/icon-192.png
rsvg-convert -w 512 -h 512 icon.svg -o icons/icon-512.png
rsvg-convert -w 192 -h 192 icon.svg -o icon.png

# Generate favicon.ico (multi-size) using ImageMagick
magick icons/favicon-16x16.png icons/favicon-32x32.png icons/favicon-48x48.png favicon.ico
```

> **Note**: Use `rsvg-convert` instead of ImageMagick for SVG conversion as it properly handles SVG gradients and other advanced features.

---

## Contact

For brand-related questions or to request assets, please open an issue in the PropertyWebBuilder repository.
