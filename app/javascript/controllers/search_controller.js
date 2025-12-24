import { Controller } from "@hotwired/stimulus"

/**
 * Search Controller
 * 
 * Handles property search functionality with:
 * - URL state management (bookmarkable/shareable searches)
 * - Turbo Frame integration for seamless updates
 * - Debounced filter changes
 * - Mobile filter panel toggle
 * - Browser history navigation (back/forward)
 */
export default class extends Controller {
  static targets = [
    "form",
    "filterPanel",
    "filterToggle",
    "backdrop",
    "results",
    "loading",
    "map"
  ]

  static values = {
    operation: String,  // "buy" or "rent"
    locale: String,     // Current locale (e.g., "en", "es")
    debounceMs: { type: Number, default: 300 }
  }

  connect() {
    this.debounceTimer = null
    this.abortController = null
    
    // Listen for browser back/forward navigation
    window.addEventListener('popstate', this.handlePopState.bind(this))
    
    // Listen for Turbo Frame load events
    document.addEventListener('turbo:frame-load', this.handleFrameLoad.bind(this))
    document.addEventListener('turbo:before-fetch-request', this.handleBeforeFetch.bind(this))
    document.addEventListener('turbo:frame-render', this.handleFrameRender.bind(this))
  }

  disconnect() {
    window.removeEventListener('popstate', this.handlePopState.bind(this))
    document.removeEventListener('turbo:frame-load', this.handleFrameLoad.bind(this))
    document.removeEventListener('turbo:before-fetch-request', this.handleBeforeFetch.bind(this))
    document.removeEventListener('turbo:frame-render', this.handleFrameRender.bind(this))
    
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    if (this.abortController) {
      this.abortController.abort()
    }
  }

  // ===================
  // Filter Handlers
  // ===================

  /**
   * Called when any filter input changes
   * Debounces the update to avoid too many requests
   */
  filterChanged(event) {
    // Clear any pending updates
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Debounce the filter update
    this.debounceTimer = setTimeout(() => {
      this.submitForm()
    }, this.debounceValue || 300)
  }

  /**
   * Called when sort or view changes (no debounce needed)
   */
  sortChanged(event) {
    this.submitForm()
  }

  /**
   * Set view mode (grid/list/map)
   */
  setView(event) {
    const view = event.currentTarget.dataset.view
    if (!this.hasFormTarget) return

    const viewInput = this.formTarget.querySelector('input[name="view"]') ||
                      document.createElement('input')

    if (!viewInput.name) {
      viewInput.type = 'hidden'
      viewInput.name = 'view'
      this.formTarget.appendChild(viewInput)
    }

    viewInput.value = view
    this.submitForm()
  }

  /**
   * Submit the form - uses native form submission which Turbo intercepts
   */
  submitForm() {
    if (!this.hasFormTarget) {
      console.warn('Search form target not found')
      return
    }

    // Use requestSubmit() which triggers the submit event (works with Turbo)
    if (typeof this.formTarget.requestSubmit === 'function') {
      this.formTarget.requestSubmit()
    } else {
      // Fallback for older browsers
      this.formTarget.submit()
    }
  }

  /**
   * Clear all filters and reset to default state
   */
  clearFilters(event) {
    if (event) event.preventDefault()

    // Reset form
    if (this.hasFormTarget) {
      this.formTarget.reset()

      // Clear hidden inputs
      this.formTarget.querySelectorAll('input[type="hidden"]').forEach(input => {
        if (input.name !== '_method' && input.name !== 'authenticity_token') {
          input.value = ''
        }
      })

      // Uncheck all checkboxes
      this.formTarget.querySelectorAll('input[type="checkbox"]').forEach(cb => {
        cb.checked = false
      })

      // Reset select elements to first option
      this.formTarget.querySelectorAll('select').forEach(select => {
        select.selectedIndex = 0
      })

      // Reset radio buttons to first (usually "Any")
      this.formTarget.querySelectorAll('input[type="radio"][value=""]').forEach(radio => {
        radio.checked = true
      })

      // Submit the cleared form
      this.submitForm()
    } else {
      // Fallback: navigate to clean URL
      const cleanUrl = `/${this.localeValue}/${this.operationValue}`
      if (typeof Turbo !== 'undefined') {
        Turbo.visit(cleanUrl)
      } else {
        window.location.href = cleanUrl
      }
    }
  }

  /**
   * Handle form submission - Turbo handles the actual navigation
   */
  handleSubmit(event) {
    // Turbo Drive will handle the form submission automatically
    // No additional action needed
  }

  // ===================
  // Mobile Filter Panel
  // ===================

  /**
   * Toggle mobile filter panel visibility
   */
  toggleFilters(event) {
    if (event) event.preventDefault()

    const isOpen = this.hasFilterPanelTarget && 
                   !this.filterPanelTarget.classList.contains('hidden')

    if (isOpen) {
      this.closeFilters()
    } else {
      this.openFilters()
    }
  }

