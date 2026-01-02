# Brussels Theme Proposal for PropertyWebBuilder

**Date:** January 2025
**Source:** Visual audit of modern real estate websites
**Status:** Proposal

## Executive Summary

This document outlines a detailed plan to create a new "Brussels" theme for PropertyWebBuilder. The theme features a fresh, modern aesthetic with a distinctive lime green accent color, clean minimal design, and Material Design influences.

## 1. Visual Audit Summary

### Overall Design Characteristics

| Aspect | Description |
|--------|-------------|
| **Style** | Modern, clean, Mediterranean |
| **Primary Accent** | Lime/Yellow-Green (distinctive brand color) |
| **Layout** | Full-width hero, card-based property listings |
| **Typography** | Catamaran (sans-serif) - clean and modern |
| **Border Style** | Minimal borders, subtle shadows |
| **Border Radius** | Minimal (0-2px) - sharp, modern look |
| **Hero Style** | Full-width image with semi-transparent overlay |
| **Icons** | Material Symbols (Outlined) |

### Key Design Elements

1. **Distinctive lime green brand color** - Used for CTAs, buttons, and accents
2. **Full-width hero with integrated search** - Hero image with property search overlay
3. **Location-based navigation tiles** - Visual links to different areas
4. **Property cards with subtle shadows** - Clean cards with Material Design-style elevation
5. **Interactive map section** - Regional map with clickable areas
6. **Video integration** - Company profile video in "Why Us" section
7. **Multi-column footer** - Property type links and company info

## 2. Color Palette

### Primary Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Primary (Lime Green)** | `#9ACD32` | `rgb(154, 205, 50)` | CTAs, buttons, links, accents |
| **Primary Alt** | `#9FCB00` | `rgb(159, 203, 0)` | Navigation links, highlights |
| **Secondary (Dark Gray)** | `#131313` | `rgb(19, 19, 19)` | Header overlay, dark backgrounds |
| **Text Primary** | `#000000DE` | `rgba(0, 0, 0, 0.87)` | Body text |
| **Text Secondary** | `#00000089` | `rgba(0, 0, 0, 0.54)` | Muted text, captions |

### Background Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Background** | `#FAFAFA` | `rgb(250, 250, 250)` | Page background |
| **Surface** | `#FFFFFF` | `rgb(255, 255, 255)` | Cards, content areas |
| **Surface Alt** | `#F5F5F5` | `rgb(245, 245, 245)` | Alternate sections |
| **Header Overlay** | `#13131385` | `rgba(19, 19, 19, 0.52)` | Navigation bar |

### Footer Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Footer Background** | `#616161` | `rgb(97, 97, 97)` | Footer section |
| **Footer Text** | `#FFFFFF` | `rgb(255, 255, 255)` | Footer text and links |
| **Footer Text Muted** | `#FFFFFFB3` | `rgba(255, 255, 255, 0.7)` | Secondary footer text |

### Accent/Status Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Success** | `#9ACD32` | Same as primary (consistent brand) |
| **Error** | `#F44336` | Form errors, alerts |
| **Warning** | `#FF9800` | Warnings |
| **Info** | `#2196F3` | Information messages |

## 3. Typography

### Font Family

**Primary Font:** Catamaran (Google Fonts)

```css
@import url('https://fonts.googleapis.com/css2?family=Catamaran:wght@400;500;600;700&display=swap');

font-family: 'Catamaran', sans-serif;
```

### Type Scale

| Element | Size | Weight | Line Height |
|---------|------|--------|-------------|
| H1 | 24px | 400 | 1.2 |
| H2 | 24px | 400 | 1.2 |
| H3 | 20px | 700 | 1.3 |
| H4 | 16px | 600 | 1.4 |
| Body | 14px | 400 | 1.5 (21px) |
| Small | 12px | 400 | 1.5 |
| Button | 14px | 500 | 1.4 |
| Nav | 14px | 400 | 1.4 |

### Font Characteristics

- Clean, modern sans-serif
- Good readability at small sizes
- Works well for both headings and body text
- Supports multiple weights (400-700)

