# Keyboard Shortcuts

This document outlines the keyboard shortcuts implementation plan for PropertyWebBuilder to improve user experience and accessibility.

## Overview

Keyboard shortcuts enhance usability for:
- Power users who prefer keyboard navigation
- Users with motor disabilities (WCAG 2.1 compliance)
- Users with repetitive strain injuries
- Anyone wanting faster navigation

## Implementation Phases

### Phase 1: High Priority (Core User Journeys) ✅ COMPLETE

#### Property Gallery Navigation
**Location:** `app/javascript/controllers/gallery_controller.js`

| Shortcut | Action |
|----------|--------|
| `←` | Previous photo |
| `→` | Next photo |
| `Escape` | Close lightbox/fullscreen |
| `Home` | First photo |
| `End` | Last photo |

**Implementation notes:**
- Only active when gallery is in focus or lightbox is open
- Should not interfere with text input fields

#### Search Interface
**Location:** `app/javascript/controllers/search_controller.js`, `filter_controller.js`

| Shortcut | Action |
|----------|--------|
| `/` | Focus search input |
| `Enter` | Submit search |
| `Escape` | Clear filters / close dropdowns |

**Implementation notes:**
- `/` shortcut is common in many web apps (GitHub, Slack, etc.)
- Should be disabled when user is typing in an input field

#### Page Editor (Admin)
**Location:** `app/javascript/controllers/` (new controller or extend existing)

| Shortcut | Action |
|----------|--------|
| `Ctrl+S` / `Cmd+S` | Save content |
| `Escape` | Close modal (image picker, etc.) |
| `Ctrl+Z` / `Cmd+Z` | Undo (if implemented) |

**Implementation notes:**
- Must prevent default browser save dialog
- Save shortcut should show visual feedback

### Phase 2: Medium Priority ✅ COMPLETE

#### Favorites
**Location:** `app/javascript/controllers/keyboard_controller.js` (global handler)

| Shortcut | Action |
|----------|--------|
| `F` | Toggle favorite on current property |

**Implementation notes:**
- Triggered via keyboard controller, calls local_favorites controller
- Only works on pages with a local-favorites controller present
- Shows toast notification feedback

#### Tab Navigation
**Location:** `app/javascript/controllers/tabs_controller.js`

| Shortcut | Action |
|----------|--------|
| `←` / `→` | Navigate tabs (when tab is focused) |
| `Home` | First tab |
| `End` | Last tab |

**Implementation notes:**
- Added ARIA roles for accessibility (role="tab", role="tabpanel")
- Manages tabindex for proper keyboard navigation
- Added `handleKeydown` action for keyboard events

#### Dropdown Menus
**Location:** `app/javascript/controllers/dropdown_controller.js`

| Shortcut | Action |
|----------|--------|
| `↑` / `↓` | Navigate options |
| `Enter` / `Space` | Select highlighted option / Open menu |
| `Escape` | Close dropdown |
| `Home` / `End` | First / Last option |

**Implementation notes:**
- Added `item` target for menu options
- Visual highlight with `bg-gray-100` class
- Auto-scrolls highlighted item into view
- Returns focus to button after selection

### Phase 3: Nice-to-Have

#### Map Controls
**Location:** `app/javascript/controllers/leaflet_map_controller.js`

| Shortcut | Action |
|----------|--------|
| `+` / `=` | Zoom in |
| `-` | Zoom out |
| `M` | Toggle map/list view |

#### Global Navigation

| Shortcut | Action |
|----------|--------|
| `?` | Show keyboard shortcuts help |
| `G` then `H` | Go to home |
| `G` then `S` | Go to search |
| `G` then `F` | Go to favorites |

## Technical Implementation

### Base Keyboard Controller

Create a reusable Stimulus controller for keyboard handling:

```javascript
// app/javascript/controllers/keyboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    shortcuts: Object // { "ctrl+s": "save", "escape": "close" }
  }

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    // Skip if user is typing in an input
    if (this.isTyping(event)) return

    const key = this.normalizeKey(event)
    const action = this.shortcutsValue[key]

    if (action && typeof this[action] === "function") {
      event.preventDefault()
      this[action](event)
    }
  }

  isTyping(event) {
    const target = event.target
    const tagName = target.tagName.toLowerCase()
    return tagName === "input" ||
           tagName === "textarea" ||
           tagName === "select" ||
           target.isContentEditable
  }

  normalizeKey(event) {
    const parts = []
    if (event.ctrlKey || event.metaKey) parts.push("ctrl")
    if (event.shiftKey) parts.push("shift")
    if (event.altKey) parts.push("alt")
    parts.push(event.key.toLowerCase())
    return parts.join("+")
  }
}
```

