import { Controller } from "@hotwired/stimulus"

// Dropdown controller for menus and select-like interfaces
// Usage:
//   <div data-controller="dropdown"
//        data-action="click@window->dropdown#closeOnClickOutside keydown->dropdown#handleKeydown">
//     <button data-action="dropdown#toggle" data-dropdown-target="button">
//       Select an option
//     </button>
//     <div data-dropdown-target="menu" class="hidden">
//       <a data-dropdown-target="item" data-action="dropdown#select" data-value="option1">Option 1</a>
//       <a data-dropdown-target="item" data-action="dropdown#select" data-value="option2">Option 2</a>
//     </div>
//   </div>
//
// Keyboard shortcuts:
//   ArrowDown  - Open menu / Move to next item
//   ArrowUp    - Move to previous item
//   Enter      - Select highlighted item / Open menu
//   Space      - Toggle menu / Select highlighted item
//   Escape     - Close menu
//   Home       - Move to first item
//   End        - Move to last item
//
export default class extends Controller {
  static targets = ["button", "menu", "input", "item"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false
    this.highlightedIndex = -1
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
    this.highlightedIndex = -1
    this.updateHighlight()
  }

  openValueChanged() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden", !this.openValue)
    }

    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.openValue)
    }

    // Reset highlight when opening
    if (this.openValue) {
      this.highlightedIndex = -1
      this.updateHighlight()
    }
  }

  /**
   * Handle keyboard navigation
   */
  handleKeydown(event) {
    // Only handle when focused on the dropdown
    if (!this.element.contains(document.activeElement)) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (!this.openValue) {
          this.open()
        } else {
          this.highlightNext()
        }
        break

      case "ArrowUp":
        event.preventDefault()
        if (this.openValue) {
          this.highlightPrevious()
        }
        break

      case "Enter":
        event.preventDefault()
        if (!this.openValue) {
          this.open()
        } else if (this.highlightedIndex >= 0) {
          this.selectHighlighted()
        }
        break

      case " ": // Space
        event.preventDefault()
        if (!this.openValue) {
          this.open()
        } else if (this.highlightedIndex >= 0) {
          this.selectHighlighted()
        }
        break

      case "Escape":
        if (this.openValue) {
          event.preventDefault()
          this.close()
          this.buttonTarget?.focus()
        }
        break

      case "Home":
        if (this.openValue) {
          event.preventDefault()
          this.highlightFirst()
        }
        break

      case "End":
        if (this.openValue) {
          event.preventDefault()
          this.highlightLast()
        }
        break

      case "Tab":
        // Allow tab to close the dropdown naturally
        if (this.openValue) {
          this.close()
        }
        break
    }
  }

  /**
   * Highlight the next item
   */
  highlightNext() {
    if (!this.hasItemTarget) return

    const items = this.itemTargets
    this.highlightedIndex = this.highlightedIndex < items.length - 1
      ? this.highlightedIndex + 1
      : 0
    this.updateHighlight()
  }

  /**
   * Highlight the previous item
   */
  highlightPrevious() {
    if (!this.hasItemTarget) return

    const items = this.itemTargets
    this.highlightedIndex = this.highlightedIndex > 0
      ? this.highlightedIndex - 1
      : items.length - 1
    this.updateHighlight()
  }

  /**
   * Highlight the first item
   */
  highlightFirst() {
    if (!this.hasItemTarget) return
    this.highlightedIndex = 0
    this.updateHighlight()
  }

  /**
   * Highlight the last item
   */
  highlightLast() {
    if (!this.hasItemTarget) return
    this.highlightedIndex = this.itemTargets.length - 1
    this.updateHighlight()
  }

  /**
   * Update the visual highlight on items
   */
  updateHighlight() {
    if (!this.hasItemTarget) return

    this.itemTargets.forEach((item, index) => {
      if (index === this.highlightedIndex) {
        item.classList.add("bg-gray-100", "text-gray-900")
        item.setAttribute("aria-selected", "true")
        // Scroll into view if needed
        item.scrollIntoView({ block: "nearest" })
      } else {
        item.classList.remove("bg-gray-100", "text-gray-900")
        item.setAttribute("aria-selected", "false")
      }
    })
  }

  /**
   * Select the currently highlighted item
   */
  selectHighlighted() {
    if (this.highlightedIndex < 0 || !this.hasItemTarget) return

    const item = this.itemTargets[this.highlightedIndex]
    if (item) {
      const value = item.dataset.value
      const label = item.textContent.trim()

      // Update hidden input if present
      if (this.hasInputTarget) {
        this.inputTarget.value = value
      }

      // Update button label
      if (this.hasButtonTarget) {
        this.buttonTarget.textContent = label
      }

      // Dispatch custom event
      this.dispatch("selected", { detail: { value, label } })

      this.close()
      this.buttonTarget?.focus()
    }
  }

  select(event) {
    event.preventDefault()
    const value = event.currentTarget.dataset.value
    const label = event.currentTarget.textContent.trim()

    // Update hidden input if present
    if (this.hasInputTarget) {
      this.inputTarget.value = value
    }

    // Update button label
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = label
    }

    // Dispatch custom event for other controllers to listen to
    this.dispatch("selected", { detail: { value, label } })

    this.close()
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target) && this.openValue) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close()
      this.buttonTarget?.focus()
    }
  }
}
