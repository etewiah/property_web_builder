import { Controller } from "@hotwired/stimulus"

// Price Game Controller - Handles "Guess the Price" game interactions
export default class extends Controller {
  static targets = [
    "gallery",
    "form",
    "result",
    "formContainer",
    "input",
    "submitBtn",
    "error",
    "copyBtn",
    "copyText"
  ]

  static values = {
    token: String,
    currency: String,
    hasGuessed: Boolean,
    guessUrl: String,
    shareUrl: String
  }

  connect() {
    // Initialize Swiper gallery if present
    if (this.hasGalleryTarget) {
      this.initGallery()
    }

    // Focus input if not already guessed
    if (!this.hasGuessedValue && this.hasInputTarget) {
      setTimeout(() => this.inputTarget.focus(), 500)
    }
  }

  initGallery() {
    if (typeof Swiper === "undefined") {
      // Wait for Swiper to load
      setTimeout(() => this.initGallery(), 100)
      return
    }

    new Swiper(this.galleryTarget, {
      loop: true,
      pagination: {
        el: ".swiper-pagination",
        clickable: true
      },
      navigation: {
        nextEl: ".swiper-button-next",
        prevEl: ".swiper-button-prev"
      }
    })
  }

  // Format input as user types (add thousands separators)
  formatInput(event) {
    const input = event.target
    let value = input.value.replace(/[^\d]/g, "")

    if (value) {
      // Add thousands separators
      value = parseInt(value, 10).toLocaleString()
    }

    input.value = value
    this.clearError()
  }

