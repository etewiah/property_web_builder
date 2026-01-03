import { Controller } from "@hotwired/stimulus"
import localStorageService from "services/local_storage_service"

// Consent Controller - Manages GDPR-compliant consent for localStorage
export default class extends Controller {
  static targets = ["banner", "preferencesCheckbox", "settingsPanel"]

  static values = {
    autoShow: { type: Boolean, default: true }
  }

  connect() {
    // Check if consent decision has been made
    if (this.autoShowValue && !localStorageService.hasConsentDecision()) {
      this.showBanner()
    }

    // Update UI based on current consent
    this.updateUI()

    // Listen for consent updates from other sources
    window.addEventListener("pwb:consent-updated", () => this.updateUI())
  }

  // Show the consent banner
  showBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.remove("hidden")
      this.bannerTarget.setAttribute("aria-hidden", "false")
    }
  }

  // Hide the consent banner
  hideBanner() {
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("hidden")
      this.bannerTarget.setAttribute("aria-hidden", "true")
    }
  }

  // Accept all (including preferences)
  acceptAll() {
    localStorageService.setConsent({ preferences: true })
    this.hideBanner()
    this.showConfirmation("Preferences saved! Your favorites will be stored locally.")
  }

  // Accept essential only (decline preferences)
  acceptEssential() {
    localStorageService.setConsent({ preferences: false })
    this.hideBanner()
  }

  // Open settings panel for granular control
  openSettings() {
    if (this.hasSettingsPanelTarget) {
      this.settingsPanelTarget.classList.remove("hidden")
      this.updateSettingsUI()
    }
  }

  // Close settings panel
  closeSettings() {
    if (this.hasSettingsPanelTarget) {
      this.settingsPanelTarget.classList.add("hidden")
    }
  }

  // Save settings from panel
  saveSettings() {
    const preferences = this.hasPreferencesCheckboxTarget
      ? this.preferencesCheckboxTarget.checked
      : false

    localStorageService.setConsent({ preferences })
    this.closeSettings()
    this.hideBanner()
    this.showConfirmation(preferences
      ? "Preferences saved! Your favorites will be stored locally."
      : "Settings saved. Local storage is disabled.")
  }

  // Clear all stored data
  clearData() {
    if (confirm("This will delete all your locally saved favorites and searches. Continue?")) {
      localStorageService.clearAllData()
      this.showConfirmation("All local data has been deleted.")
      this.updateUI()
    }
  }

  // Revoke consent entirely
  revokeConsent() {
    if (confirm("This will disable local storage and delete all saved data. Continue?")) {
      localStorageService.revokeConsent()
      this.showConfirmation("Consent revoked. All local data has been deleted.")
      this.updateUI()
    }
  }

  // Update UI based on current consent state
  updateUI() {
    const consent = localStorageService.getConsent()

    // Update checkbox if present
    if (this.hasPreferencesCheckboxTarget && consent) {
      this.preferencesCheckboxTarget.checked = consent.preferences
    }

    // Dispatch event for other controllers
    this.dispatch("updated", { detail: consent })
  }

  // Update settings panel UI
  updateSettingsUI() {
    const consent = localStorageService.getConsent()
    if (this.hasPreferencesCheckboxTarget) {
      this.preferencesCheckboxTarget.checked = consent?.preferences || false
    }
  }

  // Show a temporary confirmation message
  showConfirmation(message) {
    // Create toast notification
    const toast = document.createElement("div")
    toast.className = "fixed bottom-4 right-4 bg-green-600 text-white px-6 py-3 rounded-lg shadow-lg z-50 animate-fade-in"
    toast.textContent = message
    document.body.appendChild(toast)

    // Remove after 3 seconds
    setTimeout(() => {
      toast.classList.add("animate-fade-out")
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  // Check if preferences consent is given (for other controllers to use)
  get hasPreferencesConsent() {
    return localStorageService.hasPreferencesConsent()
  }
}
