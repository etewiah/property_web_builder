---
name: theme-evaluation
description: Evaluate themes for accessibility, contrast, and design issues. Use when auditing themes for WCAG compliance, checking color contrast ratios, or identifying visual/UX problems.
---

# Theme Evaluation for PropertyWebBuilder

## Overview

This skill provides comprehensive theme evaluation focusing on:
- **WCAG AA/AAA contrast compliance** (primary focus)
- Color palette consistency
- Typography readability
- Component styling issues
- Dark mode compatibility
- Responsive design problems

## Quick Evaluation Commands

### Using Built-in Tools

```ruby
# Check WCAG AA compliance for any color pair
Pwb::ColorUtils.wcag_aa_compliant?('#ffffff', '#333333')
# => true (14.0:1 ratio)

# Get exact contrast ratio
Pwb::ColorUtils.contrast_ratio('#ffffff', '#6b7280')
# => 4.5:1 (borderline AA for normal text)

# Suggest text color for a background
Pwb::ColorUtils.suggest_text_color('#1a2744')
# => '#ffffff' (white for dark backgrounds)

# Check if ratio meets specific threshold
Pwb::ColorUtils.meets_contrast_threshold?('#fff', '#666', 4.5)
# => true/false
```

```bash
# Validate all palettes
rake palettes:validate

# Check contrast for a specific palette
rake palettes:contrast[default,classic_red]

# List all palettes for a theme
rake palettes:list[brisbane]
```

## WCAG Contrast Requirements

### Minimum Ratios (WCAG 2.1 AA)

| Text Type | Minimum Ratio | Examples |
|-----------|---------------|----------|
| Normal text (<18px) | 4.5:1 | Body text, labels, captions |
| Large text (>=18px bold or >=24px) | 3:1 | Headings, hero text |
| UI components & graphics | 3:1 | Buttons, icons, borders |
| Incidental/decorative | None | Logos, disabled elements |

### Enhanced Ratios (WCAG AAA)

| Text Type | Enhanced Ratio |
|-----------|---------------|
| Normal text | 7:1 |
| Large text | 4.5:1 |

## Common Color Reference

### Good Contrast Colors on White (#FFFFFF)

| Color | Hex | Contrast | WCAG Level |
|-------|-----|----------|------------|
| Black | #000000 | 21:1 | AAA |
| Gray 900 | #111827 | 16.8:1 | AAA |
| Gray 800 | #1f2937 | 14.3:1 | AAA |
| Gray 700 | #374151 | 10.7:1 | AAA |
| Gray 600 | #4b5563 | 6.3:1 | AA |
| Gray 500 | #6b7280 | 4.5:1 | AA (borderline) |
| Gray 400 | #9ca3af | 2.9:1 | FAIL |
| Gray 300 | #d1d5db | 1.8:1 | FAIL |

### Good Contrast Colors on Dark (#1f2937)

| Color | Hex | Contrast | WCAG Level |
|-------|-----|----------|------------|
| White | #ffffff | 14.3:1 | AAA |
| Gray 100 | #f3f4f6 | 12.7:1 | AAA |
| Gray 200 | #e5e7eb | 11.0:1 | AAA |
| Gray 300 | #d1d5db | 7.5:1 | AAA |
| Gray 400 | #9ca3af | 4.1:1 | FAIL |
| Gray 500 | #6b7280 | 3.2:1 | FAIL |

## Evaluation Checklist

### 1. Hero Section

```markdown
- [ ] Hero title contrast (white text on image overlay)
- [ ] Hero subtitle/paragraph contrast (>=4.5:1)
- [ ] Overlay opacity sufficient for text readability
- [ ] CTA button primary has sufficient contrast
- [ ] CTA button secondary/outline readable on background
- [ ] Text shadow enhances readability (not just decorative)
```

**Common Issues:**
- Transparent overlay too light (use `rgba(0,0,0,0.45)` minimum)
- Subtitle using gray instead of white
- Outline buttons invisible on image backgrounds

