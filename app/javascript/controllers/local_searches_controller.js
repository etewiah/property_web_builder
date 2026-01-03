import { Controller } from "@hotwired/stimulus"
import localStorageService from "services/local_storage_service"

const SEARCHES_KEY = "saved_searches"
const RECENT_KEY = "recent_searches"
const MAX_SAVED = 20
const MAX_RECENT = 10

// Local Searches Controller - Manages locally stored search criteria
export default class extends Controller {
  static targets = [
    "dropdown",
    "savedList",
    "recentList",
    "emptyState",
    "saveButton",
    "nameInput",
    "saveForm"
  ]

  static values = {
    currentCriteria: String, // JSON string of current search criteria
    searchUrl: String        // Base URL for searches
  }

  connect() {
    this.updateUI()

    // Listen for events
    window.addEventListener("pwb:consent-updated", () => this.updateUI())
    window.addEventListener("pwb:data-cleared", () => this.updateUI())
    window.addEventListener("pwb:searches-updated", () => this.updateUI())

    // Track current search as recent
    if (this.currentCriteriaValue) {
      this.trackRecentSearch()
    }
  }

  // Toggle dropdown visibility
  toggleDropdown(event) {
    event?.preventDefault()

    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle("hidden")
    }
  }

  // Close dropdown
  closeDropdown() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  // Show save form
  showSaveForm() {
    if (!localStorageService.hasPreferencesConsent()) {
      this.promptForConsent()
      return
    }

    if (this.hasSaveFormTarget) {
      this.saveFormTarget.classList.remove("hidden")
      if (this.hasNameInputTarget) {
        this.nameInputTarget.focus()
      }
    }
  }

  // Hide save form
  hideSaveForm() {
    if (this.hasSaveFormTarget) {
      this.saveFormTarget.classList.add("hidden")
    }
  }

  // Save current search
  saveSearch(event) {
    event?.preventDefault()

    if (!localStorageService.hasPreferencesConsent()) {
      this.promptForConsent()
      return
    }

    const name = this.hasNameInputTarget ? this.nameInputTarget.value.trim() : ""
    if (!name) {
      this.showToast("Please enter a name for this search", "error")
      return
    }

    const criteria = this.parseCriteria()
    if (!criteria) {
      this.showToast("No search criteria to save", "error")
      return
    }

    const saved = this.getSavedSearches()

    // Check for duplicates
    const duplicate = saved.find(s => s.name.toLowerCase() === name.toLowerCase())
    if (duplicate) {
      if (!confirm(`A search named "${name}" already exists. Replace it?`)) {
        return
      }
      // Remove the duplicate
      const index = saved.indexOf(duplicate)
      saved.splice(index, 1)
    }

    // Check max limit
    if (saved.length >= MAX_SAVED) {
      this.showToast(`Maximum ${MAX_SAVED} saved searches. Delete some to add more.`, "error")
      return
    }

    // Add new search
    saved.unshift({
      id: this.generateId(),
      name: name,
      criteria: criteria,
      url: this.buildSearchUrl(criteria),
      savedAt: new Date().toISOString(),
      lastUsed: null
    })

    this.saveSavedSearches(saved)
    this.hideSaveForm()
    this.updateUI()
    this.dispatchUpdate()
    this.showToast(`Search "${name}" saved!`)

    // Clear input
    if (this.hasNameInputTarget) {
      this.nameInputTarget.value = ""
    }
  }

  // Apply a saved search (navigate to it)
  applySearch(event) {
    event?.preventDefault()

    const id = event.currentTarget.dataset.searchId
    const saved = this.getSavedSearches()
    const search = saved.find(s => s.id === id)

    if (search) {
      // Update last used
      search.lastUsed = new Date().toISOString()
      this.saveSavedSearches(saved)

      // Navigate
      if (search.url) {
        window.location.href = search.url
      }
    }
  }

  // Apply a recent search
  applyRecent(event) {
    event?.preventDefault()

    const index = parseInt(event.currentTarget.dataset.index, 10)
    const recent = this.getRecentSearches()
    const search = recent[index]

    if (search?.url) {
      window.location.href = search.url
    }
  }

  // Delete a saved search
  deleteSearch(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const id = event.currentTarget.dataset.searchId
    const saved = this.getSavedSearches().filter(s => s.id !== id)
    this.saveSavedSearches(saved)
    this.updateUI()
    this.dispatchUpdate()
    this.showToast("Search deleted")
  }

  // Clear recent searches
  clearRecent() {
    localStorageService.remove(RECENT_KEY)
    this.updateUI()
    this.showToast("Recent searches cleared")
  }

  // Clear all saved searches
  clearAll() {
    if (confirm("Delete all saved searches?")) {
      localStorageService.remove(SEARCHES_KEY)
      localStorageService.remove(RECENT_KEY)
      this.updateUI()
      this.dispatchUpdate()
      this.showToast("All searches cleared")
    }
  }

  // Track current search as recent
  trackRecentSearch() {
    if (!localStorageService.hasPreferencesConsent()) return

    const criteria = this.parseCriteria()
    if (!criteria || Object.keys(criteria).length === 0) return

    const recent = this.getRecentSearches()

    // Create search entry
    const entry = {
      criteria: criteria,
      url: this.buildSearchUrl(criteria),
      label: this.buildSearchLabel(criteria),
      timestamp: new Date().toISOString()
    }

    // Remove duplicate if exists
    const existingIndex = recent.findIndex(r =>
      JSON.stringify(r.criteria) === JSON.stringify(criteria)
    )
    if (existingIndex >= 0) {
      recent.splice(existingIndex, 1)
    }

    // Add to front
    recent.unshift(entry)

    // Trim to max
    while (recent.length > MAX_RECENT) {
      recent.pop()
    }

    this.saveRecentSearches(recent)
  }

  // Get saved searches
  getSavedSearches() {
    return localStorageService.get(SEARCHES_KEY, true) || []
  }

  // Save saved searches
  saveSavedSearches(searches) {
    localStorageService.set(SEARCHES_KEY, searches, { expiryDays: 365 })
  }

  // Get recent searches
  getRecentSearches() {
    return localStorageService.get(RECENT_KEY, true) || []
  }

  // Save recent searches
  saveRecentSearches(searches) {
    localStorageService.set(RECENT_KEY, searches, { expiryDays: 30 })
  }

  // Parse current criteria
  parseCriteria() {
    if (!this.currentCriteriaValue) return null

    try {
      return JSON.parse(this.currentCriteriaValue)
    } catch (e) {
      console.warn("Invalid search criteria:", e)
      return null
    }
  }

  // Build search URL from criteria
  buildSearchUrl(criteria) {
    if (!this.searchUrlValue) return null

    const params = new URLSearchParams()
    Object.entries(criteria).forEach(([key, value]) => {
      if (value !== null && value !== undefined && value !== "") {
        if (Array.isArray(value)) {
          value.forEach(v => params.append(`${key}[]`, v))
        } else {
          params.set(key, value)
        }
      }
    })

    return `${this.searchUrlValue}?${params.toString()}`
  }

  // Build human-readable label for criteria
  buildSearchLabel(criteria) {
    const parts = []

    if (criteria.listing_type) {
      parts.push(criteria.listing_type === "sale" ? "For Sale" : "For Rent")
    }
    if (criteria.bedrooms_min) {
      parts.push(`${criteria.bedrooms_min}+ beds`)
    }
    if (criteria.price_min || criteria.price_max) {
      const min = criteria.price_min ? `${criteria.price_min}` : ""
      const max = criteria.price_max ? `${criteria.price_max}` : ""
      if (min && max) {
        parts.push(`${min}-${max}`)
      } else if (min) {
        parts.push(`${min}+`)
      } else if (max) {
        parts.push(`Up to ${max}`)
      }
    }
    if (criteria.location) {
      parts.push(criteria.location)
    }

    return parts.length > 0 ? parts.join(" | ") : "Search"
  }

  // Update UI
  updateUI() {
    this.updateSavedList()
    this.updateRecentList()
    this.updateEmptyState()
  }

  // Update saved searches list
  updateSavedList() {
    if (!this.hasSavedListTarget) return

    const saved = this.getSavedSearches()

    if (saved.length === 0) {
      this.savedListTarget.innerHTML = `
        <p class="text-sm text-gray-500 py-2">No saved searches yet</p>
      `
      return
    }

    this.savedListTarget.innerHTML = saved.map(search => `
      <div class="flex items-center justify-between p-2 hover:bg-gray-50 rounded group">
        <a href="${this.escapeHtml(search.url || '#')}"
           data-action="local-searches#applySearch"
           data-search-id="${search.id}"
           class="flex-1 text-sm text-gray-700 hover:text-purple-600 truncate">
          ${this.escapeHtml(search.name)}
        </a>
        <button type="button"
                data-action="local-searches#deleteSearch"
                data-search-id="${search.id}"
                class="opacity-0 group-hover:opacity-100 p-1 text-gray-400 hover:text-red-500 transition"
                aria-label="Delete search">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    `).join("")
  }

  // Update recent searches list
  updateRecentList() {
    if (!this.hasRecentListTarget) return

    const recent = this.getRecentSearches()

    if (recent.length === 0) {
      this.recentListTarget.innerHTML = `
        <p class="text-sm text-gray-500 py-2">No recent searches</p>
      `
      return
    }

    this.recentListTarget.innerHTML = recent.map((search, index) => `
      <a href="${this.escapeHtml(search.url || '#')}"
         data-action="local-searches#applyRecent"
         data-index="${index}"
         class="block p-2 text-sm text-gray-600 hover:text-purple-600 hover:bg-gray-50 rounded truncate">
        ${this.escapeHtml(search.label)}
      </a>
    `).join("")
  }

  // Update empty state visibility
  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return

    const saved = this.getSavedSearches()
    const recent = this.getRecentSearches()

    this.emptyStateTarget.classList.toggle("hidden", saved.length > 0 || recent.length > 0)
  }

  // Dispatch update event
  dispatchUpdate() {
    window.dispatchEvent(new CustomEvent("pwb:searches-updated", {
      detail: { count: this.getSavedSearches().length }
    }))
  }

  // Prompt for consent
  promptForConsent() {
    this.showToast("Please accept preferences to save searches locally", "info")
    window.dispatchEvent(new CustomEvent("pwb:show-consent-banner"))
  }

  // Generate unique ID
  generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2)
  }

  // Show toast
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

  // Escape HTML
  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
