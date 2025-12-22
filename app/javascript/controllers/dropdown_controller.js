import { Controller } from "@hotwired/stimulus"

// Dropdown controller for menus and select-like interfaces
// Usage:
//   <div data-controller="dropdown" data-action="click@window->dropdown#closeOnClickOutside">
//     <button data-action="dropdown#toggle" data-dropdown-target="button">
//       Select an option
//     </button>
//     <div data-dropdown-target="menu" class="hidden">
//       <a data-action="dropdown#select" data-value="option1">Option 1</a>
//       <a data-action="dropdown#select" data-value="option2">Option 2</a>
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["button", "menu", "input"]
  static values = { open: Boolean }

  connect() {
    this.openValue = false
  }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden", !this.openValue)
    }
    
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", this.openValue)
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
    }
  }
}
