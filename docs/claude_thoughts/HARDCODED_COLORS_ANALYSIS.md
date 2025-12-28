# Hardcoded Colors Analysis - PropertyWebBuilder Themes

## Executive Summary

This document details all hardcoded colors found in theme view files across the PropertyWebBuilder project. The analysis covers 5 themes: default, bologna, brisbane, barcelona, and biarritz.

**Key Finding:** All hardcoded colors are currently found in inline styles and tailwind color classes. Most theme-specific colors use CSS variables which is GOOD. However, there are several instances where inline hex colors and hardcoded color names are used in footer components.

---

## Theme-by-Theme Analysis

### 1. DEFAULT THEME

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/default/`

#### Header (_header.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Notes |
|------|-----------------|------|---------|-------|-------|
| 2 | `bg-gray-800` | Tailwind class | Top bar background | Not theme-specific | Part of Tailwind default palette |
| 3 | `text-white` | Tailwind class | Top bar text | Not theme-specific | Using Tailwind standard |
| 18 | `bg-blue-600` | Tailwind class | Language selector active | Not theme-specific | Should use CSS variable |
| 19 | `hover:bg-gray-700` | Tailwind class | Language selector hover | Not theme-specific | Should use CSS variable |
| 24 | `bg-white` | Tailwind class | Nav background | Not theme-specific | Correct for default |
| 24 | `border-gray-200` | Tailwind class | Nav border | Not theme-specific | Correct for default |
| 28 | `text-gray-800` | Tailwind class | Logo text | Not theme-specific | Correct for default |
| 56 | `text-blue-600` | Tailwind class | Active nav link | Not theme-specific | Should use variable |
| 57 | `text-gray-700` | Tailwind class | Inactive nav link | Not theme-specific | Correct for default |
| 60 | `hover:text-blue-600` | Tailwind class | Nav hover | Not theme-specific | Should use variable |

#### Footer (_footer.html.erb)

No hardcoded colors found - all styling is done with semantic classes.

#### Shared CSS Variables (`_default.css.erb`)

CSS Variables defined:
- `--primary-color: #3b82f6` (Blue)
- `--secondary-color: #1e40af` (Dark Blue)
- `--services-bg-color: #f9fafb` (Light Gray)
- `--services-card-bg: #ffffff` (White)
- `--services-text-color: #1f2937` (Dark Gray)

These are appropriate defaults and are used via CSS variables.

---