  openFilters() {
    if (this.hasFilterPanelTarget) {
      this.filterPanelTarget.classList.remove('hidden')
      this.filterPanelTarget.classList.add('fixed', 'inset-0', 'z-50', 'bg-white', 'overflow-y-auto', 'lg:relative', 'lg:inset-auto', 'lg:z-auto', 'lg:overflow-visible')
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('hidden')
    }
    if (this.hasFilterToggleTarget) {
      this.filterToggleTarget.setAttribute('aria-expanded', 'true')
    }
    // Prevent body scroll on mobile
    document.body.classList.add('overflow-hidden', 'lg:overflow-auto')
  }

  closeFilters() {
    if (this.hasFilterPanelTarget) {
      this.filterPanelTarget.classList.add('hidden')
      this.filterPanelTarget.classList.remove('fixed', 'inset-0', 'z-50', 'overflow-y-auto')
    }
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add('hidden')
    }
    if (this.hasFilterToggleTarget) {
      this.filterToggleTarget.setAttribute('aria-expanded', 'false')
    }
    document.body.classList.remove('overflow-hidden')
  }

  /**
   * Apply filters and close panel on mobile
   */
  applyAndClose(event) {
    this.closeFilters()
    // Form submission will be handled by Turbo
  }

  // ===================
  // URL State Management
  // ===================

  /**
   * Build URL from current form state
   */
  buildUrlFromForm() {
    if (!this.hasFormTarget) return window.location.pathname

    const formData = new FormData(this.formTarget)
    const params = new URLSearchParams()

    for (const [key, value] of formData.entries()) {
      if (value && value.trim() !== '' && key !== 'authenticity_token' && key !== '_method') {
        // Handle array params (like features[])
        if (key.endsWith('[]')) {
          const cleanKey = key.replace('[]', '')
          const existing = params.get(cleanKey)
          if (existing) {
            params.set(cleanKey, `${existing},${value}`)
          } else {
            params.set(cleanKey, value)
          }
        } else {
          params.set(key, value)
        }
      }
    }

    // Sort params for consistent URLs
    const sortedParams = new URLSearchParams([...params.entries()].sort())
    const queryString = sortedParams.toString()
    
    return queryString ? `${window.location.pathname}?${queryString}` : window.location.pathname
  }

  /**
   * Update the search results
   */
  updateSearch() {
    const url = this.buildUrlFromForm()

    // Use Turbo to navigate - it handles history and page updates
    if (typeof Turbo !== 'undefined') {
      Turbo.visit(url)
    } else {
      window.location.href = url
    }
  }

  /**
   * Navigate with history state
   */
  navigateWithHistory(url) {
    // Use Turbo to navigate - it handles history and page updates
    if (typeof Turbo !== 'undefined') {
      Turbo.visit(url)
    } else {
      window.location.href = url
    }
  }

  /**
   * Push state to browser history
   */
  pushState(url) {
    if (window.location.href !== new URL(url, window.location.origin).href) {
      history.pushState({ turbo: true }, '', url)
    }
  }

  /**
   * Handle browser back/forward navigation
   */
  handlePopState(event) {
    // Turbo Drive handles the navigation, just sync form state
    this.syncFormWithUrl()
  }

  /**
   * Sync form controls with current URL parameters
   */
  syncFormWithUrl() {
    if (!this.hasFormTarget) return

    const params = new URLSearchParams(window.location.search)

    // Reset form first
    this.formTarget.reset()

    // Apply URL params to form
    for (const [key, value] of params.entries()) {
      const input = this.formTarget.querySelector(`[name="${key}"], [name="${key}[]"]`)
      
      if (input) {
        if (input.type === 'checkbox') {
          // Handle checkbox (features)
          const values = value.split(',')
          this.formTarget.querySelectorAll(`[name="${key}[]"]`).forEach(cb => {
            cb.checked = values.includes(cb.value)
          })
        } else if (input.type === 'radio') {
          // Handle radio buttons
          const radio = this.formTarget.querySelector(`[name="${key}"][value="${value}"]`)
          if (radio) radio.checked = true
        } else {
          input.value = value
        }
      }
    }
  }

  // ===================
  // Loading States
  // ===================

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add('opacity-50')
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove('opacity-50')
    }
  }

  // ===================
  // Turbo Event Handlers
  // ===================

  handleBeforeFetch(event) {
    // Cancel any pending request
    if (this.abortController) {
      this.abortController.abort()
    }
    this.abortController = new AbortController()
    
    this.showLoading()
  }

  handleFrameLoad(event) {
    if (event.target.id === 'search-results') {
      this.hideLoading()
      
      // Update map markers if present
      this.updateMapMarkers()
      
      // Announce to screen readers
      this.announceResults()
    }
  }

  handleFrameRender(event) {
    if (event.target.id === 'search-results') {
      this.hideLoading()
    }
  }

  // ===================
  // Map Integration
  // ===================

  updateMapMarkers() {
    // Dispatch event for map controller to handle
    const event = new CustomEvent('search:results-updated', {
      bubbles: true,
      detail: { source: 'search-controller' }
    })
    this.element.dispatchEvent(event)
  }

  // ===================
  // Accessibility
  // ===================

  announceResults() {
    const countElement = document.querySelector('.results-count')
    if (countElement) {
      // The aria-live region will announce automatically
      // But we can also programmatically focus if needed
    }
  }
}