**Fixes:**
```css
/* Hero overlay for WCAG AA compliance */
.hero-bg-wrapper::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 1;
}

/* Outline button on dark/image backgrounds */
.hero-section .btn-outline {
  background: rgba(0, 0, 0, 0.35);
  border-color: #ffffff;
  color: #ffffff;
}
```

### 2. Navigation/Header

```markdown
- [ ] Nav links contrast against header background
- [ ] Active/hover states clearly visible
- [ ] Dropdown menus readable
- [ ] Mobile menu toggle visible
- [ ] Logo readable (if text)
```

### 3. Footer

```markdown
- [ ] Footer text contrast (>=4.5:1)
- [ ] Footer links contrast (>=4.5:1)
- [ ] Social icons visible
- [ ] Copyright text readable
- [ ] Footer heading contrast
```

**Common Issues:**
- Light gray text (#9ca3af) on dark background fails
- Links using opacity < 0.85

**Fixes:**
```css
/* Footer link improvements */
.footer-links {
  color: #d1d5db; /* 7.5:1 on #1f2937 (was #9ca3af at 4.1:1) */
}

/* For themes using rgba */
footer a {
  color: rgba(255, 255, 255, 0.9); /* Not 0.7 or 0.8 */
}
```

### 4. Body Content

```markdown
- [ ] Body text contrast (>=4.5:1)
- [ ] Heading contrast
- [ ] Link color distinguishable and sufficient contrast
- [ ] Blockquote/testimonial text
- [ ] Caption/small text
- [ ] Form labels
- [ ] Placeholder text (informational only, not critical)
```

**Common Issues:**
- Testimonial quotes using muted gray (#6b7280)
- Small text/captions too light

**Fixes:**
```css
.testimonial-text {
  color: #374151; /* 10.7:1 on white (was #6b7280 at 4.5:1) */
}
```

### 5. Cards & Components

```markdown
- [ ] Card text on card background
- [ ] Price text visible
- [ ] Badge/tag text readable
- [ ] Icon colors sufficient contrast
- [ ] Border visibility (3:1 for UI)
```

### 6. Buttons

```markdown
- [ ] Primary button text contrast (white on brand color)
- [ ] Secondary button contrast
- [ ] Outline button visible on all backgrounds
- [ ] Disabled state still minimally visible
- [ ] Hover/focus states visible
```

### 7. Forms

```markdown
- [ ] Input text contrast
- [ ] Label contrast
- [ ] Error message contrast (red on background)
- [ ] Help text contrast
- [ ] Border visibility
```

### 8. Dark Mode (if supported)

```markdown
- [ ] All light mode checks apply to dark mode
- [ ] Cards have sufficient contrast against dark background
- [ ] Links visible in dark mode
- [ ] Form inputs styled for dark
```

## Theme Files to Check

### CSS Files Location

```
app/views/pwb/custom_css/
├── _default.css.erb
├── _brisbane.css.erb
├── _bologna.css.erb
├── _barcelona.css.erb
├── _biarritz.css.erb
└── _base_variables.css.erb
```

### Palette Files Location

```
app/themes/
├── default/palettes/
│   ├── classic_red.json
│   ├── ocean_blue.json
│   ├── forest_green.json
│   ├── sunset_orange.json
│   ├── midnight_purple.json
│   └── natural_earth.json
├── brisbane/palettes/
│   ├── gold_navy.json
│   ├── rose_gold.json
│   ├── platinum.json
│   ├── emerald_luxury.json
│   ├── azure_prestige.json
│   └── champagne_onyx.json
└── bologna/palettes/
    ├── terracotta_classic.json
    ├── sage_stone.json
    ├── coastal_warmth.json
    └── modern_slate.json
```

### Key CSS Selectors to Audit

```css
/* Hero */
.hero-section, .hero-bg-wrapper, .hero-title, .hero-subtitle
.hero-section::before, .hero-bg-wrapper::after

/* Navigation */
.navbar, header, .nav-link, .navbar-brand

/* Footer */
footer, .site-footer, .footer-links, .footer-contact-list
.footer-copyright, .social-icon-link

/* Content */
.testimonial-text, .testimonial-content
.service-content, .service-description
.card-body, .property-card

/* Buttons */
.btn-primary, .btn-secondary, .btn-outline
.btn-base, .btn-action
.pwb-btn--primary, .pwb-btn--secondary
```

## Running an Evaluation

### Step 1: Load Theme and Palette Colors

```ruby
# Get theme info
theme = Pwb::Theme.find_by(name: 'brisbane')
theme.palettes.keys
# => ["gold_navy", "rose_gold", "platinum", ...]

# Load specific palette colors
loader = Pwb::PaletteLoader.new
colors = loader.get_light_colors('brisbane', 'gold_navy')
# => { "primary_color" => "#c9a962", "secondary_color" => "#1a2744", ... }
```

### Step 2: Check Critical Color Pairs

```ruby
# Check all critical combinations
colors = loader.get_light_colors('brisbane', 'gold_navy')

# Text on backgrounds
Pwb::ColorUtils.contrast_ratio(colors['text_color'], colors['background_color'])
Pwb::ColorUtils.contrast_ratio(colors['header_text_color'], colors['header_background_color'])
Pwb::ColorUtils.contrast_ratio(colors['footer_text_color'], colors['footer_background_color'])

# Primary color on white (for buttons)
Pwb::ColorUtils.contrast_ratio('#ffffff', colors['primary_color'])

# Links on background
Pwb::ColorUtils.contrast_ratio(colors['link_color'], colors['background_color'])
```

### Step 3: Generate Contrast Report

```ruby
# Quick contrast audit
def audit_palette(theme_name, palette_id)
  loader = Pwb::PaletteLoader.new
  colors = loader.get_light_colors(theme_name, palette_id)

  checks = [
    ['Body text', colors['text_color'], colors['background_color'], 4.5],
    ['Header text', colors['header_text_color'], colors['header_background_color'], 4.5],
    ['Footer text', colors['footer_text_color'], colors['footer_background_color'], 4.5],
    ['Link on bg', colors['link_color'], colors['background_color'], 4.5],
    ['Primary on white', '#ffffff', colors['primary_color'], 4.5],
  ]

  checks.each do |name, fg, bg, required|
    ratio = Pwb::ColorUtils.contrast_ratio(fg, bg)
    status = ratio >= required ? 'PASS' : 'FAIL'
    puts "#{status} #{name}: #{ratio.round(2)}:1 (need #{required}:1)"
  end
end

audit_palette('brisbane', 'gold_navy')
```

### Step 4: Document Failures

Create a report:

```markdown
## Theme: brisbane Contrast Audit

### FAILURES (Must Fix)

| Element | Foreground | Background | Ratio | Required | Fix |
|---------|-----------|------------|-------|----------|-----|
| Footer links | #9ca3af | #1f2937 | 4.1:1 | 4.5:1 | Use #d1d5db |
| Hero subtitle | #f3f4f6 | image | ~4.2:1 | 4.5:1 | Add overlay |

### WARNINGS (Should Fix)

| Element | Issue | Recommendation |
|---------|-------|----------------|
| Testimonials | Borderline 4.5:1 | Darken to #374151 |

### PASSED

- Hero title: White on overlay (21:1)
- Primary buttons: White on brand (8.2:1)
- Body text: #333 on white (12.6:1)
```

## Using ColorUtils API

### Full API Reference

```ruby
# Contrast calculations
Pwb::ColorUtils.contrast_ratio('#ffffff', '#333333')
# => 12.63

Pwb::ColorUtils.wcag_aa_compliant?(foreground, background)
# => true/false (checks 4.5:1)

Pwb::ColorUtils.wcag_aa_large_compliant?(foreground, background)
# => true/false (checks 3:1 for large text)

Pwb::ColorUtils.meets_contrast_threshold?(fg, bg, threshold)
# => true/false

# Color suggestions
Pwb::ColorUtils.suggest_text_color(background_color)
# => '#ffffff' or '#000000' based on luminance

# Shade generation
Pwb::ColorUtils.generate_shades('#3498db')
# => { 50 => '#ebf5fc', 100 => '#d6ebf9', ..., 900 => '#0a2d4a' }

Pwb::ColorUtils.lighten('#3498db', 20)
# => lighter shade

Pwb::ColorUtils.darken('#3498db', 20)
# => darker shade

# Dark mode generation
Pwb::ColorUtils.generate_dark_mode_colors(light_colors_hash)
# => { 'primary_color' => '#...', 'background_color' => '#121212', ... }

# Color parsing
Pwb::ColorUtils.hex_to_rgb('#3498db')
# => [52, 152, 219]

Pwb::ColorUtils.rgb_to_hex(52, 152, 219)
# => '#3498db'

# Luminance
Pwb::ColorUtils.relative_luminance('#3498db')
# => 0.284 (0-1 scale)
```

## Additional Checks

### Color Blindness

Check that:
- Information isn't conveyed by color alone
- Links have underlines or other indicators
- Error states have icons, not just red color
- Charts/graphs use patterns or labels

### Typography

- Minimum 16px for body text
- Line height >= 1.5 for readability
- Sufficient spacing between paragraphs
- Headings clearly distinguished from body

### Focus Indicators

```css
/* Must have visible focus states */
*:focus {
  outline: 2px solid var(--pwb-primary);
  outline-offset: 2px;
}

/* Or custom focus ring */
button:focus-visible {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
}
```

### Motion/Animation

- Respect `prefers-reduced-motion`
- No auto-playing content that can't be paused
- No flashing content (3 flashes/second)

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Quick Reference: Safe Color Combinations

### On White Background

| Use Case | Recommended Colors |
|----------|-------------------|
| Body text | #111827, #1f2937, #374151 |
| Muted text | #4b5563, #6b7280 (large only) |
| Links | #1d4ed8, #2563eb, #0369a1 |
| Errors | #b91c1c, #dc2626 |
| Success | #047857, #059669 |

### On Dark Background (#1f2937 or darker)

| Use Case | Recommended Colors |
|----------|-------------------|
| Primary text | #ffffff, #f9fafb, #f3f4f6 |
| Secondary text | #e5e7eb, #d1d5db |
| Links | #60a5fa, #93c5fd |
| Accent | Brand gold/accent at 90%+ opacity |

## Output Format

When evaluating a theme, provide:

1. **Summary**: Pass/Fail with critical issues count
2. **Critical Failures**: Must fix for WCAG AA
3. **Warnings**: Should fix for better UX
4. **Recommendations**: Best practices
5. **Code Fixes**: Ready-to-use CSS corrections

Example:

```
## Theme Evaluation: brisbane

### Summary: PASS with 2 warnings

### Critical Failures
None - all color pairs meet WCAG AA requirements.

### Warnings

1. **Footer muted text** - 4.6:1 contrast (borderline)
   - Location: `_brisbane.css.erb` line 320
   - Recommendation: Consider using #d1d5db instead of #9ca3af

2. **Testimonial quotes** - 4.5:1 contrast (exactly at threshold)
   - Location: Testimonial section
   - Recommendation: Darken text from #6b7280 to #4b5563

### Passed Checks

- Hero title: White on overlay (21:1) ✓
- Body text: #333 on white (12.6:1) ✓
- Primary buttons: White on gold (8.2:1) ✓
- Footer text: White on navy (14.3:1) ✓
- Header navigation: Navy on white (14.3:1) ✓

### Recommendations

1. Add `prefers-reduced-motion` media query for animations
2. Ensure all interactive elements have visible focus states
3. Consider adding underlines to links for color-blind users
```

## Related Documentation

- WCAG 2.1 Guidelines: https://www.w3.org/WAI/WCAG21/quickref/
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Theme Creation Skill: `.claude/skills/theme-creation/SKILL.md`
- Color Palettes Architecture: `docs/theming/color-palettes/COLOR_PALETTES_ARCHITECTURE.md`
- Biarritz Contrast Guide: `docs/theming/BIARRITZ_CONTRAST_GUIDE.md`
- Theme System Documentation: `docs/theming/README.md`
