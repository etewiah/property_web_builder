import { Controller } from "@hotwired/stimulus"

/**
 * Keyboard Controller
 *
 * Global keyboard shortcuts and help modal functionality.
 * Attach to the body element for global shortcuts.
 *
 * Usage:
 *   <body data-controller="keyboard">
 *     ...
 *     <div data-keyboard-target="helpModal" class="hidden">...</div>
 *   </body>
 */
export default class extends Controller {
  static targets = ["helpModal", "searchInput"]

  connect() {
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
  }

  handleKeydown(event) {
    // Don't handle if user is typing in an input
    if (this.isTyping(event)) {
      // But allow Escape to blur inputs
      if (event.key === "Escape") {
        event.target.blur()
      }
      return
    }

    // Global shortcuts
    switch (event.key) {
      case "?":
        // Show help modal
        if (event.shiftKey || this.isShiftRequired(event)) {
          this.toggleHelp()
          event.preventDefault()
        }
        break

      case "/":
        // Focus search input
        this.focusSearch(event)
        break

      case "Escape":
        // Close any open modals/dropdowns
        this.closeAll()
        break

      case "f":
      case "F":
        // Toggle favorite (only on property pages)
        this.toggleFavorite(event)
        break
    }
  }

  /**
   * Toggle favorite for the current property
   */
  toggleFavorite(event) {
    // Find the local-favorites controller on the page
    const favoritesElement = document.querySelector('[data-controller*="local-favorites"]')
    if (!favoritesElement) return

    // Get the Stimulus controller instance
    const controller = this.application.getControllerForElementAndIdentifier(
      favoritesElement,
      "local-favorites"
    )

    if (controller && typeof controller.toggle === "function") {
      event.preventDefault()
      controller.toggle()
    }
  }

  /**
   * Check if user is typing in an input field
   */
  isTyping(event) {
    const target = event.target
    const tagName = target.tagName.toLowerCase()
    return tagName === "input" ||
           tagName === "textarea" ||
           tagName === "select" ||
           target.isContentEditable
  }

  /**
   * Check if shift key should be required for ? (varies by keyboard layout)
   */
  isShiftRequired(event) {
    // On most keyboards, ? requires shift, but we check the actual key
    return event.key === "?"
  }

  /**
   * Focus the search input
   */
  focusSearch(event) {
    // Try to find search input by various selectors
    const searchInput = this.hasSearchInputTarget
      ? this.searchInputTarget
      : document.querySelector(
          'input[name="search"], ' +
          'input[name="q"], ' +
          'input[type="search"], ' +
          'input[placeholder*="Search"], ' +
          'input[placeholder*="search"], ' +
          '.search-input, ' +
          '#search-input'
        )

    if (searchInput) {
      event.preventDefault()
      searchInput.focus()
      searchInput.select()
    }
  }

  /**
   * Toggle help modal visibility
   */
  toggleHelp() {
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.toggle("hidden")

      if (!this.helpModalTarget.classList.contains("hidden")) {
        // Focus the modal for accessibility
        this.helpModalTarget.setAttribute("tabindex", "-1")
        this.helpModalTarget.focus()
      }
    } else {
      // Create and show inline help if no modal target
      this.showInlineHelp()
    }
  }

  /**
   * Close help modal
   */
  closeHelp() {
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.add("hidden")
    }
    this.removeInlineHelp()
  }

  /**
   * Close all open modals and dropdowns
   */
  closeAll() {
    // Close help modal
    this.closeHelp()

    // Dispatch event for other controllers to listen to
    this.dispatch("escape", { bubbles: true })

    // Close any open dropdowns
    document.querySelectorAll('[data-dropdown-open-value="true"]').forEach(el => {
      const controller = this.application.getControllerForElementAndIdentifier(el, "dropdown")
      if (controller) controller.close()
    })
  }

  /**
   * Show inline help popup when no modal target exists
   */
  showInlineHelp() {
    // Remove existing if present
    this.removeInlineHelp()

    const helpHtml = `
      <div id="keyboard-shortcuts-help" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" data-action="click->keyboard#closeHelp keydown.escape->keyboard#closeHelp">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4 p-6" data-action="click->keyboard#stopPropagation">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-semibold text-gray-900">Keyboard Shortcuts</h2>
            <button type="button" class="text-gray-400 hover:text-gray-600" data-action="click->keyboard#closeHelp">
              <span class="sr-only">Close</span>
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <div class="space-y-4 text-sm">
            <section>
              <h3 class="font-medium text-gray-700 mb-2">Global</h3>
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1">
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">/</kbd></dt>
                <dd class="text-gray-600">Focus search</dd>
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">?</kbd></dt>
                <dd class="text-gray-600">Show this help</dd>
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">Esc</kbd></dt>
                <dd class="text-gray-600">Close dialogs</dd>
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">F</kbd></dt>
                <dd class="text-gray-600">Toggle favorite</dd>
              </dl>
            </section>

            <section>
              <h3 class="font-medium text-gray-700 mb-2">Gallery</h3>
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1">
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2190</kbd> / <kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2192</kbd></dt>
                <dd class="text-gray-600">Previous / Next</dd>
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">Home</kbd> / <kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">End</kbd></dt>
                <dd class="text-gray-600">First / Last</dd>
              </dl>
            </section>

            <section>
              <h3 class="font-medium text-gray-700 mb-2">Tabs</h3>
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1">
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2190</kbd> / <kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2192</kbd></dt>
                <dd class="text-gray-600">Previous / Next tab</dd>
              </dl>
            </section>

            <section>
              <h3 class="font-medium text-gray-700 mb-2">Dropdowns</h3>
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1">
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2191</kbd> / <kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">\u2193</kbd></dt>
                <dd class="text-gray-600">Navigate options</dd>
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">Enter</kbd></dt>
                <dd class="text-gray-600">Select option</dd>
              </dl>
            </section>

            <section>
              <h3 class="font-medium text-gray-700 mb-2">Editor</h3>
              <dl class="grid grid-cols-2 gap-x-4 gap-y-1">
                <dt><kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">Ctrl</kbd>+<kbd class="px-2 py-0.5 bg-gray-100 rounded text-xs">S</kbd></dt>
                <dd class="text-gray-600">Save content</dd>
              </dl>
            </section>
          </div>

          <p class="mt-4 text-xs text-gray-400">Press <kbd class="px-1 py-0.5 bg-gray-100 rounded">Esc</kbd> to close</p>
        </div>
      </div>
    `

    document.body.insertAdjacentHTML("beforeend", helpHtml)
  }

  /**
   * Remove inline help popup
   */
  removeInlineHelp() {
    document.getElementById("keyboard-shortcuts-help")?.remove()
  }

  /**
   * Stop event propagation (for modal content clicks)
   */
  stopPropagation(event) {
    event.stopPropagation()
  }
}
