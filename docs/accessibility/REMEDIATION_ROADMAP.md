# Accessibility Remediation Roadmap

**Target:** WCAG 2.1 Level AA Compliance
**Last Updated:** January 2026

This document provides a prioritized list of accessibility fixes with implementation details, estimated effort, and dependencies.

---

## Priority Levels

| Priority | Definition | Timeline |
|----------|------------|----------|
| **P0** | Critical blockers preventing access | Week 1 |
| **P1** | Major barriers affecting usability | Week 2-3 |
| **P2** | Improvements for better UX | Week 4-5 |
| **P3** | Polish and enhancements | Ongoing |

---

## Phase 1: Critical Fixes (P0)

### 1.1 Custom Dropdown ARIA Implementation

**Issue:** Flowbite-based custom select lacks proper ARIA roles
**WCAG:** 4.1.2 Name, Role, Value
**Effort:** High (1-2 days)

**Files to Modify:**
- `app/themes/default/views/pwb/shared/_flowbite_select.html.erb`
- Create: `app/javascript/controllers/accessible_select_controller.js`

**Implementation Steps:**

1. Create new Stimulus controller with combobox pattern:
```javascript
// app/javascript/controllers/accessible_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "listbox", "option", "input", "label"]

  connect() {
    this.highlightedIndex = -1
    this.setupARIA()
  }

  setupARIA() {
    this.buttonTarget.setAttribute("role", "combobox")
    this.buttonTarget.setAttribute("aria-haspopup", "listbox")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.buttonTarget.setAttribute("aria-controls", this.listboxTarget.id)

    this.listboxTarget.setAttribute("role", "listbox")

    this.optionTargets.forEach((option, i) => {
      option.setAttribute("role", "option")
      option.setAttribute("id", `${this.element.id}-option-${i}`)
    })
  }

  // ... full implementation in COMPONENT_AUDIT.md
}
```

2. Update template:
```erb
<div class="relative"
     data-controller="accessible-select"
     id="<%= id %>_container">
  <!-- Updated markup with ARIA roles -->
</div>
```

3. Register controller in `application.js`

4. Test with NVDA and VoiceOver

**Acceptance Criteria:**
- [ ] Screen reader announces as "combobox"
- [ ] Options announced as "option X of Y"
- [ ] Selected state announced
- [ ] Keyboard navigation works (arrows, enter, escape)
- [ ] Typeahead search works

---

### 1.2 Form Error Linking

**Issue:** Error messages not programmatically linked to form fields
**WCAG:** 3.3.1 Error Identification, 4.1.2 Name/Role/Value
**Effort:** Medium (4-6 hours)

**Files to Modify:**
- `app/helpers/pwb/forms_helper.rb` (or equivalent)
- `app/views/pwb/props/_request_prop_info.html.erb`
- `app/views/pwb/search/_search_form_*.html.erb`
- All contact form partials

**Implementation Steps:**

1. Update form helper to generate proper markup:
```ruby
# app/helpers/pwb/accessible_forms_helper.rb
module Pwb::AccessibleFormsHelper
  def accessible_input(form, field, options = {})
    error_id = "#{form.object_name}_#{field}_error"

    field_options = options.merge(
      aria: {
        describedby: error_id,
        invalid: form.object.errors[field].any?,
        required: options[:required]
      }
    )

    content_tag(:div, class: "form-group") do
      concat form.label(field)
      concat form.text_field(field, field_options)
      concat error_container(form, field, error_id)
    end
  end

  def error_container(form, field, error_id)
    content_tag(:div, id: error_id, class: "error-message", role: "alert") do
      form.object.errors[field].first if form.object.errors[field].any?
    end
  end
end
```

2. Update forms to use new helper or add attributes manually

3. Add JavaScript for client-side validation:
```javascript
// Update aria-invalid dynamically
input.addEventListener('invalid', () => {
  input.setAttribute('aria-invalid', 'true')
})
```

**Acceptance Criteria:**
- [ ] Each error has unique ID
- [ ] Input has `aria-describedby` pointing to error
- [ ] Input has `aria-invalid="true"` when invalid
- [ ] Error container has `role="alert"`
- [ ] Screen reader announces error when field is focused

