import { Controller } from "@hotwired/stimulus"

// Skeleton loading controller
// Shows skeleton placeholder while content loads, then reveals actual content
//
// Basic Usage:
//   <div data-controller="skeleton">
//     <div data-skeleton-target="placeholder">
//       <!-- Skeleton HTML here -->
//     </div>
//     <div data-skeleton-target="content" class="hidden">
//       <!-- Actual content here -->
//     </div>
//   </div>
//
// Auto-reveal after delay:
//   <div data-controller="skeleton" data-skeleton-delay-value="500">
//
// Reveal when image loads:
//   <div data-controller="skeleton">
//     <div data-skeleton-target="placeholder">...</div>
//     <img data-skeleton-target="content" data-action="load->skeleton#loaded" class="hidden" src="...">
//   </div>
//
// Reveal on Turbo frame load:
//   <turbo-frame data-controller="skeleton" data-action="turbo:frame-load->skeleton#loaded">
//     <div data-skeleton-target="placeholder">...</div>
//     <div data-skeleton-target="content" class="hidden">
//       <!-- Content loaded via Turbo -->
//     </div>
//   </turbo-frame>
//
// Manual reveal (e.g., after fetch):
//   this.skeletonController.loaded()
//
export default class extends Controller {
  static targets = ["placeholder", "content"]
  static values = {
    delay: { type: Number, default: 0 },
    animate: { type: Boolean, default: true }
  }

  connect() {
    // If delay is set, auto-reveal after delay
    if (this.delayValue > 0) {
      this.timeout = setTimeout(() => this.loaded(), this.delayValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Call this to reveal content and hide skeleton
  loaded() {
    if (this.hasPlaceholderTarget) {
      if (this.animateValue) {
        // Fade out skeleton
        this.placeholderTargets.forEach(el => {
          el.style.transition = "opacity 150ms ease-out"
          el.style.opacity = "0"
          setTimeout(() => el.classList.add("hidden"), 150)
        })
      } else {
        this.placeholderTargets.forEach(el => el.classList.add("hidden"))
      }
    }

    if (this.hasContentTarget) {
      this.contentTargets.forEach(el => {
        el.classList.remove("hidden")
        if (this.animateValue) {
          el.style.opacity = "0"
          el.style.transition = "opacity 150ms ease-in"
          // Trigger reflow then fade in
          requestAnimationFrame(() => {
            el.style.opacity = "1"
          })
        }
      })
    }

    // Dispatch event for other controllers to listen to
    this.dispatch("loaded")
  }

  // Show skeleton again (useful for refresh/reload scenarios)
  loading() {
    if (this.hasPlaceholderTarget) {
      this.placeholderTargets.forEach(el => {
        el.classList.remove("hidden")
        el.style.opacity = "1"
      })
    }

    if (this.hasContentTarget) {
      this.contentTargets.forEach(el => el.classList.add("hidden"))
    }

    this.dispatch("loading")
  }
}