### 2. BOLOGNA THEME

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/bologna/`

#### Header (_header.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 13 | `from-terra-400 to-terra-600` | Tailwind classes | Logo icon gradient | Theme-specific | Uses CSS variables - GOOD |
| 20 | `text-terra-600` | Tailwind class | Logo text color | Theme-specific | Uses CSS variables - GOOD |
| 32 | `text-terra-600` | Tailwind class | Nav hover text | Theme-specific | Uses CSS variables - GOOD |
| 33 | `hover:bg-terra-50` | Tailwind class | Nav hover bg | Theme-specific | Uses CSS variables - GOOD |
| 52 | `text-terra-600` | Tailwind class | Language active | Theme-specific | Uses CSS variables - GOOD |
| 53 | `bg-terra-50` | Tailwind class | Language bg | Theme-specific | Uses CSS variables - GOOD |
| 73 | `text-terra-600` | Tailwind class | User icon | Theme-specific | Uses CSS variables - GOOD |
| 87 | `text-terra-600` | Tailwind class | Sign out link | Theme-specific | Uses CSS variables - GOOD |
| 98 | `hover:bg-terra-200` | Tailwind class | Mobile btn hover | Theme-specific | Uses CSS variables - GOOD |

#### Footer (_footer.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 1 | `style="background-color: var(--bologna-light);"` | CSS variable | Wave divider bg | Correct | Using CSS variable - GOOD |
| 7 | `style="fill: var(--footer-bg-color);"` | CSS variable | Wave svg fill | Correct | Using CSS variable - GOOD |
| 9 | `style="background-color: var(--footer-bg-color); color: var(--footer-text-color);"` | CSS variables | Footer background & text | Correct | Using CSS variables - GOOD |
| 38 | `from-terra-400 to-terra-600` | Tailwind classes | Logo icon gradient | Theme-specific | Uses CSS variables - GOOD |
| 45 | `text-warm-gray-400` | Tailwind class | Description text | Theme-specific | Uses CSS variables - GOOD |
| 51 | `bg-warm-gray-800` | Tailwind class | Social icon bg | Theme-specific | Uses CSS variables - GOOD |
| 52 | `hover:bg-terra-500` | Tailwind class | Social hover | Theme-specific | Uses CSS variables - GOOD |
| 56 | `text-terra-400` | Tailwind class | Icon color | Theme-specific | Uses CSS variables - GOOD |
| 79 | `hover:text-terra-400` | Tailwind class | Link hover | Theme-specific | Uses CSS variables - GOOD |
| 107 | `hover:bg-terra-500` | Tailwind class | Contact icon hover | Theme-specific | Uses CSS variables - GOOD |
| 108 | `text-terra-400` | Tailwind class | Contact icon | Theme-specific | Uses CSS variables - GOOD |
| 144 | `bg-gradient-to-r from-terra-500 to-terra-600` | Tailwind classes | Button gradient | Theme-specific | Uses CSS variables - GOOD |
| 146 | `hover:from-terra-600 hover:to-terra-700` | Tailwind classes | Button hover gradient | Theme-specific | Uses CSS variables - GOOD |
| 175 | `border-warm-gray-800` | Tailwind class | Divider border | Theme-specific | Uses CSS variables - GOOD |
| 188 | `color: #d98e6e;` | Inline hex color | Footer content link | HARDCODED | Should use CSS variable |
| 190 | `color: #e7b5a0;` | Inline hex color | Footer link hover | HARDCODED | Should use CSS variable |

**Issues Found in Bologna:**
1. **Footer custom content styles** (lines 188-190) use hardcoded hex colors `#d98e6e` and `#e7b5a0` for footer links instead of CSS variables

#### CSS Variables (`_bologna.css.erb`)

Defined:
- `--bologna-terra: #c45d3e` (Terracotta)
- `--bologna-terra-400: #d98e6e` (lighter variant)
- `--bologna-terra-500: same as terra`
- `--bologna-terra-600: #b14a2e` (darker variant)
- `--bologna-olive: #5c6b4d` (Olive)
- `--bologna-sand: #d4a574` (Sand)
- `--bologna-warm-gray: #3d3d3d` (Warm Gray)
- `--bologna-light: #faf9f7` (Light)
- `--footer-bg-color: #3d3d3d` (Footer background)
- `--footer-text-color: #d5d0c8` (Footer text)

**These colors are available but not used in the hardcoded inline styles.**

---