---

### 1.3 Hero Text Contrast

**Issue:** Hero text over images may not meet contrast requirements
**WCAG:** 1.4.3 Contrast (Minimum)
**Effort:** Medium (4-6 hours)

**Files to Modify:**
- `app/themes/*/views/pwb/welcome/_hero.html.erb` (all themes)
- Theme CSS files

**Implementation Steps:**

1. Add semi-transparent overlay:
```erb
<%# In hero section %>
<section class="hero relative">
  <div class="hero__image absolute inset-0">
    <%= image_tag hero_image, class: "w-full h-full object-cover" %>
  </div>
  <div class="hero__overlay absolute inset-0 bg-black/50"></div>
  <div class="hero__content relative z-10">
    <h1 class="text-white text-shadow-lg">...</h1>
  </div>
</section>
```

2. Add text shadow as backup:
```css
.text-shadow-lg {
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
}
```

3. Verify contrast per theme:

| Theme | Overlay Opacity | Text Color | Background Sample | Ratio |
|-------|-----------------|------------|-------------------|-------|
| Default | 50% | #ffffff | | 4.5:1+ |
| Barcelona | 45% | #ffffff | | 4.5:1+ |
| Biarritz | 40% | #ffffff | | 4.5:1+ |
| Bologna | 50% | #ffffff | | 4.5:1+ |
| Brisbane | 55% | #ffffff | | 4.5:1+ |
| Brussels | 45% | #ffffff | | 4.5:1+ |

**Acceptance Criteria:**
- [ ] Normal text achieves 4.5:1 contrast
- [ ] Large text achieves 3:1 contrast
- [ ] Verified with Colour Contrast Analyser tool
- [ ] Works with various background images

---

### 1.4 Gallery Slide Announcements

**Issue:** Carousel slide changes not announced to screen readers
**WCAG:** 4.1.3 Status Messages
**Effort:** Low (2-3 hours)

**Files to Modify:**
- `app/javascript/controllers/gallery_controller.js`
- `app/themes/*/views/pwb/props/_images_section_carousel.html.erb`

**Implementation Steps:**

1. Add live region to gallery markup:
```erb
<div data-controller="gallery"
     role="region"
     aria-roledescription="carousel"
     aria-label="Property photos">
  <div aria-live="polite" aria-atomic="true" class="sr-only"
       data-gallery-target="announcement"></div>
  <!-- slides -->
</div>
```

2. Update controller to announce changes:
```javascript
showSlide(index) {
  // ... existing code ...

  if (this.hasAnnouncementTarget) {
    this.announcementTarget.textContent =
      `Showing image ${index + 1} of ${this.slideTargets.length}`
  }
}
```

**Acceptance Criteria:**
- [ ] Slide position announced on navigation
- [ ] Works with keyboard navigation
- [ ] Works with button clicks
- [ ] Tested with NVDA and VoiceOver

---

### 1.5 Search Results Announcements

**Issue:** Search results not announced after AJAX update
**WCAG:** 4.1.3 Status Messages
**Effort:** Low (2-3 hours)

**Files to Modify:**
- `app/views/pwb/search/_search_results_frame.html.erb`
- Search-related JavaScript

**Implementation Steps:**

1. Ensure live region exists before results load:
```erb
<div id="search-results-container">
  <div id="search-announcements" aria-live="polite" class="sr-only"></div>
  <div id="results-count" aria-live="polite">
    <%= t('search.results_count', count: @properties.count) %>
  </div>
  <div id="search-results">
    <%= render @properties %>
  </div>
</div>
```

2. Update JavaScript to announce results:
```javascript
// After AJAX completes
const count = document.querySelectorAll('.property-card').length
const announcement = document.getElementById('search-announcements')
announcement.textContent = `Search complete. ${count} properties found.`
```

**Acceptance Criteria:**
- [ ] Results count announced after search
- [ ] "Searching..." announced during load
- [ ] "No results found" announced when appropriate
- [ ] Focus managed appropriately

---

## Phase 2: Major Fixes (P1)

### 2.1 Tabs ARIA Relationships

