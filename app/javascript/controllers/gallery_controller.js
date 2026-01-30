import { Controller } from "@hotwired/stimulus"

// Gallery controller for property photo carousels
// Usage:
//   <div data-controller="gallery" data-gallery-index-value="0">
//     <div data-gallery-target="slide">
//       <img src="photo1.jpg">
//     </div>
//     <div data-gallery-target="slide" class="hidden">
//       <img src="photo2.jpg">
//     </div>
//     <button data-action="gallery#previous">&lt;</button>
//     <button data-action="gallery#next">&gt;</button>
//     <div data-gallery-target="counter">1 / 2</div>
//   </div>
//
// Keyboard shortcuts (when gallery is focused or hovered):
//   ArrowLeft  - Previous slide
//   ArrowRight - Next slide
//   Home       - First slide
//   End        - Last slide
//
export default class extends Controller {
  static targets = ["slide", "counter", "thumbnail"]
  static values = {
    index: { type: Number, default: 0 },
    autoplay: { type: Boolean, default: false },
    interval: { type: Number, default: 5000 }
  }

  connect() {
    this.showSlide(this.indexValue)

    if (this.autoplayValue) {
      this.startAutoplay()
    }

    // Bind keyboard handler
    this.boundHandleKeydown = this.handleKeydown.bind(this)

    // Make element focusable if not already
    if (!this.element.hasAttribute("tabindex")) {
      this.element.setAttribute("tabindex", "0")
    }

    // Listen for keyboard events when element is focused
    this.element.addEventListener("keydown", this.boundHandleKeydown)

    // Also listen when hovering (for better UX)
    this.isHovered = false
    this.boundHandleMouseEnter = () => { this.isHovered = true }
    this.boundHandleMouseLeave = () => { this.isHovered = false }
    this.element.addEventListener("mouseenter", this.boundHandleMouseEnter)
    this.element.addEventListener("mouseleave", this.boundHandleMouseLeave)

    // Global keydown for when hovered
    this.boundGlobalKeydown = this.handleGlobalKeydown.bind(this)
    document.addEventListener("keydown", this.boundGlobalKeydown)
  }

  disconnect() {
    this.stopAutoplay()
    this.element.removeEventListener("keydown", this.boundHandleKeydown)
    this.element.removeEventListener("mouseenter", this.boundHandleMouseEnter)
    this.element.removeEventListener("mouseleave", this.boundHandleMouseLeave)
    document.removeEventListener("keydown", this.boundGlobalKeydown)
  }

  /**
   * Handle keyboard navigation when gallery is focused
   */
  handleKeydown(event) {
    this.processKeydown(event)
  }

  /**
   * Handle global keydown when gallery is hovered
   */
  handleGlobalKeydown(event) {
    // Only process if hovering and not typing in an input
    if (!this.isHovered || this.isTyping(event)) return
    this.processKeydown(event)
  }

  /**
   * Process keyboard events for gallery navigation
   */
  processKeydown(event) {
    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        this.previous()
        break
      case "ArrowRight":
        event.preventDefault()
        this.next()
        break
      case "Home":
        event.preventDefault()
        this.first()
        break
      case "End":
        event.preventDefault()
        this.last()
        break
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
   * Go to first slide
   */
  first() {
    this.indexValue = 0
  }

  /**
   * Go to last slide
   */
  last() {
    this.indexValue = this.slideTargets.length - 1
  }

  next() {
    const nextIndex = (this.indexValue + 1) % this.slideTargets.length
    this.indexValue = nextIndex
  }

  previous() {
    const prevIndex = (this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length
    this.indexValue = prevIndex
  }

  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this.indexValue = index
  }

  indexValueChanged() {
    this.showSlide(this.indexValue)
  }

  showSlide(index) {
    // Show/hide slides
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== index)
    })

    // Update counter
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${index + 1} / ${this.slideTargets.length}`
    }

    // Update thumbnail active state
    this.thumbnailTargets.forEach((thumb, i) => {
      thumb.classList.toggle("ring-2", i === index)
      thumb.classList.toggle("ring-blue-500", i === index)
      thumb.classList.toggle("opacity-50", i !== index)
    })
  }

  startAutoplay() {
    this.autoplayTimer = setInterval(() => this.next(), this.intervalValue)
  }

  stopAutoplay() {
    if (this.autoplayTimer) {
      clearInterval(this.autoplayTimer)
    }
  }

  // Pause on hover
  pause() {
    this.stopAutoplay()
  }

  resume() {
    if (this.autoplayValue) {
      this.startAutoplay()
    }
  }
}