### 3. BRISBANE THEME

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/brisbane/`

#### Header (_header.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 2 | `bg-luxury-navy` | Tailwind class | Top bar bg | Theme-specific | Uses CSS variable - GOOD |
| 3 | `text-luxury-cream` | Tailwind class | Top bar text | Theme-specific | Uses CSS variable - GOOD |
| 5 | `text-luxury-gold` | Tailwind class | Icon color | Theme-specific | Uses CSS variable - GOOD |
| 7 | `border-luxury-gold/20` | Tailwind class | Border with opacity | Theme-specific | Uses CSS variable - GOOD |
| 25 | `text-luxury-gold` | Tailwind class | Language active | Theme-specific | Uses CSS variable - GOOD |
| 26 | `border-luxury-gold` | Tailwind class | Language border | Theme-specific | Uses CSS variable - GOOD |
| 33 | `text-luxury-cream/70` | Tailwind class | Language inactive | Theme-specific | Uses CSS variable - GOOD |
| 44 | `bg-white` | Tailwind class | Nav background | Not theme-specific | OK for luxury theme |
| 45 | `border-luxury-navy/5` | Tailwind class | Nav border | Theme-specific | Uses CSS variable - GOOD |
| 56 | `text-luxury-navy` | Tailwind class | Logo text | Theme-specific | Uses CSS variable - GOOD |
| 73 | `text-luxury-navy` | Tailwind class | Mobile menu button | Theme-specific | Uses CSS variable - GOOD |
| 74 | `hover:text-luxury-gold` | Tailwind class | Button hover | Theme-specific | Uses CSS variable - GOOD |
| 84 | `bg-blue-600` | Tailwind class | Nav link active bg | HARDCODED | Should use theme variable |
| 88 | `text-blue-600` | Tailwind class | Nav link active text | HARDCODED | Should use theme variable |
| 90 | `hover:text-blue-600` | Tailwind class | Nav link hover | HARDCODED | Should use theme variable |
| 101 | `border-gray-200` | Tailwind class | User dropdown border | HARDCODED | Should use theme variable |
| 104 | `hover:bg-gray-100` | Tailwind class | Dropdown hover | HARDCODED | Should use theme variable |

**Issue:** Lines 84, 88, 90 use `bg-blue-600` and `text-blue-600` instead of theme colors.

#### Footer (_footer.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 2 | `bg-luxury-navy` | Tailwind class | Footer bg | Theme-specific | Uses CSS variable - GOOD |
| 3 | `text-luxury-cream/90` | Tailwind class | Footer text | Theme-specific | Uses CSS variable - GOOD |
| 17 | `opacity-90` | Tailwind class | Logo opacity | Not color-related | Fine |
| 29 | `text-luxury-cream/70` | Tailwind class | Description text | Theme-specific | Uses CSS variable - GOOD |
| 35 | `border-luxury-gold/30` | Tailwind class | Social icon border | Theme-specific | Uses CSS variable - GOOD |
| 36 | `text-luxury-cream/70` | Tailwind class | Icon text | Theme-specific | Uses CSS variable - GOOD |
| 37 | `hover:text-luxury-gold` | Tailwind class | Icon hover text | Theme-specific | Uses CSS variable - GOOD |
| 38 | `hover:border-luxury-gold` | Tailwind class | Border hover | Theme-specific | Uses CSS variable - GOOD |
| 78 | `text-luxury-gold` | Tailwind class | Section title | Theme-specific | Uses CSS variable - GOOD |
| 81 | `text-luxury-cream/80` | Tailwind class | Link text | Theme-specific | Uses CSS variable - GOOD |
| 82 | `hover:text-luxury-gold` | Tailwind class | Link hover | Theme-specific | Uses CSS variable - GOOD |
| 120 | `bg-luxury-gold` | Tailwind class | Button bg | Theme-specific | Uses CSS variable - GOOD |
| 121 | `text-luxury-navy` | Tailwind class | Button text | Theme-specific | Uses CSS variable - GOOD |
| 122 | `hover:bg-luxury-cream` | Tailwind class | Button hover | Theme-specific | Uses CSS variable - GOOD |
| 130 | `border-luxury-gold/10` | Tailwind class | Divider border | Theme-specific | Uses CSS variable - GOOD |
| 137 | `text-luxury-cream/50` | Tailwind class | Copyright text | Theme-specific | Uses CSS variable - GOOD |
| 143 | `color: #c9a962;` | Inline hex color | Footer content link | HARDCODED | Should use CSS variable |
| 145 | `color: #e7b5a0;` | Inline hex color | Footer link hover | HARDCODED | MISMATCH - wrong color! |

**Critical Issue:** Line 145 has wrong color for hover state - uses `#e7b5a0` (terra color) instead of a gold variant.

#### CSS Variables (`_brisbane.css.erb`)

Defined:
- `--brisbane-gold: #c9a962` (Gold)
- `--brisbane-navy: #1a1a2e` (Navy)
- `--brisbane-accent: #16213e` (Dark accent)
- `--brisbane-cream: #fafafa` (Cream)
- `--brisbane-charcoal: #2d2d2d` (Charcoal)
- `--brisbane-pearl: #fafafa` (Pearl)
- `--footer-bg-color: #1a1a2e` (Footer background)
- `--footer-text-color: #e8e8e8` (Footer text)