**Issue:** Tabs missing `aria-controls` and panels missing `aria-labelledby`
**WCAG:** 4.1.2 Name, Role, Value
**Effort:** Low (1-2 hours)

**File:** `app/javascript/controllers/tabs_controller.js`

**Implementation:**
```javascript
connect() {
  const prefix = `tabs-${Math.random().toString(36).substr(2, 9)}`

  this.tabTargets.forEach((tab, i) => {
    const tabId = `${prefix}-tab-${i}`
    const panelId = `${prefix}-panel-${i}`

    tab.id = tabId
    tab.setAttribute("aria-controls", panelId)

    this.panelTargets[i].id = panelId
    this.panelTargets[i].setAttribute("aria-labelledby", tabId)
  })
}
```

---

### 2.2 Required Field Indicators

**Issue:** Required fields missing `aria-required`
**WCAG:** 3.3.2 Labels or Instructions
**Effort:** Low (1-2 hours)

**Files:** All form partials

**Implementation:**
```erb
<input type="email"
       name="contact[email]"
       required
       aria-required="true"
       ...>
```

---

### 2.3 Autocomplete Attributes

**Issue:** Form fields missing autocomplete hints
**WCAG:** 1.3.5 Identify Input Purpose
**Effort:** Low (1-2 hours)

**Files:** Contact forms, signup forms

**Implementation:**
```erb
<input type="text" name="contact[name]" autocomplete="name">
<input type="email" name="contact[email]" autocomplete="email">
<input type="tel" name="contact[phone]" autocomplete="tel">
<textarea name="contact[message]"></textarea>
```

---

### 2.4 Loading State Announcements

**Issue:** Loading states not announced
**WCAG:** 4.1.3 Status Messages
**Effort:** Medium (3-4 hours)

**Files:** Various JavaScript controllers

**Implementation:**
```javascript
// Create global loading announcer
const LoadingAnnouncer = {
  element: null,

  init() {
    this.element = document.createElement('div')
    this.element.setAttribute('aria-live', 'polite')
    this.element.setAttribute('aria-atomic', 'true')
    this.element.className = 'sr-only'
    this.element.id = 'loading-announcer'
    document.body.appendChild(this.element)
  },

  announce(message) {
    if (!this.element) this.init()
    this.element.textContent = message
  },

  clear() {
    if (this.element) this.element.textContent = ''
  }
}

// Usage
LoadingAnnouncer.announce('Loading properties...')
// ... after load
LoadingAnnouncer.clear()
```

---

### 2.5 Modal Focus Trapping

**Issue:** Keyboard help modal doesn't trap focus
**WCAG:** 2.4.3 Focus Order
**Effort:** Medium (3-4 hours)

**File:** `app/javascript/controllers/keyboard_controller.js`

**Implementation:** See COMPONENT_AUDIT.md for full focus trap implementation.

---

### 2.6 Icon-Only Elements Audit

**Issue:** Some icon-only buttons/links may lack accessible names
**WCAG:** 4.1.2 Name, Role, Value
**Effort:** Medium (3-4 hours)

**Files:** Multiple templates

**Action Items:**
1. Audit all icon-only interactive elements
2. Ensure each has either:
   - `aria-label`
   - `<span class="sr-only">` text
   - Visible text label

---

### 2.7 Carousel Pause Control

**Issue:** Auto-playing carousel has no visible pause button
**WCAG:** 2.2.2 Pause, Stop, Hide
**Effort:** Medium (2-3 hours)

**Files:**
- `app/javascript/controllers/gallery_controller.js`
- Carousel templates

**Implementation:**
```erb
<button type="button"
        data-action="gallery#toggleAutoplay"
        data-gallery-target="pauseButton"
        aria-label="Pause slideshow"
        class="...">
  <span data-gallery-target="pauseIcon">⏸</span>
  <span data-gallery-target="playIcon" class="hidden">▶</span>
</button>
```

---

### 2.8 Mobile Menu aria-expanded

**Issue:** Verify aria-expanded toggles correctly
**WCAG:** 4.1.2 Name, Role, Value
**Effort:** Low (1 hour)

**File:** `app/javascript/controllers/toggle_controller.js`

