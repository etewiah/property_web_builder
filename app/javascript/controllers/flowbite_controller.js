import { Controller } from "@hotwired/stimulus"
import { initFlowbite, initCarousels, initDropdowns } from "flowbite"

/**
 * Flowbite Controller
 *
 * Initializes Flowbite UI components and handles re-initialization
 * after Turbo navigation. Only Carousel and Dropdown components
 * are actively used in this application.
 *
 * Usage: Add data-controller="flowbite" to the body or a parent element
 * that contains Flowbite components.
 */
export default class extends Controller {
  connect() {
    this.initializeFlowbite()
  }

  /**
   * Initialize Flowbite components.
   * Called on initial page load and after Turbo navigation.
   */
  initializeFlowbite() {
    // Initialize all Flowbite components
    // This handles data-carousel-*, data-dropdown-*, etc.
    if (typeof initFlowbite === 'function') {
      initFlowbite()
    } else {
      // Fallback: initialize specific components we use
      this.initializeCarousels()
      this.initializeDropdowns()
    }
  }

  /**
   * Initialize carousel components specifically.
   * Used for property image galleries.
   */
  initializeCarousels() {
    if (typeof initCarousels === 'function') {
      initCarousels()
    }
  }

  /**
   * Initialize dropdown components specifically.
   * Used for search form select menus.
   */
  initializeDropdowns() {
    if (typeof initDropdowns === 'function') {
      initDropdowns()
    }
  }

  /**
   * Re-initialize after Turbo renders new content.
   * This handles both full page navigations and partial updates.
   */
  turboLoad() {
    this.initializeFlowbite()
  }

  /**
   * Re-initialize after Turbo Stream updates.
   */
  turboFrameLoad() {
    this.initializeFlowbite()
  }
}
