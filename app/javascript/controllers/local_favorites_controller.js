import { Controller } from "@hotwired/stimulus"
import localStorageService from "services/local_storage_service"

const FAVORITES_KEY = "favorites"
const MAX_FAVORITES = 100

// Local Favorites Controller - Manages locally stored property favorites
export default class extends Controller {
  static targets = [
    "toggleButton",
    "icon",
    "count",
    "list",
    "emptyState",
    "consentPrompt"
  ]

  static values = {
    propertyRef: String,
    propertyTitle: String,
    propertyImage: String,
    propertyPrice: String,
    propertyUrl: String
  }

  connect() {
    // Update UI based on current state
    this.updateToggleState()
    this.updateCount()

    // Listen for consent changes
    window.addEventListener("pwb:consent-updated", () => this.handleConsentChange())
    window.addEventListener("pwb:data-cleared", () => this.handleDataCleared())
    window.addEventListener("pwb:favorites-updated", () => this.updateAll())
  }

  // Toggle favorite status for current property
  toggle(event) {
    event?.preventDefault()
    event?.stopPropagation()

    // Check consent first
    if (!localStorageService.hasPreferencesConsent()) {
      this.promptForConsent()
      return
    }

    const ref = this.propertyRefValue
    if (!ref) {
      console.warn("No property reference provided")
      return
    }

    const favorites = this.getFavorites()
    const existingIndex = favorites.findIndex(f => f.ref === ref)

    if (existingIndex >= 0) {
      // Remove from favorites
      favorites.splice(existingIndex, 1)
      this.showToast("Removed from favorites")
    } else {
      // Add to favorites
      if (favorites.length >= MAX_FAVORITES) {
        this.showToast(`Maximum ${MAX_FAVORITES} favorites reached. Remove some to add more.`)
        return
      }

      favorites.unshift({
        ref: ref,
        title: this.propertyTitleValue || "Property",
        image: this.propertyImageValue || null,
        price: this.propertyPriceValue || null,
        url: this.propertyUrlValue || null,
        savedAt: new Date().toISOString()
      })
      this.showToast("Added to favorites")
    }

    this.saveFavorites(favorites)
    this.updateAll()
    this.dispatchUpdate()
  }

  // Check if property is favorited
  isFavorited() {
    if (!this.propertyRefValue) return false

    const favorites = this.getFavorites()
    return favorites.some(f => f.ref === this.propertyRefValue)
  }

  // Get all favorites
  getFavorites() {
    return localStorageService.get(FAVORITES_KEY, true) || []
  }

  // Save favorites
  saveFavorites(favorites) {
    localStorageService.set(FAVORITES_KEY, favorites, { expiryDays: 365 })
  }

  // Remove a specific favorite
  remove(event) {
    const ref = event.currentTarget.dataset.ref
    if (!ref) return

    const favorites = this.getFavorites().filter(f => f.ref !== ref)
    this.saveFavorites(favorites)
    this.updateAll()
    this.dispatchUpdate()
    this.showToast("Removed from favorites")
  }

  // Clear all favorites
  clearAll() {
    if (confirm("Remove all favorites?")) {
      localStorageService.remove(FAVORITES_KEY)
      this.updateAll()
      this.dispatchUpdate()
      this.showToast("All favorites cleared")
    }
  }

  // Update toggle button state
  updateToggleState() {
    if (!this.hasToggleButtonTarget) return

    const isFav = this.isFavorited()

    // Update button appearance
    this.toggleButtonTarget.classList.toggle("is-favorited", isFav)
    this.toggleButtonTarget.setAttribute("aria-pressed", isFav)

    // Update icon if present
    if (this.hasIconTarget) {
      if (isFav) {
        this.iconTarget.classList.remove("text-gray-400", "hover:text-red-500")
        this.iconTarget.classList.add("text-red-500", "fill-current")
      } else {
        this.iconTarget.classList.add("text-gray-400", "hover:text-red-500")
        this.iconTarget.classList.remove("text-red-500", "fill-current")
      }
    }
  }

  // Update favorites count display
  updateCount() {
    if (!this.hasCountTarget) return

    const count = this.getFavorites().length
    this.countTarget.textContent = count
    this.countTarget.classList.toggle("hidden", count === 0)
  }

  // Update favorites list display
  updateList() {
    if (!this.hasListTarget) return

    const favorites = this.getFavorites()

    if (favorites.length === 0) {
      this.listTarget.innerHTML = ""
      if (this.hasEmptyStateTarget) {
        this.emptyStateTarget.classList.remove("hidden")
      }
      return
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add("hidden")
    }

    this.listTarget.innerHTML = favorites.map(fav => this.renderFavoriteItem(fav)).join("")
  }

  // Render a single favorite item
  renderFavoriteItem(fav) {
    const imageHtml = fav.image
      ? `<img src="${this.escapeHtml(fav.image)}" alt="" class="w-16 h-16 object-cover rounded">`
      : `<div class="w-16 h-16 bg-gray-200 rounded flex items-center justify-center text-gray-400">
           <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
             <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
           </svg>
         </div>`

    return `
      <div class="flex items-center gap-3 p-3 bg-white rounded-lg shadow-sm border border-gray-100">
        ${fav.url ? `<a href="${this.escapeHtml(fav.url)}" class="flex-shrink-0">${imageHtml}</a>` : imageHtml}
        <div class="flex-1 min-w-0">
          ${fav.url
            ? `<a href="${this.escapeHtml(fav.url)}" class="font-medium text-gray-900 hover:text-purple-600 truncate block">${this.escapeHtml(fav.title)}</a>`
            : `<span class="font-medium text-gray-900 truncate block">${this.escapeHtml(fav.title)}</span>`
          }
          ${fav.price ? `<p class="text-sm text-gray-500">${this.escapeHtml(fav.price)}</p>` : ""}
        </div>
        <button type="button"
                data-action="local-favorites#remove"
                data-ref="${this.escapeHtml(fav.ref)}"
                class="flex-shrink-0 p-2 text-gray-400 hover:text-red-500 transition"
                aria-label="Remove from favorites">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `
  }

  // Update all UI elements
  updateAll() {
    this.updateToggleState()
    this.updateCount()
    this.updateList()
  }

  // Handle consent change
  handleConsentChange() {
    this.updateAll()
  }

  // Handle data cleared
  handleDataCleared() {
    this.updateAll()
  }

  // Dispatch update event for other controllers
  dispatchUpdate() {
    window.dispatchEvent(new CustomEvent("pwb:favorites-updated", {
      detail: { count: this.getFavorites().length }
    }))
  }

  // Prompt user for consent
  promptForConsent() {
    if (this.hasConsentPromptTarget) {
      this.consentPromptTarget.classList.remove("hidden")
    } else {
      // Show inline prompt or redirect to consent
      this.showToast("Please accept preferences to save favorites locally", "info")
      window.dispatchEvent(new CustomEvent("pwb:show-consent-banner"))
    }
  }

  // Show toast notification
  showToast(message, type = "success") {
    const colors = {
      success: "bg-green-600",
      info: "bg-blue-600",
      error: "bg-red-600"
    }

    const toast = document.createElement("div")
    toast.className = `fixed bottom-4 right-4 ${colors[type]} text-white px-6 py-3 rounded-lg shadow-lg z-50`
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.style.opacity = "0"
      toast.style.transition = "opacity 0.3s"
      setTimeout(() => toast.remove(), 300)
    }, 2500)
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