---

### 4. BARCELONA THEME

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/barcelona/`

#### Header (_header.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 13 | `from-med-400 to-med-600` | Tailwind classes | Logo icon gradient | Theme-specific | Uses CSS variables - GOOD |
| 20 | `text-warm-900` | Tailwind class | Logo text | Theme-specific | Uses CSS variables - GOOD |
| 27 | `text-warm-900` | Tailwind class | Nav link text | Theme-specific | Uses CSS variables - GOOD |
| 28 | `hover:text-med-600` | Tailwind class | Nav hover text | Theme-specific | Uses CSS variables - GOOD |
| 29 | `hover:bg-med-50` | Tailwind class | Nav hover bg | Theme-specific | Uses CSS variables - GOOD |
| 48 | `text-warm-700` | Tailwind class | Language button | Theme-specific | Uses CSS variables - GOOD |
| 49 | `hover:text-med-600` | Tailwind class | Language hover | Theme-specific | Uses CSS variables - GOOD |
| 51 | `bg-med-50` | Tailwind class | Language active bg | Theme-specific | Uses CSS variables - GOOD |
| 52 | `text-med-600` | Tailwind class | Language active text | Theme-specific | Uses CSS variables - GOOD |
| 65 | `bg-med-100` | Tailwind class | User icon bg | Theme-specific | Uses CSS variables - GOOD |
| 66 | `text-med-600` | Tailwind class | User icon text | Theme-specific | Uses CSS variables - GOOD |
| 70 | `border-warm-100` | Tailwind class | Dropdown border | Theme-specific | Uses CSS variables - GOOD |
| 73 | `hover:bg-med-50` | Tailwind class | Dropdown hover | Theme-specific | Uses CSS variables - GOOD |
| 74 | `hover:text-med-600` | Tailwind class | Dropdown hover text | Theme-specific | Uses CSS variables - GOOD |

#### Footer (_footer.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 3 | `from-med-800 to-med-900` | Tailwind classes | Footer bg gradient | Theme-specific | Uses CSS variables - GOOD |
| 4 | `text-warm-200` | Tailwind class | Footer text | Theme-specific | Uses CSS variables - GOOD |
| 7 | `text-warm-50` | Tailwind class | Wave color | Theme-specific | Uses CSS variables - GOOD |
| 24 | `from-gold-400 to-gold-500` | Tailwind classes | Logo icon gradient | Theme-specific | Uses CSS variables - GOOD |
| 31 | `text-med-200` | Tailwind class | Description text | Theme-specific | Uses CSS variables - GOOD |
| 37 | `bg-med-700` | Tailwind class | Social icon bg | Theme-specific | Uses CSS variables - GOOD |
| 38 | `text-med-300` | Tailwind class | Icon color | Theme-specific | Uses CSS variables - GOOD |
| 39 | `hover:bg-gold-500` | Tailwind class | Icon hover bg | Theme-specific | Uses CSS variables - GOOD |
| 40 | `hover:text-med-900` | Tailwind class | Icon hover text | Theme-specific | Uses CSS variables - GOOD |
| 63 | `text-med-300` | Tailwind class | Link text | Theme-specific | Uses CSS variables - GOOD |
| 64 | `hover:text-gold-400` | Tailwind class | Link hover | Theme-specific | Uses CSS variables - GOOD |
| 90 | `bg-med-700` | Tailwind class | Contact icon bg | Theme-specific | Uses CSS variables - GOOD |
| 91 | `group-hover:bg-gold-500/20` | Tailwind class | Icon hover bg opacity | Theme-specific | Uses CSS variables - GOOD |
| 92 | `text-gold-400` | Tailwind class | Icon color | Theme-specific | Uses CSS variables - GOOD |
| 128 | `bg-med-700` | Tailwind class | Input bg | Theme-specific | Uses CSS variables - GOOD |
| 129 | `text-white` | Tailwind class | Input text | Not theme-specific | OK |
| 130 | `placeholder-med-400` | Tailwind class | Placeholder color | Theme-specific | Uses CSS variables - GOOD |
| 131 | `focus:ring-gold-400` | Tailwind class | Focus ring | Theme-specific | Uses CSS variables - GOOD |
| 135 | `from-gold-400 to-gold-500` | Tailwind classes | Button gradient | Theme-specific | Uses CSS variables - GOOD |
| 136 | `text-med-900` | Tailwind class | Button text | Theme-specific | Uses CSS variables - GOOD |
| 137 | `hover:from-gold-500 hover:to-gold-600` | Tailwind classes | Button hover gradient | Theme-specific | Uses CSS variables - GOOD |
| 149 | `border-med-700` | Tailwind class | Divider border | Theme-specific | Uses CSS variables - GOOD |
| 158 | `text-med-400` | Tailwind class | Copyright text | Theme-specific | Uses CSS variables - GOOD |
| 163 | `text-gold-400` | Tailwind class | Link text | Theme-specific | Uses CSS variables - GOOD |
| 164 | `hover:text-gold-300` | Tailwind class | Link hover | Theme-specific | Uses CSS variables - GOOD |
| 172 | `color: #E5B45A;` | Inline hex color | Footer content link | HARDCODED | Should use CSS variable |
| 174 | `color: #fde047;` | Inline hex color | Footer link hover | HARDCODED | Should use CSS variable |