### Extending Existing Controllers

For gallery navigation, extend the existing controller:

```javascript
// In gallery_controller.js
handleKeydown(event) {
  if (event.key === "ArrowLeft") {
    event.preventDefault()
    this.previous()
  } else if (event.key === "ArrowRight") {
    event.preventDefault()
    this.next()
  } else if (event.key === "Escape") {
    event.preventDefault()
    this.closeLightbox()
  }
}
```

### Help Modal

Create a shortcuts help modal accessible via `?` key:

```html
<!-- app/views/shared/_keyboard_shortcuts_help.html.erb -->
<div id="keyboard-shortcuts-modal" class="hidden fixed inset-0 z-50 ...">
  <div class="bg-white rounded-lg shadow-xl max-w-lg mx-auto mt-20 p-6">
    <h2 class="text-xl font-semibold mb-4">Keyboard Shortcuts</h2>

    <div class="space-y-4">
      <section>
        <h3 class="font-medium text-gray-700">Gallery</h3>
        <dl class="grid grid-cols-2 gap-2 text-sm">
          <dt><kbd>←</kbd> / <kbd>→</kbd></dt>
          <dd>Previous / Next photo</dd>
          <dt><kbd>Esc</kbd></dt>
          <dd>Close lightbox</dd>
        </dl>
      </section>

      <section>
        <h3 class="font-medium text-gray-700">Search</h3>
        <dl class="grid grid-cols-2 gap-2 text-sm">
          <dt><kbd>/</kbd></dt>
          <dd>Focus search</dd>
          <dt><kbd>Esc</kbd></dt>
          <dd>Clear filters</dd>
        </dl>
      </section>
    </div>

    <button class="mt-4 text-gray-500" data-action="click->keyboard#closeHelp">
      Close (or press Esc)
    </button>
  </div>
</div>
```

## Accessibility Considerations

### WCAG 2.1 Compliance

1. **Keyboard Accessible (2.1.1):** All functionality available via keyboard
2. **No Keyboard Trap (2.1.2):** Users can always navigate away
3. **Focus Visible (2.4.7):** Clear focus indicators on all interactive elements
4. **Focus Order (2.4.3):** Logical tab order

### Best Practices

- Never remove focus outlines without providing alternative styling
- Announce shortcut actions to screen readers when appropriate
- Provide visual feedback for keyboard actions
- Document all shortcuts in help modal
- Use standard shortcuts where possible (Escape to close, Enter to submit)

## Testing

### Manual Testing Checklist

- [ ] All shortcuts work as documented
- [ ] Shortcuts don't interfere with browser defaults
- [ ] Shortcuts are disabled in text inputs
- [ ] Help modal shows all available shortcuts
- [ ] Focus indicators are visible
- [ ] Screen reader announces actions appropriately

### Playwright E2E Tests

```javascript
// tests/e2e/features/keyboard-shortcuts.spec.js
test.describe('Keyboard Shortcuts', () => {
  test('gallery navigation with arrow keys', async ({ page }) => {
    await page.goto('/properties/1')
    await page.locator('.gallery').focus()

    await page.keyboard.press('ArrowRight')
    // Assert second image is visible

    await page.keyboard.press('ArrowLeft')
    // Assert first image is visible
  })

  test('search focus with slash key', async ({ page }) => {
    await page.goto('/search')
    await page.keyboard.press('/')

    await expect(page.locator('input[name="search"]')).toBeFocused()
  })

  test('help modal with question mark', async ({ page }) => {
    await page.goto('/')
    await page.keyboard.press('?')

    await expect(page.locator('#keyboard-shortcuts-modal')).toBeVisible()
  })
})
```

## Related Files

- `app/javascript/controllers/gallery_controller.js`
- `app/javascript/controllers/search_controller.js`
- `app/javascript/controllers/filter_controller.js`
- `app/javascript/controllers/dropdown_controller.js`
- `app/javascript/controllers/tabs_controller.js`
- `app/javascript/controllers/local_favorites_controller.js`
- `app/views/pwb/editor/show.html.erb`

## References

- [WCAG 2.1 Keyboard Accessibility](https://www.w3.org/WAI/WCAG21/Understanding/keyboard)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [GitHub Keyboard Shortcuts](https://docs.github.com/en/get-started/accessibility/keyboard-shortcuts) (inspiration)
