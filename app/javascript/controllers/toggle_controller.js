import { Controller } from "@hotwired/stimulus"

// Toggle visibility of elements
// Usage:
//   <div data-controller="toggle">
//     <button data-action="toggle#toggle">Toggle</button>
//     <div data-toggle-target="content" class="hidden">Content here</div>
//   </div>
//
// Or for show/hide separately:
//   <button data-action="toggle#show">Show</button>
//   <button data-action="toggle#hide">Hide</button>
//
export default class extends Controller {
  static targets = ["content"]
  static classes = ["hidden"]

  get hiddenClassName() {
    // Use the specified hidden class or default to "hidden"
    return this.hasHiddenClass ? this.hiddenClass : "hidden"
  }

  toggle() {
    this.contentTargets.forEach(target => {
      target.classList.toggle(this.hiddenClassName)
    })
  }

  show() {
    this.contentTargets.forEach(target => {
      target.classList.remove(this.hiddenClassName)
    })
  }

  hide() {
    this.contentTargets.forEach(target => {
      target.classList.add(this.hiddenClassName)
    })
  }
}