**Issues Found in Barcelona:**
1. **Footer custom content styles** (lines 172-174) use hardcoded hex colors `#E5B45A` and `#fde047` for footer links

#### CSS Variables (`_barcelona.css.erb`)

Defined in CSS file but not yet exported. The custom CSS contains values but they could be better defined.

---

### 5. BIARRITZ THEME

**Location:** `/Users/etewiah/dev/sites-older/property_web_builder/app/themes/biarritz/`

#### Header (_header.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 3 | `bg-[#082F49]` | Inline hex | Top bar background | HARDCODED | Should use CSS variable |
| 3 | `text-white` | Tailwind class | Top bar text | Not theme-specific | OK |
| 5 | `border-[#0C4A6E]` | Inline hex | Border color | HARDCODED | Should use CSS variable |
| 12 | `hover:text-[#FEF3C7]` | Inline hex | Hover text color | HARDCODED | Should use CSS variable |
| 18 | `bg-[#0C4A6E]` | Inline hex | Phone icon bg | HARDCODED | Should use CSS variable |
| 19 | `group-hover:bg-[#D97706]` | Inline hex | Icon hover bg | HARDCODED | Should use CSS variable |
| 27 | `hover:text-[#FEF3C7]` | Inline hex | Hover text | HARDCODED | Should use CSS variable |
| 38 | `bg-[#0C4A6E]` | Inline hex | Email icon bg | HARDCODED | Should use CSS variable |
| 39 | `group-hover:bg-[#D97706]` | Inline hex | Icon hover bg | HARDCODED | Should use CSS variable |
| 49 | `bg-[#D97706]` | Inline hex | Selected lang bg | HARDCODED | Should use CSS variable |
| 50 | `text-white` | Tailwind class | Selected lang text | Not theme-specific | OK |
| 51 | `hover:bg-[#0C4A6E]` | Inline hex | Lang hover | HARDCODED | Should use CSS variable |
| 57 | `text-[#FEF3C7]` | Inline hex | Hover text | HARDCODED | Should use CSS variable |

