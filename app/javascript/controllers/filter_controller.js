import { Controller } from "@hotwired/stimulus"

// Filter controller for property search filters
// Handles filter panel visibility and form submission
// Usage:
//   <div data-controller="filter">
//     <button data-action="filter#togglePanel">Filters</button>
//     <div data-filter-target="panel" class="hidden">
//       <form data-filter-target="form" data-action="change->filter#submitOnChange">
//         <select name="bedrooms">...</select>
//         <select name="price_from">...</select>
//       </form>
//     </div>
//     <span data-filter-target="count">0 filters</span>
//     <button data-action="filter#clear">Clear All</button>
//   </div>
//
export default class extends Controller {
  static targets = ["panel", "form", "count", "input"]
  static values = { 
    submitOnChange: { type: Boolean, default: false },
    debounce: { type: Number, default: 300 }
  }

  connect() {
    this.updateCount()
  }

  togglePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden")
    }
  }

  showPanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
    }
  }

  hidePanel() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
    }
  }

  submitOnChange() {
    if (this.submitOnChangeValue) {
      this.debounceSubmit()
    }
    this.updateCount()
  }

  submit() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  debounceSubmit() {
    clearTimeout(this.submitTimeout)
    this.submitTimeout = setTimeout(() => this.submit(), this.debounceValue)
  }

  clear() {
    if (this.hasFormTarget) {
      // Reset all form inputs
      this.formTarget.reset()
      
      // Clear select elements to their first option
      this.formTarget.querySelectorAll("select").forEach(select => {
        select.selectedIndex = 0
      })
      
      // Clear checkboxes
      this.formTarget.querySelectorAll('input[type="checkbox"]').forEach(cb => {
        cb.checked = false
      })
    }
    
    this.updateCount()
    this.submit()
  }

  updateCount() {
    if (!this.hasCountTarget || !this.hasFormTarget) return

    let count = 0
    const formData = new FormData(this.formTarget)
    
    for (const [key, value] of formData.entries()) {
      if (value && value !== "" && value !== "none") {
        count++
      }
    }

    this.countTarget.textContent = count === 0 
      ? "No filters" 
      : `${count} filter${count === 1 ? "" : "s"}`
  }
}
