import { Controller } from "@hotwired/stimulus"

/**
 * AiDescriptionController
 *
 * Handles AI-powered property description generation.
 * Integrates with the property edit form to generate and apply AI content.
 *
 * Usage:
 *   <div data-controller="ai-description"
 *        data-ai-description-property-id-value="123"
 *        data-ai-description-endpoint-value="/api_manage/v1/en/properties/123/ai_description">
 *     <select data-ai-description-target="localeSelect">...</select>
 *     <select data-ai-description-target="toneSelect">...</select>
 *     <button data-action="ai-description#generate">Generate</button>
 *     <div data-ai-description-target="output">...</div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "output",
    "generateButton",
    "toneSelect",
    "localeSelect",
    "titleOutput",
    "descriptionOutput",
    "metaDescriptionOutput",
    "complianceOutput",
    "errorOutput",
    // Form field targets for applying generated content
    "titleField",
    "descriptionField",
    "metaDescriptionField"
  ]

  static values = {
    propertyId: Number,
    endpoint: String,
    generating: { type: Boolean, default: false }
  }

  connect() {
    this.hideOutput()
  }

  async generate(event) {
    event.preventDefault()

    if (this.generatingValue) return

    this.generatingValue = true
    this.showLoading()
    this.clearErrors()

    try {
      const response = await fetch(this.endpointValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          locale: this.hasLocaleSelectTarget ? this.localeSelectTarget.value : null,
          tone: this.hasToneSelectTarget ? this.toneSelectTarget.value : 'professional'
        })
      })

      const data = await response.json()

      if (response.ok && data.success) {
        this.displayResult(data)
      } else {
        this.displayError(data.error || 'Failed to generate description')
      }
    } catch (error) {
      console.error('AI description generation error:', error)
      this.displayError('Failed to connect to AI service. Please try again.')
    } finally {
      this.generatingValue = false
      this.hideLoading()
    }
  }

  displayResult(data) {
    this.showOutput()

    if (this.hasTitleOutputTarget) {
      this.titleOutputTarget.textContent = data.title || ''
    }

    if (this.hasDescriptionOutputTarget) {
      this.descriptionOutputTarget.textContent = data.description || ''
    }

    if (this.hasMetaDescriptionOutputTarget) {
      this.metaDescriptionOutputTarget.textContent = data.meta_description || ''
    }

    // Display compliance information
    if (this.hasComplianceOutputTarget && data.compliance) {
      const compliance = data.compliance
      if (compliance.compliant) {
        this.complianceOutputTarget.innerHTML = `
          <span class="inline-flex items-center text-green-600">
            <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            Fair Housing Compliant
          </span>
        `
      } else {
        const violations = compliance.violations || []
        this.complianceOutputTarget.innerHTML = `
          <div class="text-amber-600">
            <span class="inline-flex items-center font-medium">
              <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
              </svg>
              Review Recommended
            </span>
            <ul class="mt-1 text-sm list-disc list-inside">
              ${violations.map(v => `<li>Found "${this.escapeHtml(v.match)}" (${v.category})</li>`).join('')}
            </ul>
          </div>
        `
      }
    }

    // Store data for apply functionality
    this.generatedData = data
  }

  displayError(message) {
    this.showOutput()

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
    }
  }

  clearErrors() {
    if (this.hasErrorOutputTarget) {
      this.errorOutputTarget.innerHTML = ''
      this.errorOutputTarget.classList.add('hidden')
    }
  }

  /**
   * Apply generated title to the form field
   */
  applyTitle(event) {
    event.preventDefault()
    if (!this.generatedData?.title) return

    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.value = this.generatedData.title
      this.highlightField(this.titleFieldTarget)
    }
  }

  /**
   * Apply generated description to the form field
   */
  applyDescription(event) {
    event.preventDefault()
    if (!this.generatedData?.description) return

    if (this.hasDescriptionFieldTarget) {
      this.descriptionFieldTarget.value = this.generatedData.description
      this.highlightField(this.descriptionFieldTarget)
    }
  }

  /**
   * Apply generated meta description to the form field
   */
  applyMetaDescription(event) {
    event.preventDefault()
    if (!this.generatedData?.meta_description) return

    if (this.hasMetaDescriptionFieldTarget) {
      this.metaDescriptionFieldTarget.value = this.generatedData.meta_description
      this.highlightField(this.metaDescriptionFieldTarget)
    }
  }

  /**
   * Apply all generated content to form fields
   */
  applyAll(event) {
    event.preventDefault()
    if (!this.generatedData) return

    if (this.hasTitleFieldTarget && this.generatedData.title) {
      this.titleFieldTarget.value = this.generatedData.title
      this.highlightField(this.titleFieldTarget)
    }

    if (this.hasDescriptionFieldTarget && this.generatedData.description) {
      this.descriptionFieldTarget.value = this.generatedData.description
      this.highlightField(this.descriptionFieldTarget)
    }

    if (this.hasMetaDescriptionFieldTarget && this.generatedData.meta_description) {
      this.metaDescriptionFieldTarget.value = this.generatedData.meta_description
      this.highlightField(this.metaDescriptionFieldTarget)
    }
  }

  /**
   * Highlight a field briefly to indicate it was updated
   */
  highlightField(field) {
    field.classList.add('ring-2', 'ring-blue-500', 'ring-opacity-50')
    setTimeout(() => {
      field.classList.remove('ring-2', 'ring-blue-500', 'ring-opacity-50')
    }, 1500)
  }

  showLoading() {
    if (this.hasGenerateButtonTarget) {
      this.originalButtonContent = this.generateButtonTarget.innerHTML
      this.generateButtonTarget.disabled = true
      this.generateButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    }
  }

  hideLoading() {
    if (this.hasGenerateButtonTarget && this.originalButtonContent) {
      this.generateButtonTarget.disabled = false
      this.generateButtonTarget.innerHTML = this.originalButtonContent
    }
  }

  showOutput() {
    if (this.hasOutputTarget) {
      this.outputTarget.classList.remove('hidden')
    }
  }

  hideOutput() {
    if (this.hasOutputTarget) {
      this.outputTarget.classList.add('hidden')
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}