#### Navigation (_header.html.erb continued)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 71 | `bg-white` | Tailwind class | Nav background | Not theme-specific | Could use variable |
| 71 | `border-[#D97706]` | Inline hex | Bottom border | HARDCODED | Should use CSS variable |
| 84 | `bg-[#0369A1]` | Inline hex | Icon bg | HARDCODED | Should use CSS variable |
| 85 | `text-white` | Tailwind class | Icon color | Not theme-specific | OK |
| 91 | `text-[#1C1917]` | Inline hex | Logo text | HARDCODED | Should use CSS variable |
| 92 | `group-hover:text-[#0C4A6E]` | Inline hex | Logo hover | HARDCODED | Should use CSS variable |
| 96 | `text-[#1C1917]` | Inline hex | Menu button text | HARDCODED | Should use CSS variable |
| 99 | `focus:ring-[#0369A1]` | Inline hex | Focus ring | HARDCODED | Should use CSS variable |
| 124 | `bg-[#E0F2FE]` | Inline hex | Active link bg | HARDCODED | Should use CSS variable |
| 125 | `text-[#0C4A6E]` | Inline hex | Active link text | HARDCODED | Should use CSS variable |
| 126 | `text-[#1C1917]` | Inline hex | Link text | HARDCODED | Should use CSS variable |
| 128 | `hover:text-[#0C4A6E]` | Inline hex | Link hover | HARDCODED | Should use CSS variable |
| 137 | `text-[#1C1917]` | Inline hex | User dropdown text | HARDCODED | Should use CSS variable |
| 138 | `hover:text-[#0C4A6E]` | Inline hex | Dropdown hover | HARDCODED | Should use CSS variable |
| 139 | `border-[#0369A1]` | Inline hex | Border | HARDCODED | Should use CSS variable |
| 140 | `focus:ring-[#0369A1]` | Inline hex | Focus ring | HARDCODED | Should use CSS variable |
| 149 | `bg-white` | Tailwind class | Dropdown bg | Not theme-specific | OK |
| 150 | `border-[#E7E5E4]` | Inline hex | Dropdown border | HARDCODED | Should use CSS variable |
| 155 | `text-[#1C1917]` | Inline hex | Dropdown link text | HARDCODED | Should use CSS variable |
| 156 | `hover:bg-[#E0F2FE]` | Inline hex | Dropdown hover bg | HARDCODED | Should use CSS variable |
| 157 | `hover:text-[#0C4A6E]` | Inline hex | Dropdown hover text | HARDCODED | Should use CSS variable |
| 165 | `text-[#B91C1C]` | Inline hex | Sign out text (red) | HARDCODED | Should use CSS variable |

#### Footer (_footer.html.erb)

| Line | Hardcoded Color | Type | Element | Issue | Recommendation |
|------|-----------------|------|---------|-------|-----------------|
| 3 | `bg-[#082F49]` | Inline hex | Footer bg | HARDCODED | Should use CSS variable |
| 3 | `text-white` | Tailwind class | Footer text | Not theme-specific | OK |
| 10 | `text-[#082F49]` | Inline hex | Wave color | HARDCODED | Should use CSS variable |
| 17 | `text-2xl` | Tailwind class | Title size | Not color-related | OK |
| 26 | `text-white` | Tailwind class | Company text | Not theme-specific | OK |
| 28 | `bg-[#0C4A6E]` | Inline hex | Phone icon bg | HARDCODED | Should use CSS variable |
| 29 | `group-hover:bg-[#D97706]` | Inline hex | Icon hover | HARDCODED | Should use CSS variable |
| 30 | `text-white` | Tailwind class | Icon color | Not theme-specific | OK |
| 31 | `hover:text-[#FEF3C7]` | Inline hex | Hover text | HARDCODED | Should use CSS variable |
| 39 | `bg-[#0C4A6E]` | Inline hex | Email icon bg | HARDCODED | Should use CSS variable |
| 40 | `group-hover:bg-[#D97706]` | Inline hex | Icon hover | HARDCODED | Should use CSS variable |
| 41 | `text-white` | Tailwind class | Email icon color | Not theme-specific | OK |
| 42 | `hover:text-[#FEF3C7]` | Inline hex | Hover text | HARDCODED | Should use CSS variable |
| 56 | `bg-[#0C4A6E]` | Inline hex | Social icon bg | HARDCODED | Should use CSS variable |
| 57 | `hover:bg-[#D97706]` | Inline hex | Social hover bg | HARDCODED | Should use CSS variable |
| 58 | `text-white` | Tailwind class | Icon color | Not theme-specific | OK |
| 61 | `focus:ring-[#FEF3C7]` | Inline hex | Focus ring | HARDCODED | Should use CSS variable |
| 61 | `focus:ring-offset-[#082F49]` | Inline hex | Focus offset | HARDCODED | Should use CSS variable |
| 77 | `text-[#D4D4D8]` | Inline hex | Footer text | HARDCODED | Should use CSS variable |
| 84 | `text-[#FEF3C7]` | Inline hex | Hover text | HARDCODED | Should use CSS variable |
| 90 | `border-[#0C4A6E]` | Inline hex | Footer divider | HARDCODED | Should use CSS variable |
| 99 | `text-[#D4D4D8]` | Inline hex | Copyright text | HARDCODED | Should use CSS variable |
| 104 | `text-[#FEF3C7]` | Inline hex | Link hover | HARDCODED | Should use CSS variable |
| 110 | `from-[#0369A1] via-[#D97706] to-[#F59E0B]` | Inline hex | Wave gradient | HARDCODED | Should use CSS variables |

