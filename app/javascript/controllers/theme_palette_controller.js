import { Controller } from "@hotwired/stimulus"

// Handles dynamic palette switching when theme selection changes
// Palettes are theme-specific, so changing the theme should show different palette options
export default class extends Controller {
  static targets = ["paletteContainer", "themeRadio"]
  static values = {
    palettes: Object,  // All palettes keyed by theme name
    currentTheme: String
  }

  connect() {
    // Set initial theme from checked radio
    const checkedRadio = this.element.querySelector('input[name="website[theme_name]"]:checked')
    if (checkedRadio) {
      this.currentThemeValue = checkedRadio.value
    }
  }

  // Called when a theme radio button is selected
  selectTheme(event) {
    const newTheme = event.target.value
    if (newTheme === this.currentThemeValue) return

    this.currentThemeValue = newTheme
    this.updatePaletteOptions(newTheme)
  }

  updatePaletteOptions(themeName) {
    const palettes = this.palettesValue[themeName]
    if (!palettes || !this.hasPaletteContainerTarget) return

    // Get the current selected palette (if any)
    const currentSelected = this.element.querySelector('input[name="website[selected_palette]"]:checked')?.value

    // Build new palette HTML
    const paletteHtml = this.buildPaletteHtml(palettes, themeName)
    this.paletteContainerTarget.innerHTML = paletteHtml

    // Try to select the first palette if none matches
    const firstRadio = this.paletteContainerTarget.querySelector('input[type="radio"]')
    if (firstRadio) {
      // Check if previously selected palette exists in new theme
      const matchingRadio = this.paletteContainerTarget.querySelector(`input[value="${currentSelected}"]`)
      if (matchingRadio) {
        matchingRadio.checked = true
      } else {
        // Select the default palette for this theme
        const defaultPalette = Object.entries(palettes).find(([id, p]) => p.is_default)
        if (defaultPalette) {
          const defaultRadio = this.paletteContainerTarget.querySelector(`input[value="${defaultPalette[0]}"]`)
          if (defaultRadio) defaultRadio.checked = true
        } else {
          firstRadio.checked = true
        }
      }
    }
  }

  buildPaletteHtml(palettes, themeName) {
    return Object.entries(palettes).map(([paletteId, palette]) => {
      const previewColors = palette.preview_colors || []
      const colorSwatches = previewColors.map((color, i) => {
        const roundedClass = i === 0 ? 'rounded-l-lg' : (i === previewColors.length - 1 ? 'rounded-r-lg' : '')
        return `<div class="flex-1 ${roundedClass}" style="background-color: ${color}"></div>`
      }).join('')

      return `
        <label class="relative cursor-pointer group">
          <input type="radio" name="website[selected_palette]" value="${paletteId}"
                 class="sr-only peer"
                 data-palette-colors='${JSON.stringify(palette.colors || {})}'>
          <div class="border-2 rounded-lg p-4 peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-400 transition-all">
            <div class="flex h-12 rounded-lg overflow-hidden mb-3 shadow-sm">
              ${colorSwatches}
            </div>
            <div class="flex items-center justify-between">
              <div>
                <span class="font-medium text-gray-900 block">${palette.name}</span>
                <span class="text-xs text-gray-500">${palette.description || ''}</span>
              </div>
              <span class="hidden peer-checked:inline-block text-blue-600">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </span>
            </div>
          </div>
        </label>
      `
    }).join('')
  }
}