**Verification:**
```javascript
toggle() {
  const isExpanded = this.triggerTarget.getAttribute('aria-expanded') === 'true'
  this.triggerTarget.setAttribute('aria-expanded', String(!isExpanded))
  // ...
}
```

---

## Phase 3: Polish & Improvements (P2)

### 3.1 Language Switcher Consistency

Ensure all themes match default theme's accessible implementation.

**Files:** `app/themes/*/views/pwb/_header.html.erb`

---

### 3.2 Breadcrumb aria-current

Add `aria-current="page"` to current page in breadcrumbs.

---

### 3.3 View Toggle aria-pressed

Add `aria-pressed` to list/grid toggle buttons.

---

### 3.4 Focus Style Standardization

Create consistent focus styles across all themes.

```css
/* Add to each theme's CSS */
:focus-visible {
  outline: 3px solid var(--pwb-focus-color, #005fcc);
  outline-offset: 2px;
}

/* Remove default outline */
:focus:not(:focus-visible) {
  outline: none;
}
```

---

### 3.5 Property Feature Semantics

Consider using `<dl>` for property features.

---

### 3.6 Map Accessibility

Add accessible name and skip link for map components.

---

### 3.7 Consent Banner Focus Trap

Implement focus trap for consent banner.

---

## Implementation Timeline

```
Week 1:
├── 1.1 Custom Dropdown ARIA (2 days)
├── 1.2 Form Error Linking (1 day)
└── 1.3 Hero Text Contrast (1 day)

Week 2:
├── 1.4 Gallery Announcements (0.5 day)
├── 1.5 Search Announcements (0.5 day)
├── 2.1 Tabs ARIA (0.5 day)
├── 2.2 Required Fields (0.5 day)
├── 2.3 Autocomplete (0.5 day)
└── 2.4 Loading Announcements (0.5 day)

Week 3:
├── 2.5 Modal Focus Trap (0.5 day)
├── 2.6 Icon Audit (0.5 day)
├── 2.7 Carousel Pause (0.5 day)
├── 2.8 Mobile Menu Check (0.5 day)
└── Testing and fixes (2 days)

Week 4-5:
├── Phase 3 improvements
├── Theme-by-theme verification
├── Full screen reader testing
└── Documentation updates
```

---

## Testing Requirements Per Fix

| Fix | Automated | Manual Keyboard | Screen Reader | Theme Check |
|-----|-----------|-----------------|---------------|-------------|
| 1.1 Dropdown | axe | ✓ | ✓ | All |
| 1.2 Form Errors | axe | ✓ | ✓ | Sample |
| 1.3 Hero Contrast | Lighthouse | Visual | - | All |
| 1.4 Gallery | - | ✓ | ✓ | Sample |
| 1.5 Search Results | - | - | ✓ | Sample |
| 2.1 Tabs | axe | ✓ | ✓ | Sample |
| 2.2 Required | axe | - | ✓ | Sample |
| 2.3 Autocomplete | axe | - | - | Sample |
| 2.4 Loading | - | - | ✓ | Sample |
| 2.5 Modal Focus | - | ✓ | - | Sample |
| 2.6 Icons | axe | - | ✓ | Sample |
| 2.7 Carousel Pause | - | ✓ | ✓ | Sample |
| 2.8 Mobile Menu | - | ✓ | ✓ | All |

---

## Success Metrics

### Target Scores

| Metric | Current (Est.) | Target | Tool |
|--------|----------------|--------|------|
| Lighthouse Accessibility | ~75 | 95+ | Chrome DevTools |
| axe violations (critical) | 3-5 | 0 | axe-core |
| axe violations (major) | 5-10 | 0 | axe-core |
| Pa11y errors | 10-15 | 0 | Pa11y |

### Verification Checklist

- [ ] All P0 issues resolved
- [ ] All P1 issues resolved
- [ ] Lighthouse score >= 90 on all pages
- [ ] Zero critical axe violations
- [ ] Screen reader testing completed for key flows
- [ ] All 6 themes verified
- [ ] Documentation updated

---

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
- [Main Audit Document](./ACCESSIBILITY_AUDIT.md)
- [Component Audit](./COMPONENT_AUDIT.md)
- [Testing Checklist](./TESTING_CHECKLIST.md)
