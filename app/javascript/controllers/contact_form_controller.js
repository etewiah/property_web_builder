import { Controller } from "@hotwired/stimulus"

/**
 * ContactFormController
 * 
 * Handles contact form submissions with AJAX.
 * Replaces remote: true forms and jQuery-based response handling.
 * 
 * Usage:
 *   <div data-controller="contact-form">
 *     <form data-contact-form-target="form" data-action="submit->contact-form#submit">
 *       ...
 *       <div data-contact-form-target="result"></div>
 *       <button data-contact-form-target="submitButton">Send</button>
 *     </form>
 *   </div>
 */
export default class extends Controller {
  static targets = ["form", "result", "submitButton", "prompt"]
  static values = {
    submitUrl: String,
    successMessage: { type: String, default: "Message sent successfully!" },
    errorMessage: { type: String, default: "There was an error sending your message. Please try again." }
  }

  connect() {
    // If using Rails UJS remote forms, listen for those events too
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("ajax:success", this.handleAjaxSuccess.bind(this))
      this.formTarget.addEventListener("ajax:error", this.handleAjaxError.bind(this))
      this.formTarget.addEventListener("ajax:beforeSend", this.handleBeforeSend.bind(this))
      this.formTarget.addEventListener("ajax:complete", this.handleComplete.bind(this))
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("ajax:success", this.handleAjaxSuccess.bind(this))
      this.formTarget.removeEventListener("ajax:error", this.handleAjaxError.bind(this))
      this.formTarget.removeEventListener("ajax:beforeSend", this.handleBeforeSend.bind(this))
      this.formTarget.removeEventListener("ajax:complete", this.handleComplete.bind(this))
    }
  }

  /**
   * Handle form submission via fetch (for non-UJS forms)
   */
  async submit(event) {
    event.preventDefault()
    
    if (!this.hasFormTarget) return

    this.showLoading()
    this.clearResult()

    try {
      const formData = new FormData(this.formTarget)
      const url = this.submitUrlValue || this.formTarget.action
      
      const response = await fetch(url, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })

      const data = await response.json()

      if (response.ok) {
        this.showSuccess(data.message || this.successMessageValue)
        if (data.reset !== false) {
          this.formTarget.reset()
        }
      } else {
        this.showError(data.errors || data.message || this.errorMessageValue)
      }
    } catch (error) {
      console.error("Contact form error:", error)
      this.showError(this.errorMessageValue)
    } finally {
      this.hideLoading()
    }
  }

  /**
   * Handle Rails UJS ajax:beforeSend event
   */
  handleBeforeSend() {
    this.showLoading()
    this.clearResult()
  }

  /**
   * Handle Rails UJS ajax:complete event
   */
  handleComplete() {
    this.hideLoading()
  }

  /**
   * Handle Rails UJS ajax:success event
   */
  handleAjaxSuccess(event) {
    const [data, status, xhr] = event.detail
    
    // If response is HTML (from .js.erb), it will be in the result div
    // If response is JSON, handle it here
    if (typeof data === "object" && data.message) {
      this.showSuccess(data.message)
      this.formTarget.reset()
    }
    // For JS responses, the response executes and updates the DOM directly
  }

  /**
   * Handle Rails UJS ajax:error event
   */
  handleAjaxError(event) {
    const [data, status, xhr] = event.detail
    
    if (typeof data === "object" && data.errors) {
      this.showError(data.errors)
    } else {
      this.showError(this.errorMessageValue)
    }
  }

  showLoading() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.originalButtonText = this.submitButtonTarget.innerHTML
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Sending...
      `
    }
  }

  hideLoading() {
    if (this.hasSubmitButtonTarget && this.originalButtonText) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.innerHTML = this.originalButtonText
    }
  }

  showSuccess(message) {
    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = `
        <div class="bg-green-50 border border-green-200 text-green-800 px-4 py-3 rounded-lg mb-4">
          <div class="flex items-center">
            <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span>${this.escapeHtml(message)}</span>
          </div>
        </div>
      `
    }
    
    // Hide the prompt after successful submission
    if (this.hasPromptTarget) {
      this.promptTarget.classList.add("hidden")
    }
  }

  showError(errors) {
    if (!this.hasResultTarget) return

    let errorHtml = ""
    
    if (Array.isArray(errors)) {
      errorHtml = `
        <div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mb-4">
          <ul class="list-disc list-inside">
            ${errors.map(e => `<li>${this.escapeHtml(e)}</li>`).join("")}
          </ul>
        </div>
      `
    } else {
      errorHtml = `
        <div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mb-4">
          <div class="flex items-center">
            <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
            </svg>
            <span>${this.escapeHtml(errors)}</span>
          </div>
        </div>
      `
    }
    
    this.resultTarget.innerHTML = errorHtml
  }

  clearResult() {
    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = ""
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
