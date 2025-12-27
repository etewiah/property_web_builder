import { Controller } from "@hotwired/stimulus"

/**
 * Currency Selector Controller
 *
 * Handles currency preference selection and persists choice via form submission.
 * Works with the _currency_selector.html.erb partial.
 *
 * Targets:
 *   - select: The dropdown select element
 *   - form: Hidden form for submitting currency change
 *   - input: Hidden input holding selected currency
 *   - menu: Dropdown menu for minimal style
 */
export default class extends Controller {
  static targets = ["select", "form", "input", "menu"]

  /**
   * Handle dropdown change event
   */
  change(event) {
    const currency = event.target.value
    this.setCurrency(currency)
  }

  /**
   * Handle button click for button/minimal styles
   */
  select(event) {
    const currency = event.currentTarget.dataset.currency
    this.setCurrency(currency)
  }

  /**
   * Toggle dropdown menu for minimal style
   */
  toggle() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden")
    }
  }

  /**
   * Set the currency and submit form
   */
  setCurrency(currency) {
    if (!currency) return

    // Update hidden input and submit form
    if (this.hasInputTarget && this.hasFormTarget) {
      this.inputTarget.value = currency
      this.formTarget.requestSubmit()
    }
  }

  /**
   * Handle successful form submission
   * Turbo will handle the response, but we reload for full page update
   */
  formSuccess() {
    // Reload page to show new currency throughout
    window.location.reload()
  }

  /**
   * Close menu when clicking outside
   */
  clickOutside(event) {
    if (this.hasMenuTarget && !this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
    }
  }

  connect() {
    // Listen for clicks outside to close menu
    document.addEventListener("click", this.clickOutside.bind(this))
  }

  disconnect() {
    document.removeEventListener("click", this.clickOutside.bind(this))
  }
}
