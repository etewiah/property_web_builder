# UX & Accessibility Audit: Home Page

**Page:** Home (`/en`)
**Themes:** default (observed), brisbane, bologna
**Target standard:** WCAG 2.1 AA
**Audience:** Frontend / UI engineer
**Date:** 2025-12-29

---

## 1. HERO SECTION (Highest Priority)

### 1.1 Text Contrast Over Background Image

**Status:** Not Fixed

**Observed:**
- Hero text ("Find Your Dream Home", paragraph, CTA buttons) is rendered directly on top of a detailed photo
- No guaranteed contrast protection is visible

**Risk:**
- Text contrast likely falls below WCAG 2.1 AA:
  - Normal text requires 4.5:1
  - Large headings require 3:1
- Risk increases in lighter themes (brisbane especially)

**Required Fix:**
Add a contrast-stabilizing overlay or text background.

```html
<section class="hero">
  <div class="hero__overlay"></div>
  <div class="hero__content">
    <h1>Find Your Dream Home</h1>
    <p>We're dedicated to helping you find the perfect property...</p>
  </div>
</section>
```

```css
.hero {
  position: relative;
}

.hero__overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.45); /* tune per theme */
}

.hero__content {
  position: relative;
  color: #ffffff;
}
```

**Acceptance Criteria:**
- [ ] All hero text passes WCAG AA contrast in all three themes
- [ ] Verified via automated tooling (Lighthouse / axe)

---

### 1.2 Missing Primary Task Entry (UX)

**Status:** Enhancement

**Observed:**
- User sees branding and CTAs but no immediate way to filter/search

**Issue:**
- Real estate users are task-driven (location, price, buy/rent)
- "Browse Properties" is generic and adds friction

**Recommendation:**
Add a lightweight search block in hero:
- Buy / Rent toggle
- Location input
- Budget range

*No accessibility blocker, but high UX ROI.*

---

## 2. HEADER & NAVIGATION

### 2.1 Language Switcher Accessibility

**Status:** Not Fixed

**Observed DOM:**
```html
<a href="/en"> en </a>
<a href="/es"> es </a>
```

**Issues:**
- Abbreviations are ambiguous for screen readers
- No `lang` or `hreflang`
- Very small click targets

**Required Fix:**
```html
<nav aria-label="Language selector">
  <a href="/en" lang="en" hreflang="en">English</a>
  <a href="/es" lang="es" hreflang="es">Español</a>
</nav>
```

```css
nav[aria-label="Language selector"] a {
  min-width: 44px;
  min-height: 44px;
  display: inline-flex;
  align-items: center;
}
```

---

### 2.2 Mobile Menu Button Semantics

**Status:** Not Fixed

**Observed:**
```html
<button> Open main menu</button>
```

**Issues:**
- No `aria-expanded`
- No relationship to controlled nav

**Required Fix:**
```html
<button
  aria-label="Open main navigation"
  aria-expanded="false"
  aria-controls="main-nav"
>
  ☰
</button>
```

**JS Requirement:**
- Toggle `aria-expanded` dynamically

---

## 3. CTA BUTTONS

### 3.1 Button Contrast & Focus

**Status:** Not Fixed

**Observed:**
- White outlined button over image ("Contact Us")
- Likely fails contrast in lighter themes

**Required Fix:**
- Ensure 4.5:1 contrast
- Add visible focus state

```css
.button:focus-visible {
  outline: 3px solid #005fcc;
  outline-offset: 2px;
}
```

**Theme Note:**
- Brisbane theme likely needs darker button fills
- Bologna theme must avoid dark-red-on-dark backgrounds

---

## 4. SERVICES SECTION

### 4.1 Icon-Only Semantics

**Status:** Not Fixed

**Observed:**
Icons rendered as text equivalents:
```
home
person
attach_money
```

**Issue:**
- Screen readers may read raw icon names
- Icons alone do not convey meaning

**Required Fix:**
```html
<span aria-hidden="true" class="icon-home"></span>
<span class="sr-only">Find Your Home</span>
```

OR

```html
<span aria-label="Find Your Home">
  <i class="icon-home"></i>
</span>
```

---

## 5. PROPERTY LISTINGS (CRITICAL)

### 5.1 Icon-Only Metadata

**Status:** Not Fixed

**Observed:**
```
bed 2
shower 2
fullscreen 190m2
directions_car 1
```

