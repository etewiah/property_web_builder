# WCAG 2.1 AA Accessibility Audit: PropertyWebBuilder

**Date:** January 2026
**Standard:** WCAG 2.1 Level AA
**Scope:** All themes (default, Barcelona, Biarritz, Bologna, Brisbane, Brussels)

---

## Executive Summary

PropertyWebBuilder demonstrates a solid foundation for accessibility with several strengths already in place: skip links, keyboard navigation, ARIA attributes on many components, and semantic HTML structure. However, there are critical gaps that must be addressed to achieve full WCAG 2.1 AA compliance.

### Compliance Score (Estimated)

| Category | Current | Target |
|----------|---------|--------|
| Perceivable | 65% | 100% |
| Operable | 75% | 100% |
| Understandable | 70% | 100% |
| Robust | 60% | 100% |
| **Overall** | **68%** | **100%** |

### Priority Summary

- **Critical Issues:** 5 (must fix for basic accessibility)
- **Major Issues:** 8 (significant barriers for some users)
- **Minor Issues:** 12 (improvements for better UX)

---

## Table of Contents

1. [WCAG 2.1 AA Compliance Matrix](#wcag-21-aa-compliance-matrix)
2. [Strengths](#strengths)
3. [Critical Issues](#critical-issues)
4. [Major Issues](#major-issues)
5. [Minor Issues](#minor-issues)
6. [Theme-Specific Findings](#theme-specific-findings)
7. [Remediation Roadmap](#remediation-roadmap)

---

## WCAG 2.1 AA Compliance Matrix

### Principle 1: Perceivable

| Criterion | Status | Notes |
|-----------|--------|-------|
| **1.1.1 Non-text Content** | Partial | Property images need meaningful alt text |
| **1.2.1 Audio-only/Video-only** | N/A | No media content |
| **1.2.2 Captions** | N/A | No video content |
| **1.2.3 Audio Description** | N/A | No video content |
| **1.2.4 Captions (Live)** | N/A | No live content |
| **1.2.5 Audio Description** | N/A | No video content |
| **1.3.1 Info and Relationships** | Partial | Form labels exist; some ARIA relationships missing |
| **1.3.2 Meaningful Sequence** | Pass | DOM order matches visual order |
| **1.3.3 Sensory Characteristics** | Partial | Some icon-only UI elements |
| **1.3.4 Orientation** | Pass | No orientation restrictions |
| **1.3.5 Identify Input Purpose** | Fail | Missing autocomplete attributes |
| **1.4.1 Use of Color** | Partial | Some links rely on color only |
| **1.4.2 Audio Control** | N/A | No auto-playing audio |
| **1.4.3 Contrast (Minimum)** | Fail | Hero text over images; some theme palettes |
| **1.4.4 Resize Text** | Pass | Text scales appropriately |
| **1.4.5 Images of Text** | Pass | No images of text |
| **1.4.10 Reflow** | Pass | Responsive layout |
| **1.4.11 Non-text Contrast** | Partial | Some UI components need verification |
| **1.4.12 Text Spacing** | Pass | No issues with increased spacing |
| **1.4.13 Content on Hover/Focus** | Pass | Tooltips remain visible |

### Principle 2: Operable

| Criterion | Status | Notes |
|-----------|--------|-------|
| **2.1.1 Keyboard** | Partial | Flowbite select missing keyboard support |
| **2.1.2 No Keyboard Trap** | Pass | Escape closes modals |
| **2.1.4 Character Key Shortcuts** | Pass | Shortcuts require modifier or can be disabled |
| **2.2.1 Timing Adjustable** | Pass | No strict time limits |
| **2.2.2 Pause, Stop, Hide** | Partial | Carousel auto-play needs pause control |
| **2.3.1 Three Flashes** | Pass | No flashing content |
| **2.4.1 Bypass Blocks** | Pass | Skip link implemented in all themes |
| **2.4.2 Page Titled** | Pass | Dynamic page titles |
| **2.4.3 Focus Order** | Pass | Logical focus order |
| **2.4.4 Link Purpose** | Partial | Some generic "View details" links |
| **2.4.5 Multiple Ways** | Pass | Navigation + search |
| **2.4.6 Headings and Labels** | Pass | Semantic heading structure |
| **2.4.7 Focus Visible** | Partial | Some components need better focus styles |
| **2.5.1 Pointer Gestures** | Pass | No complex gestures required |
| **2.5.2 Pointer Cancellation** | Pass | Standard click behavior |
| **2.5.3 Label in Name** | Pass | Visible labels match accessible names |
| **2.5.4 Motion Actuation** | N/A | No motion-based input |

### Principle 3: Understandable

| Criterion | Status | Notes |
|-----------|--------|-------|
| **3.1.1 Language of Page** | Pass | `lang` attribute on `<html>` |
| **3.1.2 Language of Parts** | Partial | Language switcher needs `lang` attributes |
| **3.2.1 On Focus** | Pass | No context changes on focus |
| **3.2.2 On Input** | Pass | Form submission requires explicit action |
| **3.2.3 Consistent Navigation** | Pass | Navigation consistent across pages |
| **3.2.4 Consistent Identification** | Pass | UI components consistent |
| **3.3.1 Error Identification** | Fail | Errors not linked to fields |
| **3.3.2 Labels or Instructions** | Pass | Form fields have labels |
| **3.3.3 Error Suggestion** | Partial | Generic error messages |
| **3.3.4 Error Prevention** | N/A | No legal/financial transactions |

### Principle 4: Robust

| Criterion | Status | Notes |
|-----------|--------|-------|
| **4.1.1 Parsing** | Pass | Valid HTML |
| **4.1.2 Name, Role, Value** | Fail | Custom dropdown missing ARIA roles |
| **4.1.3 Status Messages** | Fail | Search results not announced |

---

## Strengths

### 1. Skip Links (All Themes)
All six themes implement skip links correctly:
```html
<a href="#main-content" class="sr-only focus:not-sr-only ...">
  Skip to main content
</a>
```
**Files:** `app/themes/*/views/layouts/pwb/application.html.erb`

### 2. Keyboard Controller
Comprehensive keyboard shortcuts implemented via Stimulus:
- `/` - Focus search
- `?` - Show keyboard help
- `Escape` - Close dialogs
- `F` - Toggle favorite

**File:** `app/javascript/controllers/keyboard_controller.js`

### 3. Semantic HTML Structure
- Main landmark with `role="main"` on `<main>` element
- Navigation landmarks with `aria-label`
- Proper heading hierarchy
- Semantic lists for menus

### 4. Touch Target Sizing
Navigation and interactive elements use minimum 44x44px touch targets:
```erb
class="min-h-[44px] min-w-[44px]"
```

### 5. Language Switcher Accessibility (Default Theme)
- Full language names (not abbreviations)
- `lang` and `hreflang` attributes
- `aria-current="page"` for selected language
- Proper `aria-label` on nav

**File:** `app/themes/default/views/pwb/_header.html.erb:21-33`

### 6. Social Media Links
Social links include descriptive `aria-label` attributes:
```erb
aria-label="Follow us on Facebook"
```

### 7. Property Feature Metadata
Property cards include accessible labels for features:
```erb
aria-label="<%= t('pwb.accessibility.bedrooms_count', count: property.count_bedrooms) %>"
```

---

## Critical Issues

### C1. Custom Dropdown Select Missing ARIA Roles

**WCAG:** 4.1.2 Name, Role, Value
**Severity:** Critical
**File:** `app/themes/default/views/pwb/shared/_flowbite_select.html.erb`

**Problem:**
The custom Flowbite-based dropdown select is implemented as a button + hidden list without proper ARIA roles. Screen readers cannot identify it as a select control.

**Current Implementation:**
```erb
<button id="<%= button_id %>" data-dropdown-toggle="<%= dropdown_id %>"
        class="..." type="button">
  <span id="<%= id %>_label"><%= selected_label %></span>
  <svg>...</svg>
</button>
<ul class="py-2 text-sm" aria-labelledby="<%= button_id %>">
  <li>
    <button type="button" onclick="selectOption...">
      <%= label %>
    </button>
  </li>
</ul>
```

**Required Fix:**
```erb
<div role="combobox"
     aria-haspopup="listbox"
     aria-expanded="false"
     aria-owns="<%= dropdown_id %>"
     aria-controls="<%= dropdown_id %>">
  <button id="<%= button_id %>"
          aria-labelledby="<%= id %>_label"
          aria-expanded="false"
          type="button">
    <span id="<%= id %>_label"><%= selected_label %></span>
  </button>
</div>
<ul id="<%= dropdown_id %>"
    role="listbox"
    aria-labelledby="<%= button_id %>">
  <li role="option"
      aria-selected="<%= selected_value == value ? 'true' : 'false' %>"
      tabindex="-1">
    <%= label %>
  </li>
</ul>
```

### C2. Form Error Messages Not Linked to Fields

**WCAG:** 3.3.1 Error Identification, 4.1.2 Name/Role/Value
**Severity:** Critical
**Files:** Multiple form partials

**Problem:**
Error messages are displayed visually but not programmatically linked to their fields via `aria-describedby`. Screen reader users won't know which field has an error.

**Current:**
```erb
<div class="bg-red-50 ..." role="alert">
  Error message here
</div>
<input name="email" ...>
```

**Required Fix:**
```erb
<input name="email"
       aria-describedby="email-error"
       aria-invalid="true"
       ...>
<div id="email-error" class="bg-red-50 ..." role="alert">
  Error message here
</div>
```

### C3. Hero Text Contrast Over Images

**WCAG:** 1.4.3 Contrast (Minimum)
**Severity:** Critical
**Files:** All theme hero sections

**Problem:**
Hero text is rendered directly over background images without guaranteed contrast. Text may be illegible depending on the image content.

**Required Fix:**
Add a semi-transparent overlay:
```css
.hero__overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
}
```

Or use text shadows:
```css
.hero__text {
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
}
```

### C4. Gallery Carousel Not Announced to Screen Readers

**WCAG:** 4.1.3 Status Messages
**Severity:** Critical
**File:** `app/themes/default/views/pwb/props/_images_section_carousel.html.erb`

**Problem:**
When the carousel changes slides, screen reader users are not informed. The counter text `1 / 5` updates visually but isn't announced.

**Required Fix:**
```html
<div aria-live="polite" aria-atomic="true" class="sr-only">
  Showing image 1 of 5
</div>
```

And add to the gallery controller:
```javascript
showSlide(index) {
  // ... existing code

  // Announce slide change
  const announcement = this.element.querySelector('[aria-live="polite"]')
  if (announcement) {
    announcement.textContent = `Showing image ${index + 1} of ${this.slideTargets.length}`
  }
}
```

### C5. Search Results Not Announced

**WCAG:** 4.1.3 Status Messages
**Severity:** Critical
**File:** `app/views/pwb/search/_search_results_frame.html.erb`

**Problem:**
When search results update via AJAX, the results count is shown but not announced to screen readers. Users don't know the search completed or how many results were found.

**Current (Partial):**
```erb
<div class="results-count text-gray-700" aria-live="polite">
```

**Issue:** The `aria-live` region exists but may not be properly populated on AJAX updates. Verify that:
1. The element exists in the DOM before results load
2. Content is updated (not replaced) inside the live region
3. Consider using `aria-atomic="true"` if the whole message should be announced

---

## Major Issues

### M1. Mobile Menu Button Missing aria-expanded Toggle

**WCAG:** 4.1.2 Name, Role, Value
**Severity:** Major
**Files:** All theme headers

**Problem:**
While `aria-expanded="false"` is set initially, it may not toggle to `true` when the menu opens (depends on toggle controller implementation).

**Verification needed:** Check that the `toggle_controller.js` updates `aria-expanded` dynamically.

### M2. Tabs Missing aria-controls

**WCAG:** 4.1.2 Name, Role, Value
**Severity:** Major
**File:** `app/javascript/controllers/tabs_controller.js`

**Problem:**
Tabs have `role="tab"` and panels have `role="tabpanel"`, but the relationship via `aria-controls` (tab → panel) and `aria-labelledby` (panel → tab) is not set.

**Current:**
```javascript
tab.setAttribute("role", "tab")
tab.setAttribute("tabindex", i === this.indexValue ? "0" : "-1")
// Missing: tab.setAttribute("aria-controls", panelId)
```

**Required Fix:**
```javascript
connect() {
  this.tabTargets.forEach((tab, i) => {
    const panelId = `tab-panel-${i}`
    const tabId = `tab-${i}`

    tab.setAttribute("id", tabId)
    tab.setAttribute("role", "tab")
    tab.setAttribute("aria-controls", panelId)

    this.panelTargets[i].setAttribute("id", panelId)
    this.panelTargets[i].setAttribute("aria-labelledby", tabId)
  })
}
```

### M3. Required Fields Missing aria-required

**WCAG:** 3.3.2 Labels or Instructions
**Severity:** Major
**Files:** Form partials

**Problem:**
Required form fields are marked visually (asterisk) but not programmatically with `aria-required="true"` or the HTML5 `required` attribute.

### M4. Loading States Not Announced

**WCAG:** 4.1.3 Status Messages
**Severity:** Major

**Problem:**
When content is loading (search, form submission), there's no screen reader announcement. Users don't know something is happening.

**Required Fix:**
Add a live region for loading states:
```html
<div id="loading-announcement" aria-live="polite" class="sr-only"></div>
```

Update via JavaScript:
```javascript
document.getElementById('loading-announcement').textContent = 'Loading results...';
// After load:
document.getElementById('loading-announcement').textContent = '';
```

### M5. Icon-Only Buttons Need Accessible Names

**WCAG:** 4.1.2 Name, Role, Value
**Severity:** Major
**Files:** Various

**Problem:**
Some buttons/links contain only icons with no accessible text alternative.

**Example from carousel:**
```erb
<button type="button" ... data-carousel-prev>
  <span class="...">
    <svg ...></svg>
    <span class="sr-only">Previous</span>  <!-- Good! -->
  </span>
</button>
```

**Verify:** Ensure all icon-only interactive elements have either:
- `aria-label` attribute
- `<span class="sr-only">` text
- `title` attribute (less preferred)

### M6. Focus Management in Modal Incomplete

**WCAG:** 2.4.3 Focus Order
**Severity:** Major
**File:** `app/javascript/controllers/keyboard_controller.js`

**Problem:**
The keyboard controller's inline help modal sets `tabindex="-1"` and calls `.focus()`, but doesn't implement focus trapping. Users can tab outside the modal.

**Required Fix:**
Implement focus trap:
```javascript
trapFocus(modal) {
  const focusable = modal.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  const first = focusable[0];
  const last = focusable[focusable.length - 1];

  modal.addEventListener('keydown', (e) => {
    if (e.key === 'Tab') {
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  });
}
```

### M7. Carousel Auto-Play Missing Pause Control

**WCAG:** 2.2.2 Pause, Stop, Hide
**Severity:** Major
**File:** `app/javascript/controllers/gallery_controller.js`

**Problem:**
The gallery supports auto-play but there's no visible pause button. Users with cognitive disabilities may need to pause to read content.

**Current:** Auto-play pauses on hover, but:
- Keyboard users can't easily pause
- No visible pause/play button

**Required Fix:**
Add a visible pause/play toggle button that also works via keyboard.

### M8. Autocomplete Attributes Missing

**WCAG:** 1.3.5 Identify Input Purpose
**Severity:** Major
**Files:** Contact forms, search forms

**Problem:**
Form fields like name, email, phone don't have `autocomplete` attributes, preventing browsers and assistive technologies from auto-filling.

**Required Fix:**
```erb
<input type="email" name="contact[email]" autocomplete="email" ...>
<input type="text" name="contact[name]" autocomplete="name" ...>
<input type="tel" name="contact[tel]" autocomplete="tel" ...>
```

---

## Minor Issues

### m1. Language Switcher - Other Themes
Some themes may not have the full accessibility implementation seen in the default theme. Verify all themes have:
- `lang` and `hreflang` attributes
- Full language names (not abbreviations)
- `aria-current="page"` for selected language

### m2. Image Alt Text Quality
Property images use generic alt text from the title field. Consider:
- Adding descriptive alt text in the admin
- Using a fallback like "Property listing: [address]"

### m3. Breadcrumb Accessibility
Breadcrumbs use `aria-label="Breadcrumb"` but should also have:
```html
<li aria-current="page">Current Page</li>
```

### m4. Focus Styles Consistency
Some components have custom focus styles, others rely on browser defaults. Standardize to:
```css
:focus-visible {
  outline: 3px solid var(--focus-color);
  outline-offset: 2px;
}
```

### m5. Color-Only Links
Some links rely on color alone to distinguish from surrounding text. Add underlines:
```css
.prose a {
  text-decoration: underline;
}
```

### m6. User Dropdown Menu
The user dropdown menu in the header doesn't have `role="menu"` and menu items don't have `role="menuitem"`.

### m7. View Toggle Button Group
The list/grid view toggle should use `role="group"` with `aria-label`:
```html
<div role="group" aria-label="View options">
  <button aria-pressed="true">List</button>
  <button aria-pressed="false">Grid</button>
</div>
```

### m8. Price Display
Currency values should be formatted accessibly:
```html
<span aria-label="Price: $325,000">$325,000</span>
```

### m9. Feature List Semantics
Property features list could use `<dl>` for better semantics:
```html
<dl class="property-features">
  <div>
    <dt class="sr-only">Bedrooms</dt>
    <dd>3</dd>
  </div>
</dl>
```

### m10. Map Component
The map component should have:
- An accessible name
- A skip link to bypass it
- Text alternative describing the location

### m11. Form Labels
Some forms use placeholder text instead of visible labels. Always provide visible labels.

### m12. Consent Banner
The consent banner has good ARIA attributes but should trap focus when open.

---

## Theme-Specific Findings

### Default Theme
**Overall:** Good baseline accessibility
- ✅ Skip link
- ✅ Language switcher with proper attributes
- ✅ Social links with aria-labels
- ⚠️ Hero contrast needs verification

### Barcelona Theme
**Overall:** Similar to default
- ✅ Skip link (med-600 accent color)
- ⚠️ Verify contrast with Mediterranean color palette
- ⚠️ Check property card contrast

### Biarritz Theme
**Overall:** Strong accessibility features
- ✅ Skip link (sky-700)
- ✅ Footer has `role="contentinfo"`
- ✅ Header nav has `role="navigation"`
- ✅ User dropdown has `role="menu"` on items
- ⚠️ Light color scheme - verify all text contrast

### Bologna Theme
**Overall:** Needs contrast review
- ✅ Skip link (terra-600)
- ⚠️ Terracotta/earth tones may have contrast issues
- ⚠️ Red/brown text combinations need verification

### Brisbane Theme
**Overall:** Luxury theme with potential contrast issues
- ✅ Skip link (luxury-gold)
- ⚠️ Gold on white may not meet contrast
- ⚠️ Verify all palette variations (platinum, rose gold, etc.)

### Brussels Theme
**Overall:** Good structure
- ✅ Skip link (brussels-lime)
- ✅ Main landmark with `role="main"`
- ⚠️ Lime green accent - verify contrast

---

## Remediation Roadmap

### Phase 1: Critical Fixes (Week 1-2)

1. **C1: Custom Dropdown ARIA**
   - Update `_flowbite_select.html.erb`
   - Add proper combobox/listbox roles
   - Test with NVDA/VoiceOver

2. **C2: Form Error Linking**
   - Add `aria-describedby` to form inputs
   - Add `aria-invalid` when errors present
   - Update all form partials

3. **C3: Hero Contrast**
   - Add overlay to all theme hero sections
   - Verify with contrast checker tool
   - Target: 4.5:1 minimum for body text, 3:1 for large text

4. **C4: Gallery Announcements**
   - Add aria-live region to carousel
   - Update gallery_controller.js
   - Test slide change announcements

5. **C5: Search Result Announcements**
   - Verify aria-live region behavior
   - Ensure count updates are announced
   - Test with screen reader

### Phase 2: Major Fixes (Week 3-4)

6. **M1-M2: ARIA Relationships**
   - Add aria-controls to tabs
   - Verify mobile menu aria-expanded toggle
   - Add aria-labelledby to tab panels

7. **M3-M4: Form & Loading States**
   - Add aria-required to required fields
   - Implement loading announcements
   - Add autocomplete attributes

8. **M5-M6: Focus Management**
   - Audit all icon-only elements
   - Implement focus trap in modals
   - Test with keyboard only

9. **M7-M8: Auto-Play & Autocomplete**
   - Add pause button to carousel
   - Add autocomplete to form fields

### Phase 3: Polish & Testing (Week 5-6)

10. **Minor Issues**
    - Address all minor issues
    - Standardize focus styles
    - Review all themes for consistency

11. **Testing**
    - Automated testing with axe-core
    - Manual testing checklist
    - Screen reader testing (NVDA, VoiceOver, JAWS)

12. **Documentation**
    - Update component documentation
    - Add accessibility notes to CONTRIBUTING.md
    - Create accessibility testing guide

---

## References

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [Existing Home Page Audit](../ui/HOME_PAGE_ACCESSIBILITY_AUDIT.md)
- [Component Audit](./COMPONENT_AUDIT.md)
- [Testing Checklist](./TESTING_CHECKLIST.md)
