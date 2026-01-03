// LocalStorage Service - Centralized localStorage wrapper with consent checking
// Handles data expiration, quota management, and GDPR compliance

const CONSENT_KEY = "pwb_storage_consent"
const DATA_PREFIX = "pwb_"
const DEFAULT_EXPIRY_DAYS = 90

class LocalStorageService {
  constructor() {
    this.isAvailable = this.checkAvailability()
  }

  // Check if localStorage is available
  checkAvailability() {
    try {
      const test = "__storage_test__"
      localStorage.setItem(test, test)
      localStorage.removeItem(test)
      return true
    } catch (e) {
      return false
    }
  }

  // Get consent status
  getConsent() {
    if (!this.isAvailable) return { essential: true, preferences: false }

    try {
      const consent = localStorage.getItem(CONSENT_KEY)
      if (consent) {
        return JSON.parse(consent)
      }
    } catch (e) {
      console.warn("Error reading consent:", e)
    }

    return null // No consent decision made yet
  }

  // Set consent status
  setConsent(consentData) {
    if (!this.isAvailable) return false

    try {
      const consent = {
        essential: true, // Always true
        preferences: consentData.preferences || false,
        timestamp: new Date().toISOString(),
        version: "1.0"
      }
      localStorage.setItem(CONSENT_KEY, JSON.stringify(consent))

      // Dispatch event for other components to react
      window.dispatchEvent(new CustomEvent("pwb:consent-updated", { detail: consent }))

      return true
    } catch (e) {
      console.error("Error saving consent:", e)
      return false
    }
  }

  // Check if preferences consent is given
  hasPreferencesConsent() {
    const consent = this.getConsent()
    return consent?.preferences === true
  }

  // Check if consent decision has been made
  hasConsentDecision() {
    return this.getConsent() !== null
  }

  // Revoke consent and clear all preference data
  revokeConsent() {
    if (!this.isAvailable) return

    // Clear all PWB data except consent record
    this.clearAllData()

    // Update consent to preferences: false
    this.setConsent({ preferences: false })
  }

  // Get item with consent check
  get(key, requireConsent = true) {
    if (!this.isAvailable) return null

    if (requireConsent && !this.hasPreferencesConsent()) {
      return null
    }

    try {
      const fullKey = DATA_PREFIX + key
      const item = localStorage.getItem(fullKey)

      if (!item) return null

      const parsed = JSON.parse(item)

      // Check expiration
      if (parsed._expires && new Date(parsed._expires) < new Date()) {
        this.remove(key)
        return null
      }

      return parsed.data
    } catch (e) {
      console.warn(`Error reading ${key}:`, e)
      return null
    }
  }

  // Set item with consent check and optional expiration
  set(key, data, options = {}) {
    if (!this.isAvailable) return false

    const requireConsent = options.requireConsent !== false
    if (requireConsent && !this.hasPreferencesConsent()) {
      console.warn("Cannot save data: preferences consent not given")
      return false
    }

    try {
      const fullKey = DATA_PREFIX + key
      const expiryDays = options.expiryDays || DEFAULT_EXPIRY_DAYS

      const item = {
        data: data,
        _created: new Date().toISOString(),
        _expires: this.calculateExpiry(expiryDays)
      }

      localStorage.setItem(fullKey, JSON.stringify(item))
      return true
    } catch (e) {
      if (e.name === "QuotaExceededError") {
        console.warn("Storage quota exceeded, cleaning old data...")
        this.cleanExpiredData()
        // Retry once
        try {
          localStorage.setItem(DATA_PREFIX + key, JSON.stringify({
            data: data,
            _created: new Date().toISOString(),
            _expires: this.calculateExpiry(options.expiryDays || DEFAULT_EXPIRY_DAYS)
          }))
          return true
        } catch (e2) {
          console.error("Storage still full after cleanup:", e2)
        }
      }
      console.error(`Error saving ${key}:`, e)
      return false
    }
  }

  // Remove item
  remove(key) {
    if (!this.isAvailable) return

    try {
      localStorage.removeItem(DATA_PREFIX + key)
    } catch (e) {
      console.warn(`Error removing ${key}:`, e)
    }
  }

  // Calculate expiry date
  calculateExpiry(days) {
    const date = new Date()
    date.setDate(date.getDate() + days)
    return date.toISOString()
  }

  // Clean expired data
  cleanExpiredData() {
    if (!this.isAvailable) return

    const now = new Date()
    const keysToRemove = []

    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith(DATA_PREFIX)) {
        try {
          const item = JSON.parse(localStorage.getItem(key))
          if (item._expires && new Date(item._expires) < now) {
            keysToRemove.push(key)
          }
        } catch (e) {
          // Invalid data, remove it
          keysToRemove.push(key)
        }
      }
    }

    keysToRemove.forEach(key => localStorage.removeItem(key))
    console.log(`Cleaned ${keysToRemove.length} expired items`)
  }

  // Clear all PWB data (except consent)
  clearAllData() {
    if (!this.isAvailable) return

    const keysToRemove = []

    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith(DATA_PREFIX) && key !== CONSENT_KEY) {
        keysToRemove.push(key)
      }
    }

    keysToRemove.forEach(key => localStorage.removeItem(key))

    // Dispatch event
    window.dispatchEvent(new CustomEvent("pwb:data-cleared"))
  }

  // Get storage usage info
  getStorageInfo() {
    if (!this.isAvailable) return { used: 0, items: 0 }

    let totalSize = 0
    let itemCount = 0

    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i)
      if (key && key.startsWith(DATA_PREFIX)) {
        const value = localStorage.getItem(key)
        totalSize += key.length + (value ? value.length : 0)
        itemCount++
      }
    }

    return {
      used: totalSize,
      usedKB: Math.round(totalSize / 1024 * 100) / 100,
      items: itemCount
    }
  }
}

// Export singleton instance
const localStorageService = new LocalStorageService()
export default localStorageService
