import { Controller } from "@hotwired/stimulus"

/**
 * SearchFormController
 * 
 * Handles AJAX search form submissions with loading states.
 * Replaces jQuery-based ajax:beforeSend and ajax:complete handlers.
 * 
 * Usage:
 *   <div data-controller="search-form">
 *     <form data-search-form-target="form" data-action="ajax:beforeSend->search-form#showLoading ajax:complete->search-form#hideLoading">
 *       ...
 *     </form>
 *     <div data-search-form-target="spinner" class="hidden">Loading...</div>
 *     <div data-search-form-target="results">Results here</div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["form", "results", "spinner"]

  connect() {
    // If form target exists, set up event listeners
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("ajax:beforeSend", this.showLoading.bind(this))
      this.formTarget.addEventListener("ajax:complete", this.hideLoading.bind(this))
      this.formTarget.addEventListener("ajax:success", this.handleSuccess.bind(this))
      this.formTarget.addEventListener("ajax:error", this.handleError.bind(this))
    }

    // Initialize any existing content
    this.truncateDescriptions()
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("ajax:beforeSend", this.showLoading.bind(this))
      this.formTarget.removeEventListener("ajax:complete", this.hideLoading.bind(this))
      this.formTarget.removeEventListener("ajax:success", this.handleSuccess.bind(this))
      this.formTarget.removeEventListener("ajax:error", this.handleError.bind(this))
    }
  }

  showLoading() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("opacity-50")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("opacity-50")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
  }

  handleSuccess(event) {
    // After successful AJAX response, re-truncate descriptions
    this.truncateDescriptions()
    this.sortResults()
    
    // Update URL with search params for bookmarkability
    this.updateUrlParams()
  }

  handleError(event) {
    console.error("Search form error:", event.detail)
    this.hideLoading()
  }

  /**
   * Truncate property descriptions to prevent layout issues
   * Replaces INMOAPP.truncateDescriptions()
   */
  truncateDescriptions() {
    const maxLength = 150
    const descriptions = this.element.querySelectorAll(".property-description")
    
    descriptions.forEach(desc => {
      const text = desc.textContent.trim()
      if (text.length > maxLength) {
        desc.textContent = text.substring(0, maxLength) + "..."
      }
    })
  }

  /**
   * Sort search results by price
   * Replaces INMOAPP.sortSearchResults()
   */
  sortResults() {
    const wrapper = this.element.querySelector("#ordered-properties")
    if (!wrapper) return

    const items = Array.from(wrapper.querySelectorAll(".property-item"))
    if (items.length === 0) return

    // Get current sort order from URL or default
    const urlParams = new URLSearchParams(window.location.search)
    const sortOrder = urlParams.get("sort") || "price-asc"

    items.sort((a, b) => {
      const priceA = parseFloat(a.dataset.price) || 0
      const priceB = parseFloat(b.dataset.price) || 0

      if (sortOrder === "price-desc") {
        return priceB - priceA
      }
      return priceA - priceB
    })

    items.forEach(item => wrapper.appendChild(item))
  }

  /**
   * Update URL with current search parameters for bookmarkability
   */
  updateUrlParams() {
    if (!this.hasFormTarget) return

    const formData = new FormData(this.formTarget)
    const params = new URLSearchParams()

    for (const [key, value] of formData.entries()) {
      if (value && key.startsWith("search[")) {
        params.append(key, value)
      }
    }

    const newUrl = window.location.pathname + "?" + params.toString()
    window.history.pushState({ path: newUrl }, "", newUrl)
  }

  /**
   * Toggle filter sidebar visibility (for mobile)
   */
  toggleFilters() {
    const sidebar = document.getElementById("sidebar-filters")
    if (sidebar) {
      sidebar.classList.toggle("hidden")
      sidebar.classList.toggle("block")
    }
  }
}
