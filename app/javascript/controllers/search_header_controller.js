import { Controller } from "@hotwired/stimulus"

/**
 * Search Header Controller
 *
 * Handles sort and view toggle controls in the search results header.
 * Works independently of the main search controller to avoid Turbo Frame issues.
 */
export default class extends Controller {
  static targets = ["sortSelect", "viewButton"]

  /**
   * Handle sort dropdown change
   * Updates the URL with the new sort parameter and reloads the Turbo Frame
   */
  sort(event) {
    const sortValue = event.target.value
    this.updateUrlAndReload({ sort: sortValue })
  }

  /**
   * Handle view toggle button click
   * Updates the URL with the new view parameter and reloads the Turbo Frame
   */
  setView(event) {
    event.preventDefault()
    const view = event.currentTarget.dataset.view

    // Update button states immediately for visual feedback
    this.updateViewButtonStates(view)

    // Update URL and reload
    this.updateUrlAndReload({ view: view })
  }

  /**
   * Update view button visual states
   */
  updateViewButtonStates(activeView) {
    const buttons = this.element.querySelectorAll('[data-view]')
    buttons.forEach(btn => {
      const isActive = btn.dataset.view === activeView
      btn.setAttribute('aria-pressed', isActive)

      if (isActive) {
        btn.classList.remove('bg-white', 'text-gray-700')
        btn.classList.add('bg-blue-50', 'text-blue-700', 'border-blue-500')
      } else {
        btn.classList.remove('bg-blue-50', 'text-blue-700', 'border-blue-500')
        btn.classList.add('bg-white', 'text-gray-700')
      }
    })
  }

  /**
   * Update URL with new parameters and reload the Turbo Frame
   */
  updateUrlAndReload(newParams) {
    const url = new URL(window.location.href)

    // Update or remove parameters
    Object.entries(newParams).forEach(([key, value]) => {
      if (value && value.trim() !== '') {
        url.searchParams.set(key, value)
      } else {
        url.searchParams.delete(key)
      }
    })

    // Reset to page 1 when changing sort/view
    url.searchParams.delete('page')

    const newUrl = url.toString()

    // Use Turbo to navigate - it handles history and page updates
    if (typeof Turbo !== 'undefined') {
      Turbo.visit(newUrl)
    } else {
      // Fallback: navigate directly
      window.location.href = newUrl
    }
  }
}
