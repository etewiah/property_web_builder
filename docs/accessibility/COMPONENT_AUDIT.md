# Component Accessibility Audit

**Date:** January 2026
**Standard:** WCAG 2.1 Level AA + WAI-ARIA Authoring Practices

This document provides detailed accessibility findings for each interactive component in PropertyWebBuilder, along with specific code fixes and ARIA pattern recommendations.

---

## Table of Contents

1. [Custom Dropdown Select](#1-custom-dropdown-select)
2. [Gallery/Carousel](#2-gallerycarousel)
3. [Tabs Component](#3-tabs-component)
4. [Dropdown Menu](#4-dropdown-menu)
5. [Mobile Navigation Toggle](#5-mobile-navigation-toggle)
6. [Keyboard Help Modal](#6-keyboard-help-modal)
7. [Search Forms](#7-search-forms)
8. [Contact Forms](#8-contact-forms)
9. [Property Cards](#9-property-cards)
10. [Language Switcher](#10-language-switcher)
11. [Breadcrumbs](#11-breadcrumbs)
12. [View Toggle](#12-view-toggle)
13. [Consent Banner](#13-consent-banner)
14. [Toast/Notifications](#14-toastnotifications)

---

## 1. Custom Dropdown Select

**File:** `app/themes/default/views/pwb/shared/_flowbite_select.html.erb`

### Current Implementation

```erb
<div class="relative">
  <input type="hidden" name="<%= name %>" id="<%= id %>" value="<%= selected_value %>">

  <button id="<%= button_id %>" data-dropdown-toggle="<%= dropdown_id %>"
          class="..." type="button">
    <span id="<%= id %>_label"><%= selected_label %></span>
    <svg ...></svg>
  </button>

  <div id="<%= dropdown_id %>" class="absolute z-50 hidden ...">
    <ul class="py-2 ..." aria-labelledby="<%= button_id %>">
      <% options.each do |label, value| %>
        <li>
          <button type="button" onclick="selectOption_<%= id %>...">
            <%= label %>
          </button>
        </li>
      <% end %>
    </ul>
  </div>
</div>
```

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing `role="combobox"` on container | 4.1.2 | Critical |
| Missing `role="listbox"` on options list | 4.1.2 | Critical |
| Missing `role="option"` on list items | 4.1.2 | Critical |
| No keyboard navigation (arrow keys) | 2.1.1 | Critical |
| Missing `aria-activedescendant` | 4.1.2 | Major |
| No typeahead search | 2.1.1 | Minor |

### Recommended Fix

**Updated Template:**
```erb
<%
  dropdown_id = "#{id}_dropdown"
  button_id = "#{id}_button"
  selected_value = selected || ""
  selected_label = options.find { |o| o[1].to_s == selected_value.to_s }&.first || placeholder || "Select..."
%>

<div class="relative"
     data-controller="accessible-select"
     data-accessible-select-selected-value="<%= selected_value %>">
  <input type="hidden"
         name="<%= name %>"
         id="<%= id %>"
         value="<%= selected_value %>"
         data-accessible-select-target="input">

  <button id="<%= button_id %>"
          type="button"
          role="combobox"
          aria-haspopup="listbox"
          aria-expanded="false"
          aria-controls="<%= dropdown_id %>"
          aria-labelledby="<%= id %>_visual_label"
          data-accessible-select-target="button"
          data-action="click->accessible-select#toggle
                       keydown->accessible-select#handleKeydown"
          class="bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg
                 focus:ring-2 focus:ring-blue-500 focus:border-blue-500
                 block w-full p-2.5 text-left flex justify-between items-center">
    <span id="<%= id %>_label" data-accessible-select-target="label">
      <%= selected_label %>
    </span>
    <svg class="w-3 h-3 ml-2 transition-transform"
         aria-hidden="true"
         data-accessible-select-target="icon"
         viewBox="0 0 10 6">
      <path stroke="currentColor" stroke-linecap="round"
            stroke-linejoin="round" stroke-width="2" d="m1 1 4 4 4-4"/>
    </svg>
  </button>

  <ul id="<%= dropdown_id %>"
      role="listbox"
      aria-labelledby="<%= button_id %>"
      tabindex="-1"
      data-accessible-select-target="listbox"
      class="absolute z-50 hidden bg-white divide-y divide-gray-100
             rounded-lg shadow w-full max-h-60 overflow-y-auto
             focus:outline-none">
    <% options.each_with_index do |(label, value), index| %>
      <li id="<%= id %>_option_<%= index %>"
          role="option"
          aria-selected="<%= selected_value.to_s == value.to_s %>"
          data-value="<%= value %>"
          data-accessible-select-target="option"
          data-action="click->accessible-select#select
                       mouseenter->accessible-select#highlight"
          class="px-4 py-2 cursor-pointer hover:bg-gray-100
                 aria-selected:bg-blue-100 aria-selected:text-blue-900">
        <%= label %>
      </li>
    <% end %>
  </ul>
</div>
```

**New Stimulus Controller:**
```javascript
// app/javascript/controllers/accessible_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "listbox", "option", "input", "label", "icon"]
  static values = { selected: String }

  connect() {
    this.highlightedIndex = -1
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.listboxTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.iconTarget.classList.add("rotate-180")

    // Find currently selected option
    const selectedOption = this.optionTargets.find(
      opt => opt.getAttribute("aria-selected") === "true"
    )
    if (selectedOption) {
      this.highlightOption(this.optionTargets.indexOf(selectedOption))
    }
  }

  close() {
    this.listboxTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.iconTarget.classList.remove("rotate-180")
    this.highlightedIndex = -1
    this.buttonTarget.focus()
  }

  get isOpen() {
    return this.buttonTarget.getAttribute("aria-expanded") === "true"
  }

  handleKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (!this.isOpen) {
          this.open()
        } else {
          this.highlightNext()
        }
        break

      case "ArrowUp":
        event.preventDefault()
        if (this.isOpen) {
          this.highlightPrevious()
        }
        break

      case "Enter":
      case " ":
        event.preventDefault()
        if (!this.isOpen) {
          this.open()
        } else if (this.highlightedIndex >= 0) {
          this.selectHighlighted()
        }
        break

      case "Escape":
        if (this.isOpen) {
          event.preventDefault()
          this.close()
        }
        break

      case "Home":
        if (this.isOpen) {
          event.preventDefault()
          this.highlightOption(0)
        }
        break

      case "End":
        if (this.isOpen) {
          event.preventDefault()
          this.highlightOption(this.optionTargets.length - 1)
        }
        break

      default:
        // Typeahead: find option starting with pressed key
        if (event.key.length === 1 && this.isOpen) {
          this.typeahead(event.key)
        }
    }
  }

  highlightNext() {
    const next = this.highlightedIndex < this.optionTargets.length - 1
      ? this.highlightedIndex + 1
      : 0
    this.highlightOption(next)
  }

  highlightPrevious() {
    const prev = this.highlightedIndex > 0
      ? this.highlightedIndex - 1
      : this.optionTargets.length - 1
    this.highlightOption(prev)
  }

  highlightOption(index) {
    // Remove highlight from all
    this.optionTargets.forEach(opt => {
      opt.classList.remove("bg-gray-100")
    })

    // Add highlight to target
    this.highlightedIndex = index
    const option = this.optionTargets[index]
    if (option) {
      option.classList.add("bg-gray-100")
      option.scrollIntoView({ block: "nearest" })
      this.buttonTarget.setAttribute("aria-activedescendant", option.id)
    }
  }

  highlight(event) {
    const index = this.optionTargets.indexOf(event.currentTarget)
    this.highlightOption(index)
  }

  selectHighlighted() {
    const option = this.optionTargets[this.highlightedIndex]
    if (option) {
      this.selectOption(option)
    }
  }

  select(event) {
    this.selectOption(event.currentTarget)
  }

  selectOption(option) {
    const value = option.dataset.value
    const label = option.textContent.trim()

    // Update hidden input
    this.inputTarget.value = value

    // Update button label
    this.labelTarget.textContent = label

    // Update aria-selected
    this.optionTargets.forEach(opt => {
      opt.setAttribute("aria-selected", opt === option)
    })

    // Dispatch change event
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))

    this.close()
  }

  typeahead(char) {
    const search = char.toLowerCase()
    const match = this.optionTargets.find(opt =>
      opt.textContent.trim().toLowerCase().startsWith(search)
    )
    if (match) {
      this.highlightOption(this.optionTargets.indexOf(match))
    }
  }
}
```

### Testing Checklist
- [ ] Can open with Enter/Space
- [ ] Can navigate with Arrow keys
- [ ] Can select with Enter
- [ ] Can close with Escape
- [ ] Announces selected option
- [ ] Screen reader identifies as combobox
- [ ] Typeahead search works

---

## 2. Gallery/Carousel

**File:** `app/javascript/controllers/gallery_controller.js`

### Current Implementation Strengths
- Keyboard navigation (Arrow keys, Home, End)
- Makes element focusable with `tabindex="0"`
- Pauses auto-play on hover

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Slide changes not announced | 4.1.3 | Critical |
| No visible pause button | 2.2.2 | Major |
| Missing `role="region"` and `aria-roledescription` | 4.1.2 | Major |
| Slides not labeled | 4.1.2 | Minor |

### Recommended Fix

**Updated Controller:**
```javascript
// Add to gallery_controller.js

connect() {
  // ... existing code ...

  // Add ARIA attributes
  this.element.setAttribute("role", "region")
  this.element.setAttribute("aria-roledescription", "carousel")
  this.element.setAttribute("aria-label", this.element.dataset.galleryLabel || "Image gallery")

  // Create live region for announcements
  this.liveRegion = document.createElement("div")
  this.liveRegion.setAttribute("aria-live", "polite")
  this.liveRegion.setAttribute("aria-atomic", "true")
  this.liveRegion.className = "sr-only"
  this.element.appendChild(this.liveRegion)

  // Label slides
  this.slideTargets.forEach((slide, i) => {
    slide.setAttribute("role", "group")
    slide.setAttribute("aria-roledescription", "slide")
    slide.setAttribute("aria-label", `Slide ${i + 1} of ${this.slideTargets.length}`)
  })
}

showSlide(index) {
  // ... existing code ...

  // Announce slide change
  this.announceSlide(index)
}

announceSlide(index) {
  if (this.liveRegion) {
    this.liveRegion.textContent = `Showing slide ${index + 1} of ${this.slideTargets.length}`
  }
}

// Add pause/play toggle
toggleAutoplay() {
  if (this.autoplayTimer) {
    this.stopAutoplay()
    this.announceAutoplayState("Autoplay paused")
  } else {
    this.startAutoplay()
    this.announceAutoplayState("Autoplay resumed")
  }
}

announceAutoplayState(message) {
  if (this.liveRegion) {
    this.liveRegion.textContent = message
  }
}
```

**HTML Template Addition (pause button):**
```erb
<button type="button"
        data-action="gallery#toggleAutoplay"
        aria-label="Pause slideshow"
        class="absolute bottom-4 right-4 p-2 bg-white/80 rounded-full
               hover:bg-white focus:ring-2 focus:ring-blue-500">
  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
    <!-- Pause icon -->
    <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/>
  </svg>
</button>
```

---

## 3. Tabs Component

**File:** `app/javascript/controllers/tabs_controller.js`

### Current Implementation Strengths
- Keyboard navigation (Arrow keys, Home, End)
- Sets `role="tab"` and `role="tabpanel"`
- Updates `aria-selected` and `tabindex`

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing `aria-controls` on tabs | 4.1.2 | Major |
| Missing `aria-labelledby` on panels | 4.1.2 | Major |
| Missing unique IDs | 4.1.1 | Major |

### Recommended Fix

```javascript
// Update tabs_controller.js

connect() {
  // Generate unique prefix
  this.idPrefix = `tabs-${Math.random().toString(36).substr(2, 9)}`

  this.tabTargets.forEach((tab, i) => {
    const tabId = `${this.idPrefix}-tab-${i}`
    const panelId = `${this.idPrefix}-panel-${i}`

    // Set IDs
    tab.setAttribute("id", tabId)
    this.panelTargets[i].setAttribute("id", panelId)

    // Set ARIA relationships
    tab.setAttribute("role", "tab")
    tab.setAttribute("aria-controls", panelId)
    tab.setAttribute("tabindex", i === this.indexValue ? "0" : "-1")

    this.panelTargets[i].setAttribute("role", "tabpanel")
    this.panelTargets[i].setAttribute("aria-labelledby", tabId)
    this.panelTargets[i].setAttribute("tabindex", "0")
  })

  // Set tablist role if target exists
  if (this.hasTablistTarget) {
    this.tablistTarget.setAttribute("role", "tablist")
  }

  this.showTab(this.indexValue)
}
```

---

## 4. Dropdown Menu

**File:** `app/javascript/controllers/dropdown_controller.js`

### Current Implementation Strengths
- Full keyboard navigation
- Updates `aria-expanded`
- Manages highlight with `aria-selected`
- Closes on Escape

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing `role="menu"` for navigation menus | 4.1.2 | Major |
| Items should have `role="menuitem"` | 4.1.2 | Major |
| Should use `aria-activedescendant` instead of focus | 4.1.2 | Minor |

### Recommended Fix

**For navigation menus, add:**
```javascript
// In template:
<div data-controller="dropdown" data-dropdown-menu-type-value="menu">
  <button data-dropdown-target="button"
          aria-haspopup="menu">
    Menu
  </button>
  <ul data-dropdown-target="menu" role="menu">
    <li role="none">
      <a role="menuitem" data-dropdown-target="item" href="...">Item 1</a>
    </li>
  </ul>
</div>
```

**Note:** For select-like dropdowns, use `listbox`/`option` instead (see Component #1).

---

## 5. Mobile Navigation Toggle

**Files:** `app/themes/*/views/pwb/_header.html.erb`

### Current Implementation (Default Theme)

```erb
<button
  data-action="toggle#toggle"
  data-toggle-target="trigger"
  type="button"
  aria-controls="navbar-main"
  aria-expanded="false"
  aria-label="<%= t('pwb.accessibility.open_main_menu') %>">
  <svg aria-hidden="true">...</svg>
</button>
```

### Status: Good

The default theme implementation is correct. Ensure the toggle controller updates `aria-expanded` dynamically.

### Verify Toggle Controller

```javascript
// app/javascript/controllers/toggle_controller.js
// Should include:
toggle() {
  const isExpanded = this.triggerTarget.getAttribute("aria-expanded") === "true"
  this.triggerTarget.setAttribute("aria-expanded", !isExpanded)
  this.contentTarget.classList.toggle("hidden")
}
```

---

## 6. Keyboard Help Modal

**File:** `app/javascript/controllers/keyboard_controller.js`

### Current Implementation

```javascript
showInlineHelp() {
  const helpHtml = `
    <div id="keyboard-shortcuts-help" class="fixed inset-0 z-50 ..."
         data-action="click->keyboard#closeHelp keydown.escape->keyboard#closeHelp">
      <div class="bg-white rounded-lg ..." data-action="click->keyboard#stopPropagation">
        ...
      </div>
    </div>
  `
  document.body.insertAdjacentHTML("beforeend", helpHtml)
}

toggleHelp() {
  if (this.hasHelpModalTarget) {
    this.helpModalTarget.classList.toggle("hidden")
    if (!this.helpModalTarget.classList.contains("hidden")) {
      this.helpModalTarget.setAttribute("tabindex", "-1")
      this.helpModalTarget.focus()
    }
  }
}
```

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| No focus trap | 2.4.3 | Major |
| Missing `role="dialog"` | 4.1.2 | Major |
| Missing `aria-modal="true"` | 4.1.2 | Major |
| Background not inert | 2.4.3 | Minor |

### Recommended Fix

```javascript
showInlineHelp() {
  this.removeInlineHelp()

  const helpHtml = `
    <div id="keyboard-shortcuts-help"
         class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
         role="dialog"
         aria-modal="true"
         aria-labelledby="keyboard-help-title"
         data-action="click->keyboard#closeHelp">
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6"
           data-action="click->keyboard#stopPropagation">
        <div class="flex justify-between items-center mb-4">
          <h2 id="keyboard-help-title" class="text-xl font-semibold text-gray-900">
            Keyboard Shortcuts
          </h2>
          <button type="button"
                  class="text-gray-400 hover:text-gray-600 focus:ring-2 focus:ring-blue-500"
                  data-action="click->keyboard#closeHelp"
                  aria-label="Close keyboard shortcuts help">
            <span class="sr-only">Close</span>
            <svg class="w-6 h-6" ...></svg>
          </button>
        </div>
        ...
      </div>
    </div>
  `

  document.body.insertAdjacentHTML("beforeend", helpHtml)

  const modal = document.getElementById("keyboard-shortcuts-help")
  this.setupFocusTrap(modal)

  // Store previous focus to restore later
  this.previousFocus = document.activeElement

  // Focus first focusable element
  const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
  if (firstFocusable) firstFocusable.focus()
}

setupFocusTrap(modal) {
  const focusableElements = modal.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  )
  const firstFocusable = focusableElements[0]
  const lastFocusable = focusableElements[focusableElements.length - 1]

  this.focusTrapHandler = (e) => {
    if (e.key !== 'Tab') return

    if (e.shiftKey) {
      if (document.activeElement === firstFocusable) {
        e.preventDefault()
        lastFocusable.focus()
      }
    } else {
      if (document.activeElement === lastFocusable) {
        e.preventDefault()
        firstFocusable.focus()
      }
    }
  }

  modal.addEventListener('keydown', this.focusTrapHandler)
}

closeHelp() {
  this.removeInlineHelp()

  // Restore previous focus
  if (this.previousFocus) {
    this.previousFocus.focus()
    this.previousFocus = null
  }
}
```

---

## 7. Search Forms

**File:** `app/views/pwb/search/_search_form_for_sale.html.erb`

### Current Implementation

```erb
<div>
  <label for="search_for_sale_price_from" class="block text-sm ...">
    <%= I18n.t("simple_form.labels.search.for_sale_price_from") %>
  </label>
  <select name="search[for_sale_price_from]" id="search_for_sale_price_from" class="...">
    ...
  </select>
</div>
```

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing autocomplete on text inputs | 1.3.5 | Major |
| No loading state announcement | 4.1.3 | Major |
| Results not announced | 4.1.3 | Major |
| Features toggle needs accessible name | 4.1.2 | Minor |

### Recommended Fixes

**1. Add loading announcements:**
```erb
<div id="search-status" aria-live="polite" class="sr-only"></div>

<script>
document.addEventListener('ajax:beforeSend', function() {
  document.getElementById('search-status').textContent = 'Searching properties...';
});
document.addEventListener('ajax:complete', function() {
  document.getElementById('search-status').textContent = '';
});
</script>
```

**2. Fix features toggle:**
```erb
<button type="button"
        aria-expanded="false"
        aria-controls="features-panel-sale"
        class="..."
        onclick="toggleFeatures(this)">
  <span><%= I18n.t("search.features_label") %></span>
  <svg aria-hidden="true">...</svg>
</button>
<div id="features-panel-sale" class="hidden" role="group" aria-label="Property features">
```

---

## 8. Contact Forms

**File:** `app/views/pwb/props/_request_prop_info.html.erb`

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing `required` attribute on required fields | 3.3.2 | Major |
| Missing `autocomplete` attributes | 1.3.5 | Major |
| Error container not linked to fields | 3.3.1 | Critical |
| No `aria-describedby` for hints | 4.1.2 | Minor |

### Recommended Fix

**Update the `simple_inmo_input` helper to generate:**
```erb
<div class="space-y-1">
  <label for="contact_name" class="block text-sm font-medium text-gray-700">
    Name <span class="text-red-500" aria-hidden="true">*</span>
  </label>
  <input type="text"
         name="contact[name]"
         id="contact_name"
         required
         aria-required="true"
         autocomplete="name"
         aria-describedby="contact_name_error"
         class="...">
  <div id="contact_name_error" class="text-sm text-red-600" role="alert" aria-live="polite">
    <!-- Error message injected here -->
  </div>
</div>
```

---

## 9. Property Cards

**File:** `app/themes/default/views/pwb/welcome/_single_property_row.html.erb`

### Current Implementation Strengths
- Good use of `aria-label` on feature list items
- Icon elements marked with `aria_hidden: true`
- Link has descriptive `aria-label`

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Image alt text may be generic | 1.1.1 | Minor |
| Price could have more context | 1.3.1 | Minor |

### Recommendations

**1. Improved image alt:**
```erb
alt: "#{property.title.presence || t('pwb.accessibility.property_image')} - #{property.property_type_label}"
```

**2. Price with context:**
```erb
<span class="text-xl font-bold text-blue-600"
      aria-label="<%= t('pwb.accessibility.price', price: property_price(property, rent_or_sale)) %>">
  <%= property_price(property, rent_or_sale) %>
</span>
```

---

## 10. Language Switcher

**File:** `app/themes/default/views/pwb/_header.html.erb:21-33`

### Current Implementation: Good

```erb
<nav aria-label="<%= t('pwb.accessibility.language_selector') %>"
     class="pwb-header__lang-nav ...">
  <% @current_website.supported_locales_with_variants.uniq { |l| l["locale"] }.each do |locale_with_var| %>
    <% is_selected = locale.to_s == locale_with_var["locale"] %>
    <% locale_name = t("languages.#{locale_with_var['locale']}", default: locale_with_var['locale'].upcase) %>
    <%= link_to params.permit(:locale).merge({locale: locale_with_var["locale"]}),
        lang: locale_with_var["locale"],
        hreflang: locale_with_var["locale"],
        "aria-current": is_selected ? "page" : nil,
        class: "... min-h-[44px] min-w-[44px] ..." do %>
      <%= locale_name %>
    <% end %>
  <% end %>
</nav>
```

### Status: Excellent

This is a good implementation. Ensure other themes match this pattern.

---

## 11. Breadcrumbs

**File:** `app/themes/default/views/pwb/sections/contact_us.html.erb`

### Current Implementation

```erb
<nav class="flex" aria-label="Breadcrumb">
  <ol class="inline-flex items-center space-x-1 md:space-x-3">
    <li class="inline-flex items-center">
      <a href="/" class="text-gray-700 hover:text-blue-600">
        <%= I18n.t("webContentSections.home") %>
      </a>
    </li>
    <li>
      <div class="flex items-center">
        <svg aria-hidden="true">...</svg>
        <span class="ml-1 text-gray-500 md:ml-2">
          <%= I18n.t("contactUs") %>
        </span>
      </div>
    </li>
  </ol>
</nav>
```

### Issues

| Issue | WCAG | Severity |
|-------|------|----------|
| Missing `aria-current="page"` on current page | 4.1.2 | Minor |

### Recommended Fix

```erb
<li aria-current="page">
  <div class="flex items-center">
    <svg aria-hidden="true">...</svg>
    <span class="ml-1 text-gray-500 md:ml-2">
      <%= I18n.t("contactUs") %>
    </span>
  </div>
</li>
```

---

## 12. View Toggle

**File:** `app/views/pwb/search/_search_results_frame.html.erb`

### Current Implementation

```erb
<div class="view-toggle flex rounded-md shadow-sm"
     role="group"
     aria-label="<%= t('search.view_options') %>">
  <!-- Toggle buttons -->
</div>
```

### Status: Good

The `role="group"` and `aria-label` are correct.

### Enhancement

Add `aria-pressed` to indicate current selection:
```erb
<button type="button"
        aria-pressed="<%= @view == 'list' %>"
        class="...">
  List view
</button>
```

---

## 13. Consent Banner

**File:** `app/views/shared/_consent_banner.html.erb`

### Current Implementation

```erb
<div role="dialog"
     aria-describedby="consent-description"
     ...>
```

### Status: Good structure

### Enhancement

Add focus trap and `aria-modal="true"`:
```erb
<div role="dialog"
     aria-modal="true"
     aria-labelledby="consent-title"
     aria-describedby="consent-description">
  <h2 id="consent-title">Cookie Consent</h2>
  <p id="consent-description">...</p>
</div>
```

---

## 14. Toast/Notifications

### Current Implementation

No dedicated toast controller found. Flash messages use `role="alert"`.

### Recommended Implementation

For dynamic notifications, create a toast controller:

```javascript
// app/javascript/controllers/toast_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  show(message, type = "info") {
    const toast = document.createElement("div")
    toast.setAttribute("role", "status")
    toast.setAttribute("aria-live", type === "error" ? "assertive" : "polite")
    toast.className = `toast toast-${type}`
    toast.textContent = message

    this.containerTarget.appendChild(toast)

    // Auto-dismiss after 5 seconds
    setTimeout(() => toast.remove(), 5000)
  }
}
```

**HTML:**
```erb
<div data-controller="toast" data-toast-target="container"
     class="fixed bottom-4 right-4 space-y-2 z-50"
     aria-label="Notifications">
</div>
```

---

## Summary: Components Needing Updates

| Component | Priority | Effort |
|-----------|----------|--------|
| Custom Dropdown Select | Critical | High |
| Gallery/Carousel | Critical | Medium |
| Contact Forms | Critical | Medium |
| Keyboard Help Modal | Major | Medium |
| Tabs Component | Major | Low |
| Search Forms | Major | Medium |
| Dropdown Menu | Minor | Low |
| Property Cards | Minor | Low |
| Breadcrumbs | Minor | Low |
| View Toggle | Minor | Low |

---

## References

- [WAI-ARIA Authoring Practices - Combobox](https://www.w3.org/WAI/ARIA/apg/patterns/combobox/)
- [WAI-ARIA Authoring Practices - Carousel](https://www.w3.org/WAI/ARIA/apg/patterns/carousel/)
- [WAI-ARIA Authoring Practices - Tabs](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/)
- [WAI-ARIA Authoring Practices - Modal Dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)