**Issues:**
- Screen readers read icon tokens ("bed", "fullscreen")
- No semantic grouping

**Required Fix:**
```html
<ul class="property-meta">
  <li aria-label="2 bedrooms">
    <i class="icon-bed" aria-hidden="true"></i> 2
  </li>
  <li aria-label="2 bathrooms">
    <i class="icon-bath" aria-hidden="true"></i> 2
  </li>
  <li aria-label="190 square metres">
    <i class="icon-area" aria-hidden="true"></i> 190 m²
  </li>
</ul>
```

---

### 5.2 Price Hierarchy (UX)

**Status:** Enhancement

**Observed:**
- Price appears after title
- Competes visually with metadata

**Recommendation:**
Make price the dominant element.

```html
<strong class="property-price">$325,000</strong>
<h3>Charming Country House with Modern Updates</h3>
```

---

## 6. IMAGES

### 6.1 Decorative vs Informative Alt Text

**Status:** Not Fixed

**Observed:**
```html
<img src="carousel_villa_with_pool.webp" alt=""/>
```

**Issue:**
- Empty alt is correct only if decorative
- Hero image is contextual and meaningful

**Required Fix:**
```html
<img
  src="carousel_villa_with_pool.webp"
  alt="Luxury villa with swimming pool at night"
/>
```

---

### 6.2 Lazy Loading (Performance UX)

**Status:** Partially Implemented

**Required Fix:**
```html
<img
  src="new_villa.webp"
  alt="Charming Country House with Modern Updates"
  loading="lazy"
/>
```

---

## 7. TESTIMONIALS

### 7.1 Quote Contrast & Length

**Status:** Needs Verification

**Observed:**
- Long quotes
- Potential low-contrast body text in themed variants

**Required Checks:**
- [ ] Quote text contrast ≥ 4.5:1 in Brisbane & Bologna
- [ ] Line length ≤ ~75 characters

---

## 8. FOOTER

### 8.1 Social Media Link Accessibility

**Status:** Not Fixed

**Observed:**
```html
<a href="https://www.facebook.com/propertywebbuilder" aria-label="Follow us on Facebook"> </a>
```

**Issue:**
- Empty anchor has no visible content

**Required Fix:**
```html
<a
  href="https://www.facebook.com/propertywebbuilder"
  aria-label="Follow us on Facebook"
>
  <i class="icon-facebook" aria-hidden="true"></i>
</a>
```

---

## 9. THEME-SPECIFIC CHECKLIST (MANDATORY)

### Brisbane Theme
- [ ] Verify all gray text ≥ #444 on white
- [ ] Avoid pastel buttons without dark text
- [ ] Hero overlay opacity likely needs to be higher

### Bologna Theme
- [ ] Avoid red/brown text on dark backgrounds
- [ ] Ensure links are underlined, not color-only

```css
a {
  text-decoration: underline;
}
```

---

## 10. PRIORITIZED TASK LIST

### P0 – Accessibility Blockers
1. [ ] Hero text contrast
2. [ ] Property icon semantics
3. [ ] Language switcher semantics
4. [ ] Mobile menu ARIA

### P1 – UX & Conversion
5. [ ] Hero search/filter
6. [ ] Price hierarchy in listings
7. [ ] CTA contrast consistency

### P2 – Quality & Polish
8. [ ] Lazy loading images
9. [ ] Testimonial readability
10. [ ] Footer social links

---

## Implementation Notes

### Files to Modify

**Hero Section:**
- `app/themes/default/views/pwb/welcome/_hero.html.erb`
- `app/themes/brisbane/views/pwb/welcome/_hero.html.erb`
- `app/themes/bologna/views/pwb/welcome/_hero.html.erb`

**Header/Navigation:**
- `app/themes/*/views/pwb/_header.html.erb`
- `app/views/pwb/_locale_switcher.html.erb`

**Property Cards:**
- `app/themes/*/views/pwb/welcome/_single_property_row.html.erb`
- `app/themes/*/views/pwb/search/_search_result_item.html.erb`

**Footer:**
- `app/themes/*/views/pwb/_footer.html.erb`

**Stylesheets:**
- `app/assets/stylesheets/pwb/themes/default.css`
- `app/assets/stylesheets/brisbane_theme.css`
- `app/assets/stylesheets/bologna_theme.css`
