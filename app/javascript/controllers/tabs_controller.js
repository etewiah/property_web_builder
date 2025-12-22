import { Controller } from "@hotwired/stimulus"

// Tabs controller for tabbed interfaces
// Usage:
//   <div data-controller="tabs" data-tabs-active-class="border-blue-500">
//     <nav>
//       <button data-tabs-target="tab" data-action="tabs#select">Tab 1</button>
//       <button data-tabs-target="tab" data-action="tabs#select">Tab 2</button>
//     </nav>
//     <div data-tabs-target="panel">Panel 1 content</div>
//     <div data-tabs-target="panel" class="hidden">Panel 2 content</div>
//   </div>
//
export default class extends Controller {
  static targets = ["tab", "panel"]
  static classes = ["active"]
  static values = { index: { type: Number, default: 0 } }

  connect() {
    this.showTab(this.indexValue)
  }

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)
    this.indexValue = index
  }

  indexValueChanged() {
    this.showTab(this.indexValue)
  }

  showTab(index) {
    // Update tab styles
    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add(...this.activeClasses)
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove(...this.activeClasses)
        tab.setAttribute("aria-selected", "false")
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