## 4. Component Specifications

### 4.1 Header/Navigation

```
+------------------------------------------------------------------+
| LOGO        NAV LINKS...        CALLBACK | FAVORITES | LANGUAGE  |
+------------------------------------------------------------------+
```

**Specifications:**
- **Background:** Semi-transparent dark overlay `rgba(19, 19, 19, 0.52)`
- **Text Color:** White `#FFFFFF`
- **Active Link Color:** Lime green `#9FCB00`
- **Height:** ~60px
- **Position:** Fixed/Sticky
- **Logo:** Left-aligned with brand name text

**Navigation Items:**
- Our Properties
- New Developments
- About Us
- Our Services
- Contact Us
- Request a CallBack (with phone icon)
- Favourites (with star icon)
- Language selector (flag + dropdown)

### 4.2 Hero Section

**Specifications:**
- **Height:** ~70vh (covers most of viewport)
- **Background:** Full-width property image
- **Overlay:** Semi-transparent for text readability
- **Search Form:** Overlaid on hero image
- **Location Tiles:** Below search, showing key areas

**Search Form Layout:**
```
+------------------------------------------------------------------+
|  [City ▼]  [Property Type ▼]  [Price From]  [Price To]  [Search] |
|  [Reference]  [Bedrooms ▼]  [Bathrooms ▼]  [Advanced Search →]   |
+------------------------------------------------------------------+
```

**Search Form Styling:**
- White background inputs
- Minimal borders
- Green search button
- Dropdown arrows using Material Symbols

### 4.3 Property Cards

**Specifications:**
- **Background:** White `#FFFFFF`
- **Border Radius:** 0px (sharp corners)
- **Shadow:** Material Design elevation
  ```css
  box-shadow:
    rgba(0, 0, 0, 0.2) 0px 3px 1px -2px,
    rgba(0, 0, 0, 0.14) 0px 2px 2px 0px,
    rgba(0, 0, 0, 0.12) 0px 1px 5px 0px;
  ```

**Card Layout:**
```
+------------------------+
|     [Property Image]   |
+------------------------+
| Title                  |
| Location               |
| € Price                |
+------------------------+
| 🛏 Beds | 🛁 Baths | 📐 m² |
+------------------------+
```

**Card Details:**
- Image with favorite button overlay
- Property type + location
- Price in green/prominent
- Feature icons: beds, baths, area
- Hover: subtle lift effect

### 4.4 Buttons

**Primary Button (Green CTA):**
```css
.btn-primary {
  background-color: #9ACD32;
  color: #FFFFFF;
  border-radius: 2px;
  padding: 8px 16px;
  font-weight: 500;
  text-transform: none;
}
```

**Secondary Button (Outline):**
```css
.btn-secondary {
  background-color: transparent;
  color: #9ACD32;
  border: 1px solid #9ACD32;
  border-radius: 2px;
}
```

### 4.5 Footer

**Three-Section Layout:**
```
+------------------------------------------------------------------+
| Apartment Types    | House Types      | Other Locations          |
| Ground Floor       | Detached Villas  | Benahavis Properties    |
| Middle Floor       | Semidetached     | Estepona Properties     |
| Top Floor          | Town Houses      | Marbella Properties     |
| Penthouse          | All Houses       | Mijas Properties        |
+------------------------------------------------------------------+
| © 2015-2025 Your Company | Contact | About | Cookie | Legal  |
| Address Line                  | Partner Logos                    |
+------------------------------------------------------------------+
```

**Footer Styling:**
- **Upper Section:** Gray background `#616161`
- **Lower Section:** Slightly darker
- **Text:** White with categorized links
- **Separators:** Horizontal lines between categories

## 5. Page Layouts

### 5.1 Homepage

1. **Header** - Fixed navigation with transparent-to-solid on scroll
2. **Hero** - Full-width image with search form overlay
3. **Location Tiles** - 5 area links with images
4. **CTA Banner** - "You have a property to sell?" with contact button
5. **Featured Properties** - Horizontal scrolling carousel
6. **Search by Map** - Interactive regional map
7. **Category Links** - "What are you looking for?" grid
8. **About Section** - "Why Choose Us?" with tabs
9. **Footer** - Multi-column with property type links