  // Handle Enter key to submit
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.submitGuess()
    }
  }

  // Submit the guess
  async submitGuess() {
    if (!this.hasInputTarget) return

    const rawValue = this.inputTarget.value.replace(/[^\d]/g, "")
    const guessedPrice = parseInt(rawValue, 10)

    if (!guessedPrice || guessedPrice <= 0) {
      this.showError("Please enter a valid price")
      return
    }

    // Disable button while submitting
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = true
      this.submitBtnTarget.textContent = "Submitting..."
    }

    try {
      const response = await fetch(this.guessUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({
          guessed_price: guessedPrice,
          currency: this.currencyValue
        })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.showResult(data.guess, data.leaderboard)
      } else {
        this.showError(data.error || "Something went wrong")
        if (this.hasSubmitBtnTarget) {
          this.submitBtnTarget.disabled = false
          this.submitBtnTarget.textContent = "🎯 Submit My Guess"
        }
      }
    } catch (error) {
      console.error("Error submitting guess:", error)
      this.showError("Network error. Please try again.")
      if (this.hasSubmitBtnTarget) {
        this.submitBtnTarget.disabled = false
        this.submitBtnTarget.textContent = "🎯 Submit My Guess"
      }
    }
  }

  // Show the result after a successful guess
  showResult(guess, leaderboard) {
    if (!this.hasFormTarget || !this.hasResultTarget) return

    // Build result HTML
    const resultHtml = this.buildResultHtml(guess)
    this.resultTarget.innerHTML = resultHtml
    this.resultTarget.classList.remove("hidden")
    this.formTarget.classList.add("hidden")

    // Scroll to result
    this.formContainerTarget.scrollIntoView({ behavior: "smooth", block: "center" })

    // Trigger confetti for high scores
    if (guess.score >= 70) {
      this.triggerConfetti()
    }
  }

  buildResultHtml(guess) {
    const emoji = guess.emoji || this.getEmoji(guess.score)
    const resultTitle = this.getResultTitle(guess.score)
    const colorClass = this.getColorClass(guess.score)

    return `
      <div class="text-center">
        <div class="text-6xl mb-4">${emoji}</div>
        <h3 class="text-3xl font-bold ${colorClass} mb-2">${resultTitle}</h3>

        <div class="inline-flex items-center justify-center px-6 py-2 bg-purple-100 text-purple-800 rounded-full text-lg font-bold mb-6">
          <span class="mr-2">🎯</span>
          Score: ${guess.score}/100
        </div>

        <div class="grid grid-cols-2 gap-4 max-w-md mx-auto mb-6">
          <div class="bg-gray-50 rounded-xl p-4">
            <p class="text-sm text-gray-500 mb-1">Your Guess</p>
            <p class="text-2xl font-bold text-gray-900">${guess.guessed_price}</p>
          </div>
          <div class="bg-green-50 rounded-xl p-4">
            <p class="text-sm text-gray-500 mb-1">Actual Price</p>
            <p class="text-2xl font-bold text-green-600">${guess.actual_price}</p>
          </div>
        </div>

        <p class="text-lg text-gray-600 mb-6">${guess.feedback}</p>
      </div>
    `
  }

  getEmoji(score) {
    if (score >= 90) return "🎉"
    if (score >= 70) return "👏"
    if (score >= 50) return "👍"
    if (score >= 30) return "🤔"
    return "💪"
  }

  getResultTitle(score) {
    if (score >= 90) return "Excellent!"
    if (score >= 70) return "Great Guess!"
    if (score >= 50) return "Good Effort!"
    if (score >= 30) return "Not Bad!"
    return "Keep Trying!"
  }

  getColorClass(score) {
    if (score >= 90) return "text-green-600"
    if (score >= 70) return "text-blue-600"
    if (score >= 50) return "text-yellow-600"
    if (score >= 30) return "text-orange-600"
    return "text-red-600"
  }

  triggerConfetti() {
    // Simple confetti effect using CSS animations
    const confettiContainer = document.createElement("div")
    confettiContainer.className = "fixed inset-0 pointer-events-none z-50"
    confettiContainer.innerHTML = this.generateConfettiHtml()
    document.body.appendChild(confettiContainer)

    setTimeout(() => confettiContainer.remove(), 3000)
  }

  generateConfettiHtml() {
    const colors = ["#a855f7", "#ec4899", "#3b82f6", "#22c55e", "#eab308"]
    let html = ""

    for (let i = 0; i < 50; i++) {
      const color = colors[Math.floor(Math.random() * colors.length)]
      const left = Math.random() * 100
      const delay = Math.random() * 0.5
      const duration = 2 + Math.random() * 2

      html += `
        <div class="absolute w-3 h-3 rounded-full animate-fall"
             style="background: ${color}; left: ${left}%; top: -10px; animation-delay: ${delay}s; animation-duration: ${duration}s;">
        </div>
      `
    }

    return `<style>
      @keyframes fall {
        to { transform: translateY(110vh) rotate(720deg); opacity: 0; }
      }
      .animate-fall { animation: fall linear forwards; }
    </style>${html}`
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.add("text-red-500")
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
    }
  }

  // Social sharing
  shareTwitter() {
    const text = "Can you guess the price of this property? 🏠🎯"
    const url = window.location.href
    window.open(
      `https://twitter.com/intent/tweet?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`,
      "_blank",
      "width=600,height=400"
    )
    this.trackShare()
  }

  shareFacebook() {
    const url = window.location.href
    window.open(
      `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`,
      "_blank",
      "width=600,height=400"
    )
    this.trackShare()
  }

  shareWhatsApp() {
    const text = "Can you guess the price of this property? 🏠🎯"
    const url = window.location.href
    window.open(
      `https://wa.me/?text=${encodeURIComponent(text + " " + url)}`,
      "_blank"
    )
    this.trackShare()
  }

  async copyLink() {
    const url = window.location.href

    try {
      await navigator.clipboard.writeText(url)

      if (this.hasCopyTextTarget) {
        const originalText = this.copyTextTarget.textContent
        this.copyTextTarget.textContent = "Copied!"
        setTimeout(() => {
          this.copyTextTarget.textContent = originalText
        }, 2000)
      }

      this.trackShare()
    } catch (error) {
      console.error("Failed to copy:", error)
    }
  }

  // Track share for analytics
  async trackShare() {
    if (!this.shareUrlValue) return

    try {
      await fetch(this.shareUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        }
      })
    } catch (error) {
      // Silent fail for analytics
      console.error("Failed to track share:", error)
    }
  }
}
