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
  }

  disconnect() {
    this.stopAutoplay()
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