### 5.2 Property Listing Page

1. **Header**
2. **Breadcrumb**
3. **Filters Sidebar** (left, collapsible on mobile)
4. **Property Grid** (3-4 columns)
5. **Pagination**
6. **Footer**

### 5.3 Property Detail Page

1. **Header**
2. **Breadcrumb**
3. **Image Gallery** (main image + thumbnails)
4. **Property Title + Price**
5. **Key Features** (beds, baths, area)
6. **Description**
7. **Features List** (amenities)
8. **Location Map**
9. **Contact Form**
10. **Similar Properties**
11. **Footer**

## 6. Implementation Plan

### 6.1 File Structure

```
app/themes/brussels/
├── palettes/
│   ├── default.json          # Main lime green palette
│   ├── ocean_blue.json       # Blue variation
│   └── sunset_gold.json      # Gold variation
├── views/
│   ├── layouts/
│   │   └── pwb/
│   │       └── application.html.erb
│   ├── pwb/
│   │   ├── _header.html.erb
│   │   ├── _footer.html.erb
│   │   ├── welcome/
│   │   │   └── index.html.erb
│   │   ├── search/
│   │   │   ├── buy.html.erb
│   │   │   └── rent.html.erb
│   │   └── props/
│   │       └── show.html.erb
│   └── components/
│       ├── _property_card.html.erb
│       ├── _search_form.html.erb
│       └── _location_tiles.html.erb
└── page_parts/
    └── heroes/
        └── hero_search.liquid
```

### 6.2 Theme Configuration

Add to `app/themes/config.json`:

```json
{
  "name": "brussels",
  "friendly_name": "Brussels",
  "id": "brussels",
  "version": "1.0.0",
  "enabled": true,
  "parent_theme": "default",
  "description": "Modern clean theme with lime green accents and minimal design",
  "author": "PropertyWebBuilder",
  "tags": ["modern", "minimal", "green", "clean"],
  "supports": {
    "page_parts": [
      "heroes/hero_search",
      "heroes/hero_centered",
      "features/feature_grid_3col",
      "testimonials/testimonial_carousel",
      "cta/cta_banner"
    ],
    "layouts": ["default", "landing", "full_width"],
    "color_schemes": ["light"],
    "features": {
      "sticky_header": true,
      "back_to_top": true,
      "animations": true,
      "location_tiles": true,
      "map_search": true
    }
  }
}
```

### 6.3 Default Palette (brussels/palettes/default.json)

```json
{
  "id": "default",
  "name": "Lime Green",
  "description": "Fresh lime green - the signature Brussels look",
  "is_default": true,
  "preview_colors": ["#9ACD32", "#131313", "#616161"],
  "colors": {
    "primary_color": "#9ACD32",
    "secondary_color": "#131313",
    "accent_color": "#9FCB00",
    "background_color": "#FAFAFA",
    "text_color": "#000000DE",
    "header_background_color": "#13131385",
    "header_text_color": "#FFFFFF",
    "footer_background_color": "#616161",
    "footer_text_color": "#FFFFFF",
    "light_color": "#F5F5F5",
    "link_color": "#9ACD32",
    "action_color": "#9ACD32",
    "card_background_color": "#FFFFFF",
    "border_color": "#E0E0E0",
    "success_color": "#9ACD32",
    "error_color": "#F44336"
  }
}
```

### 6.4 Tailwind Configuration

Create `app/assets/stylesheets/tailwind-brussels.css`:

```css
@import "tailwindcss";

/* Catamaran font */
@import url('https://fonts.googleapis.com/css2?family=Catamaran:wght@400;500;600;700&display=swap');

@theme {
  /* Colors */
  --color-primary: var(--primary-color, #9ACD32);
  --color-secondary: var(--secondary-color, #131313);
  --color-accent: var(--accent-color, #9FCB00);

  /* Typography */
  --font-family-sans: 'Catamaran', system-ui, sans-serif;

  /* Minimal border radius */
  --radius: 2px;
  --radius-lg: 4px;
}

/* Material Design shadows */
@layer utilities {
  .shadow-card {
    box-shadow:
      rgba(0, 0, 0, 0.2) 0px 3px 1px -2px,
      rgba(0, 0, 0, 0.14) 0px 2px 2px 0px,
      rgba(0, 0, 0, 0.12) 0px 1px 5px 0px;
  }

  .shadow-card-hover {
    box-shadow:
      rgba(0, 0, 0, 0.2) 0px 5px 5px -3px,
      rgba(0, 0, 0, 0.14) 0px 8px 10px 1px,
      rgba(0, 0, 0, 0.12) 0px 3px 14px 2px;
  }
}

/* PWB utility classes */
@layer utilities {
  .bg-pwb-primary { background-color: var(--pwb-primary); }
  .bg-pwb-secondary { background-color: var(--pwb-secondary); }
  .text-pwb-primary { color: var(--pwb-primary); }
  .text-pwb-secondary { color: var(--pwb-secondary); }
  .border-pwb-primary { border-color: var(--pwb-primary); }
}
```

### 6.5 CSS Variables Partial

Create `app/views/pwb/custom_css/_brussels.css.erb`:

```erb
/* Theme: brussels */
<%
  styles = @current_website&.style_variables || {}

  primary_color = styles["primary_color"] || "#9ACD32"
  secondary_color = styles["secondary_color"] || "#131313"
  accent_color = styles["accent_color"] || "#9FCB00"
  background_color = styles["background_color"] || "#FAFAFA"
  text_color = styles["text_color"] || "rgba(0, 0, 0, 0.87)"
  header_bg = styles["header_background_color"] || "rgba(19, 19, 19, 0.52)"
  header_text = styles["header_text_color"] || "#FFFFFF"
  footer_bg = styles["footer_background_color"] || "#616161"
  footer_text = styles["footer_text_color"] || "#FFFFFF"
%>

<%= render partial: 'pwb/custom_css/base_variables',
           locals: {
             primary_color: primary_color,
             secondary_color: secondary_color,
             accent_color: accent_color,
             background_color: background_color,
             text_color: text_color,
             font_primary: "Catamaran",
             border_radius: "2px"
           } %>

:root {
  /* Brussels-specific variables */
  --br-header-bg: <%= header_bg %>;
  --br-header-text: <%= header_text %>;
  --br-footer-bg: <%= footer_bg %>;
  --br-footer-text: <%= footer_text %>;
  --br-text-muted: rgba(0, 0, 0, 0.54);
  --br-shadow-card: rgba(0, 0, 0, 0.2) 0px 3px 1px -2px, rgba(0, 0, 0, 0.14) 0px 2px 2px 0px, rgba(0, 0, 0, 0.12) 0px 1px 5px 0px;
}

/* Header styling */
.brussels-theme header,
.brussels-theme .site-header {
  background-color: var(--br-header-bg);
  color: var(--br-header-text);
}

.brussels-theme header a {
  color: var(--br-header-text);
}

.brussels-theme header a:hover,
.brussels-theme header a.active {
  color: var(--pwb-primary);
}

/* Footer styling */
.brussels-theme footer,
.brussels-theme .site-footer {
  background-color: var(--br-footer-bg);
  color: var(--br-footer-text);
}

.brussels-theme footer a {
  color: var(--br-footer-text);
}

.brussels-theme footer a:hover {
  color: var(--pwb-primary);
}

/* Property cards */
.brussels-theme .property-card {
  background: var(--pwb-bg-surface);
  box-shadow: var(--br-shadow-card);
  border-radius: 0;
  transition: box-shadow 0.2s ease, transform 0.2s ease;
}

.brussels-theme .property-card:hover {
  box-shadow: rgba(0, 0, 0, 0.2) 0px 5px 5px -3px, rgba(0, 0, 0, 0.14) 0px 8px 10px 1px, rgba(0, 0, 0, 0.12) 0px 3px 14px 2px;
  transform: translateY(-2px);
}

/* Buttons */
.brussels-theme .btn-primary,
.brussels-theme .pwb-btn--primary {
  background-color: var(--pwb-primary);
  color: #FFFFFF;
  border-radius: 2px;
  font-weight: 500;
}

.brussels-theme .btn-primary:hover {
  filter: brightness(1.1);
}

/* Search form */
.brussels-theme .search-form {
  background: rgba(255, 255, 255, 0.9);
  backdrop-filter: blur(10px);
}

.brussels-theme .search-form input,
.brussels-theme .search-form select {
  border-radius: 0;
  border: 1px solid #E0E0E0;
}

/* Raw CSS from admin */
<%= @current_website&.raw_css %>
```