**Critical Issues Found in Biarritz:**
1. **Extensive use of inline hex colors** throughout both header and footer
2. **Over 30 instances** of hardcoded `#` hex values
3. **No CSS variables** used for theme colors
4. **Difficult to maintain** theme consistency

---

## Summary Table

| Theme | Header Issues | Footer Issues | View File Issues | Total Colors |
|-------|---------------|---------------|-----------------|--------------|
| **Default** | 10 Tailwind (not critical) | 0 | 0 | Mostly variables |
| **Bologna** | 0 | 2 hardcoded hex | 0 | `#d98e6e`, `#e7b5a0` |
| **Brisbane** | 3 wrong colors (blue) | 2 hardcoded hex + 1 mismatch | 0 | `#c9a962`, `#e7b5a0` |
| **Barcelona** | 0 | 2 hardcoded hex | 0 | `#E5B45A`, `#fde047` |
| **Biarritz** | 26+ hardcoded hex | 15+ hardcoded hex | 0 | Multiple |

---

## Detailed Issues by Category

### 1. Inline Hex Colors (Highest Priority)

**Biarritz Theme** - Multiple instances of `style="color: #value"` and square bracket syntax:
- `#082F49` - Ocean dark blue
- `#0C4A6E` - Ocean medium blue
- `#D97706` - Amber/Orange
- `#FEF3C7` - Cream/Light
- `#0369A1` - Sky blue
- `#1C1917` - Dark text
- `#D4D4D8` - Light gray
- `#E0F2FE` - Light blue
- `#F59E0B` - Amber
- `#E7E5E4` - Light gray border
- `#B91C1C` - Red

**Bologna/Brisbane/Barcelona Footers:**
- Footer link colors hardcoded in inline `<style>` blocks instead of using CSS variables

### 2. Wrong Theme Colors (Medium Priority)

**Brisbane Theme Header:**
- Lines 84, 88, 90 use `bg-blue-600` and `text-blue-600` (Tailwind defaults) instead of `bg-luxury-gold` and `text-luxury-gold`

**Brisbane Theme Footer:**
- Line 145 footer link hover uses `#e7b5a0` (terra color) instead of a gold color variant - inconsistent with other themes

### 3. Tailwind Classes That Should Be Variables (Low Priority)

**Default Theme:**
- Uses hardcoded Tailwind colors like `bg-gray-800`, `text-blue-600` instead of theme variables
- This is less critical since Tailwind classes are manageable but less flexible

---

## CSS Variables Available But Not Used

### Bologna Theme
```css
--bologna-terra: #c45d3e
--bologna-terra-400: #d98e6e
--bologna-terra-500: (same as terra)
--bologna-terra-600: #b14a2e
--bologna-olive: #5c6b4d
--bologna-sand: #d4a574
--footer-bg-color: #3d3d3d
--footer-text-color: #d5d0c8
```

### Brisbane Theme
```css
--brisbane-gold: #c9a962
--brisbane-navy: #1a1a2e
--brisbane-cream: #fafafa
--brisbane-charcoal: #2d2d2d
--footer-bg-color: #1a1a2e
--footer-text-color: #e8e8e8
```

