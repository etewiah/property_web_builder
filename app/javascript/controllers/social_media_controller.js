import { Controller } from "@hotwired/stimulus"

/**
 * SocialMediaController
 *
 * Handles AI-powered social media post generation for property listings.
 * Generates platform-specific content for Instagram, Facebook, LinkedIn, Twitter.
 *
 * Usage:
 *   <div data-controller="social-media"
 *        data-social-media-property-id-value="123"
 *        data-social-media-locale-value="en">
 *     <input type="checkbox" data-social-media-target="platform" value="instagram">
 *     <select data-social-media-target="category">...</select>
 *     <button data-action="social-media#generate">Generate</button>
 *     <div data-social-media-target="results">...</div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "platform",       // Checkboxes for platform selection
    "category",       // Post category select (just_listed, price_drop, etc.)
    "generateBtn",    // Generate button
    "loading",        // Loading indicator
    "results",        // Results container
    "postTemplate",   // Template for post cards
    "errorOutput"     // Error display area
  ]

  static values = {
    propertyId: Number,
    locale: { type: String, default: 'en' },
    generating: { type: Boolean, default: false }
  }

  connect() {
    console.log('[Social Media] Controller connected', this.element)
    this.hideResults()
  }

  async generate(event) {
    event.preventDefault()

    if (this.generatingValue) {
      return
    }

    const platforms = this.getSelectedPlatforms()
    if (platforms.length === 0) {
      this.showError('Please select at least one platform')
      return
    }

    this.generatingValue = true
    this.showLoading()
    this.clearErrors()

    try {
      const response = await fetch(this.batchEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          property_id: this.propertyIdValue,
          platforms: platforms,
          category: this.hasCategoryTarget ? this.categoryTarget.value : 'just_listed',
          post_type: 'feed'
        })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.displayResults(data.posts)
      } else {
        this.showError(data.error || 'Failed to generate posts')
      }
    } catch (error) {
      console.error('[Social Media] Generation error:', error)
      this.showError('Failed to connect to AI service. Please try again.')
    } finally {
      this.generatingValue = false
      this.hideLoading()
    }
  }

  getSelectedPlatforms() {
    if (!this.hasPlatformTarget) return ['instagram']

    return this.platformTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  displayResults(posts) {
    this.showResults()

    if (!this.hasResultsTarget) return

    // Clear previous results
    this.resultsTarget.innerHTML = ''

    posts.forEach(post => {
      const card = this.createPostCard(post)
      this.resultsTarget.appendChild(card)
    })
  }

  createPostCard(post) {
    const card = document.createElement('div')
    card.className = 'border rounded-lg p-4 mb-4 bg-white'
    card.dataset.postId = post.id
    card.dataset.platform = post.platform

    const platformColors = {
      instagram: 'text-pink-600 bg-pink-50',
      facebook: 'text-blue-600 bg-blue-50',
      linkedin: 'text-blue-700 bg-blue-50',
      twitter: 'text-gray-800 bg-gray-50',
      tiktok: 'text-black bg-gray-50'
    }

    const colorClass = platformColors[post.platform] || platformColors.instagram

    card.innerHTML = `
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colorClass}">
            ${this.platformLabel(post.platform)}
          </span>
          <span class="ml-2 text-xs text-gray-500">${post.character_count} chars</span>
        </div>
        <div class="flex space-x-2">
          <button class="text-gray-500 hover:text-gray-700 p-1" data-action="click->social-media#copyPost" data-post-id="${post.id}" title="Copy to clipboard">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"></path>
            </svg>
          </button>
        </div>
      </div>

      <div class="mb-3">
        <p class="text-sm text-gray-700 whitespace-pre-wrap caption-text">${this.escapeHtml(post.caption)}</p>
      </div>

      ${post.hashtags ? `
        <div class="mb-3">
          <p class="text-sm text-blue-600 hashtags-text">${this.escapeHtml(post.hashtags)}</p>
        </div>
      ` : ''}

      <div class="flex items-center justify-between text-xs text-gray-500">
        <span>${post.hashtag_count || 0} hashtags</span>
        <span class="text-gray-400">ID: ${post.id}</span>
      </div>
    `

    // Store post data for copy functionality
    card._postData = post

    return card
  }

  async copyPost(event) {
    event.preventDefault()
    const button = event.currentTarget
    const card = button.closest('[data-post-id]')

    if (!card?._postData) return

    const post = card._postData
    const text = post.hashtags
      ? `${post.caption}\n\n${post.hashtags}`
      : post.caption

    try {
      await navigator.clipboard.writeText(text)
      this.showToast('Copied to clipboard!')

      // Visual feedback
      button.classList.add('text-green-600')
      setTimeout(() => button.classList.remove('text-green-600'), 1500)
    } catch (error) {
      console.error('Failed to copy:', error)
      this.showError('Failed to copy to clipboard')
    }
  }

  platformLabel(platform) {
    const labels = {
      instagram: 'Instagram',
      facebook: 'Facebook',
      linkedin: 'LinkedIn',
      twitter: 'X (Twitter)',
      tiktok: 'TikTok'
    }
    return labels[platform] || platform
  }

  showLoading() {
    if (this.hasGenerateBtnTarget) {
      this.originalButtonContent = this.generateBtnTarget.innerHTML
      this.generateBtnTarget.disabled = true
      this.generateBtnTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    }

    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasGenerateBtnTarget && this.originalButtonContent) {
      this.generateBtnTarget.disabled = false
      this.generateBtnTarget.innerHTML = this.originalButtonContent
    }

    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add('hidden')
    }
  }

  showResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove('hidden')
    }
  }

  hideResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add('hidden')
    }
  }

  showError(message) {
    if (this.hasErrorOutputTarget) {
      this.errorOutputTarget.classList.remove('hidden')
      this.errorOutputTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg">
          <div class="flex items-center">
            <svg class="w-5 h-5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
            <span>${this.escapeHtml(message)}</span>
          </div>
        </div>
      `
    } else {
      alert(message)
    }
  }

  clearErrors() {
    if (this.hasErrorOutputTarget) {
      this.errorOutputTarget.innerHTML = ''
      this.errorOutputTarget.classList.add('hidden')
    }
  }

  showToast(message) {
    // Simple toast notification
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-4 right-4 bg-gray-800 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-opacity duration-300'
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add('opacity-0')
      setTimeout(() => toast.remove(), 300)
    }, 2000)
  }

  escapeHtml(text) {
    if (!text) return ''
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  get batchEndpoint() {
    return `/api_manage/v1/${this.localeValue}/ai/social_posts/batch_generate`
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}