## 7. WCAG Accessibility Compliance

### Contrast Ratios

| Combination | Ratio | Status |
|-------------|-------|--------|
| Primary (#9ACD32) on White | 2.3:1 | FAIL for text, OK for UI |
| Primary (#9ACD32) on Dark (#131313) | 7.4:1 | PASS AAA |
| White on Primary (#9ACD32) | 2.3:1 | FAIL for small text |
| Black (87%) on White | 12.6:1 | PASS AAA |
| White on Footer Gray (#616161) | 5.4:1 | PASS AA |

### Accessibility Recommendations

1. **Button Text:** Use dark text (#000000DE) on lime green buttons for better contrast
2. **Link Text:** Ensure lime green links have underlines or other indicators
3. **Focus States:** Add visible focus rings for keyboard navigation
4. **Alt Text:** Ensure all property images have descriptive alt text

### Required Fixes for WCAG AA

```css
/* Better contrast for primary buttons */
.brussels-theme .btn-primary {
  color: rgba(0, 0, 0, 0.87); /* Dark text on green */
}

/* Focus states */
.brussels-theme *:focus-visible {
  outline: 2px solid var(--pwb-primary);
  outline-offset: 2px;
}

/* Link indicators */
.brussels-theme a:not(.btn) {
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}
```

## 8. Implementation Checklist

### Phase 1: Foundation
- [ ] Add theme entry to `config.json`
- [ ] Create directory structure
- [ ] Create default palette JSON
- [ ] Create Tailwind input file
- [ ] Create CSS variables partial
- [ ] Add npm build scripts

### Phase 2: Core Templates
- [ ] Create layout file
- [ ] Create header partial
- [ ] Create footer partial
- [ ] Create property card component
- [ ] Create search form component

### Phase 3: Page Templates
- [ ] Homepage with hero search
- [ ] Property listing page
- [ ] Property detail page
- [ ] Contact page

### Phase 4: Special Features
- [ ] Location tiles component
- [ ] Map search section
- [ ] Property carousel
- [ ] Video integration

### Phase 5: Testing & Refinement
- [ ] WCAG accessibility audit
- [ ] Cross-browser testing
- [ ] Mobile responsiveness
- [ ] Performance optimization

## 9. Alternative Palettes

### Ocean Blue Palette

```json
{
  "id": "ocean_blue",
  "name": "Ocean Blue",
  "description": "Mediterranean blue variant",
  "colors": {
    "primary_color": "#2196F3",
    "secondary_color": "#0D47A1",
    "accent_color": "#03A9F4"
  }
}
```

### Sunset Gold Palette

```json
{
  "id": "sunset_gold",
  "name": "Sunset Gold",
  "description": "Warm golden Mediterranean variant",
  "colors": {
    "primary_color": "#FFA000",
    "secondary_color": "#5D4037",
    "accent_color": "#FFB300"
  }
}
```

## 10. References

- **Google Fonts:** https://fonts.google.com/specimen/Catamaran
- **Material Symbols:** https://fonts.google.com/icons
- **WCAG Contrast Checker:** https://webaim.org/resources/contrastchecker/

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Author:** Claude Code Theme Audit
