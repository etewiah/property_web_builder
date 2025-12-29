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

## Contrast Calculation Formula

```ruby
# Relative luminance calculation
def relative_luminance(r, g, b)
  [r, g, b].map do |c|
    c = c / 255.0
    c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  end.then { |r, g, b| 0.2126 * r + 0.7152 * g + 0.0722 * b }
end

# Contrast ratio
def contrast_ratio(l1, l2)
  lighter = [l1, l2].max
  darker = [l1, l2].min
  (lighter + 0.05) / (darker + 0.05)
end
```

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
```

## Running an Evaluation

### Step 1: Identify Theme CSS

```bash
# Find theme CSS file
ls app/views/pwb/custom_css/_*.css.erb
```

### Step 2: Extract Color Pairs

Look for these patterns in CSS:
- `color: #xxx` with parent `background: #xxx`
- `rgba(r,g,b, opacity)` values
- CSS variable definitions in `:root`
- Overlay gradients (`linear-gradient`)

### Step 3: Calculate Contrast Ratios

Use online tools or the formula above:
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Coolors Contrast Checker: https://coolors.co/contrast-checker

### Step 4: Document Failures

Create a report:

```markdown
## Theme: [theme_name] Contrast Audit

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
```

### Step 5: Apply Fixes

Common fix patterns:

```css
/* 1. Add overlay to hero */
.hero-bg-wrapper::after {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 1;
}

/* 2. Improve footer text */
.footer-links { color: #d1d5db; }
.footer-copyright { color: #d1d5db; }

/* 3. Fix testimonials */
.testimonial-text { color: #374151; }

/* 4. Fix outline buttons */
.hero-section .btn-outline {
  background: rgba(0, 0, 0, 0.35);
  color: #ffffff;
  border-color: #ffffff;
}

/* 5. Increase gradient opacity */
.theme .hero-section::before {
  background: linear-gradient(
    135deg,
    rgba(0, 0, 0, 0.7) 0%,   /* was 0.5 */
    rgba(0, 0, 0, 0.5) 50%,  /* was 0.3 */
    rgba(0, 0, 0, 0.65) 100% /* was 0.4 */
  );
}
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
  outline: 2px solid var(--primary-color);
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

### Summary: FAIL (3 critical issues)

### Critical Failures

1. **Footer links** - 3.8:1 contrast (needs 4.5:1)
   - Location: `_brisbane.css.erb` line 320
   - Fix: Change `rgba(250,248,245,0.8)` to `0.9`

2. **Hero subtitle** - ~4.1:1 on image
   - Location: Hero section overlay
   - Fix: Increase overlay opacity from 0.4 to 0.5

3. **Testimonial quotes** - 4.2:1 contrast
   - Location: Testimonial section
   - Fix: Change text color from #6b7280 to #374151

### Warnings

- Consider darkening muted footer text for better readability
- Outline buttons could use background for better visibility

### Recommended Fixes

[Include CSS code blocks with exact fixes]
```

## Related Documentation

- WCAG 2.1 Guidelines: https://www.w3.org/WAI/WCAG21/quickref/
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/
- Theme Creation Skill: `.claude/skills/theme-creation/SKILL.md`
- Color Palettes Architecture: `docs/architecture/COLOR_PALETTES_ARCHITECTURE.md`
