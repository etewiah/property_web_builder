import { Controller } from "@hotwired/stimulus"

// Tabs controller for tabbed interfaces
// Usage:
//   <div data-controller="tabs" data-tabs-active-class="border-blue-500">
//     <nav data-tabs-target="tablist" role="tablist">
//       <button data-tabs-target="tab" data-action="tabs#select keydown->tabs#handleKeydown">Tab 1</button>
//       <button data-tabs-target="tab" data-action="tabs#select keydown->tabs#handleKeydown">Tab 2</button>
//     </nav>
//     <div data-tabs-target="panel">Panel 1 content</div>
//     <div data-tabs-target="panel" class="hidden">Panel 2 content</div>
//   </div>
//
// Keyboard shortcuts (when a tab is focused):
//   ArrowLeft  - Previous tab
//   ArrowRight - Next tab
//   Home       - First tab
//   End        - Last tab
//
export default class extends Controller {
  static targets = ["tab", "panel", "tablist"]
  static classes = ["active"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.showTab(this.indexValue)

    // Set up ARIA roles
    this.tabTargets.forEach((tab, i) => {
      tab.setAttribute("role", "tab")
      tab.setAttribute("tabindex", i === this.indexValue ? "0" : "-1")
    })

    this.panelTargets.forEach((panel) => {
      panel.setAttribute("role", "tabpanel")
    })
  }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.indexValue = index
  }

  /**
   * Handle keyboard navigation for tabs
   */
  handleKeydown(event) {
    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    let newIndex = currentIndex

    switch (event.key) {
      case "ArrowLeft":
        event.preventDefault()
        newIndex = currentIndex > 0 ? currentIndex - 1 : this.tabTargets.length - 1
        break
      case "ArrowRight":
        event.preventDefault()
        newIndex = currentIndex < this.tabTargets.length - 1 ? currentIndex + 1 : 0
        break
      case "Home":
        event.preventDefault()
        newIndex = 0
        break
      case "End":
        event.preventDefault()
        newIndex = this.tabTargets.length - 1
        break
      default:
        return
    }

    this.indexValue = newIndex
    this.tabTargets[newIndex].focus()
  }

  /**
   * Navigate to previous tab
   */
  previous() {
    const newIndex = this.indexValue > 0 ? this.indexValue - 1 : this.tabTargets.length - 1
    this.indexValue = newIndex
  }

  /**
   * Navigate to next tab
   */
  next() {
    const newIndex = this.indexValue < this.tabTargets.length - 1 ? this.indexValue + 1 : 0
    this.indexValue = newIndex
  }

  indexValueChanged() {
    this.showTab(this.indexValue)
  }

  showTab(index) {
    // Update tab styles and accessibility
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add(...this.activeClasses)
        tab.setAttribute("aria-selected", "true")
        tab.setAttribute("tabindex", "0")
      } else {
        tab.classList.remove(...this.activeClasses)
        tab.setAttribute("aria-selected", "false")
        tab.setAttribute("tabindex", "-1")
      }
    })

    // Show/hide panels
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })
  }

  get activeClasses() {
    return this.hasActiveClass ? [this.activeClass] : ["border-b-2", "border-blue-500", "text-blue-600"]
  }
}