### Barcelona Theme
Uses defined colors but they're not exported to CSS root variables - should be formalized.

### Biarritz Theme
**No CSS variables defined at all** - colors are only in inline styles.

---

## Recommendations

### Priority 1: Critical (Do First)
1. **Biarritz Theme:** Convert all inline hex colors to CSS variables in a dedicated CSS file
2. **Footer Custom Content Styles:** In Bologna, Brisbane, Barcelona - move hardcoded hex colors to CSS variables
   - Example: Create `--footer-link-color` and `--footer-link-hover-color`

### Priority 2: Important
3. **Brisbane Header:** Fix incorrect blue colors (lines 84, 88, 90) to use theme gold colors
4. **Brisbane Footer:** Fix mismatched link hover color (line 145)
5. **Default Theme:** Consider using CSS variables instead of inline Tailwind classes for consistency

### Priority 3: Enhancement
6. **Barcelona Theme:** Formalize color variables and export them to CSS root
7. **Consistency:** Ensure all themes follow the same pattern for color definition and usage

---

## Files to Modify

1. `/app/themes/biarritz/views/pwb/_header.html.erb` - Extract 26+ inline hex colors to CSS
2. `/app/themes/biarritz/views/pwb/_footer.html.erb` - Extract 15+ inline hex colors to CSS
3. `/app/themes/bologna/views/pwb/_footer.html.erb` - Lines 188-190
4. `/app/themes/brisbane/views/pwb/_header.html.erb` - Lines 84, 88, 90
5. `/app/themes/brisbane/views/pwb/_footer.html.erb` - Lines 143, 145
6. `/app/themes/barcelona/views/pwb/_footer.html.erb` - Lines 172-174
7. `/app/views/pwb/custom_css/_biarritz.css.erb` - Create new file with CSS variables
8. Update `/app/views/pwb/custom_css/_bologna.css.erb` - Add footer link variables
9. Update `/app/views/pwb/custom_css/_brisbane.css.erb` - Add footer link variables
10. Update `/app/views/pwb/custom_css/_barcelona.css.erb` - Formalize color variables

---

## Color Palette Reference

### Biarritz Palette (from inline colors)
- **Ocean Dark:** `#082F49` (primary background)
- **Ocean Medium:** `#0C4A6E` (accent backgrounds)
- **Sky Blue:** `#0369A1` (icons/accents)
- **Amber:** `#D97706` (hover states)
- **Cream/Light:** `#FEF3C7` (light text)
- **Dark Text:** `#1C1917` (main text)
- **Light Gray:** `#D4D4D8`, `#E7E5E4` (borders/secondary)
- **Red:** `#B91C1C` (sign out/destructive)

### Bologna Palette
- **Terra:** `#c45d3e` (primary)
- **Olive:** `#5c6b4d` (secondary)
- **Sand:** `#d4a574` (accent)
- **Warm Gray:** `#3d3d3d` (text)

### Brisbane Palette
- **Gold:** `#c9a962` (primary)
- **Navy:** `#1a1a2e` (background)
- **Cream:** `#fafafa` (text/light)
- **Charcoal:** `#2d2d2d` (dark text)

### Barcelona Palette
- **Mediterranean:** `#med-*` colors
- **Gold:** `#gold-*` colors
- **Warm:** `#warm-*` colors

### Default Palette
- **Blue:** `#3b82f6` (Tailwind blue-500)
- **Dark Blue:** `#1e40af` (Tailwind blue-800)
- **Gray palette:** Standard Tailwind grays

---

## Additional Notes

- Most themes use Tailwind CSS classes referencing custom color names (e.g., `bg-terra-500`, `text-luxury-gold`)
- These custom color names are defined in the CSS files via root variables
- The main issue is **Biarritz theme completely bypasses this system** and uses inline hex colors instead
- The pattern in Bologna, Brisbane, and Barcelona for footer custom content links should be standardized across themes
- Default theme is functional but could be more consistent with the CSS variable pattern

