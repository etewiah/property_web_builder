import { Controller } from "@hotwired/stimulus"

// Manages the shard dashboard with auto-refresh and real-time updates
export default class extends Controller {
  static targets = ["refreshButton"]

  connect() {
    // Optional: Auto-refresh every 30 seconds
    // this.startAutoRefresh()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  refresh() {
    // Show loading state
    const button = this.element.querySelector('[data-action*="refresh"]')
    if (button) {
      button.classList.add('loading')
      button.disabled = true
    }

    // Reload the page (or use Turbo for partial updates)
    window.location.reload()
  }

  startAutoRefresh() {
    this.autoRefreshInterval = setInterval(() => {
      this.refresh()
    }, 30000) // 30 seconds
  }

  stopAutoRefresh() {
    if (this.autoRefreshInterval) {
      clearInterval(this.autoRefreshInterval)
    }
  }
}
