import { Controller } from "@hotwired/stimulus"

/**
 * LeafletMapController
 *
 * Simple Leaflet map for displaying a single location marker.
 * Used in contact forms and location displays.
 *
 * For property listings with multiple markers, use map_controller.js instead.
 *
 * Usage:
 *   <div data-controller="leaflet-map"
 *        data-leaflet-map-latitude-value="40.7128"
 *        data-leaflet-map-longitude-value="-74.0060"
 *        data-leaflet-map-zoom-value="14"
 *        data-leaflet-map-marker-title-value="Our Office"
 *        style="height: 300px;">
 *     <div data-leaflet-map-target="container" class="w-full h-full"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["container"]
  static values = {
    latitude: { type: Number, default: 40.7128 },
    longitude: { type: Number, default: -74.0060 },
    zoom: { type: Number, default: 14 },
    maxZoom: { type: Number, default: 18 },
    markerTitle: { type: String, default: "" },
    scrollWheelZoom: { type: Boolean, default: false },
    tileUrl: { type: String, default: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" },
    attribution: { type: String, default: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' }
  }

  connect() {
    // Wait for Leaflet to be available
    if (typeof L === "undefined") {
      console.warn("Leaflet not loaded, waiting...")
      this.waitForLeaflet()
      return
    }

    this.initMap()
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  waitForLeaflet() {
    const checkInterval = setInterval(() => {
      if (typeof L !== "undefined") {
        clearInterval(checkInterval)
        this.initMap()
      }
    }, 100)

    // Stop checking after 10 seconds
    setTimeout(() => clearInterval(checkInterval), 10000)
  }

  initMap() {
    const mapElement = this.hasContainerTarget ? this.containerTarget : this.element

    // Ensure the element has dimensions
    if (mapElement.offsetHeight === 0) {
      mapElement.style.height = "300px"
    }

    // Fix for Leaflet default icon path issues
    this.fixIconPaths()

    // Initialize the map
    this.map = L.map(mapElement, {
      scrollWheelZoom: this.scrollWheelZoomValue
    })

    // Set view to the specified coordinates
    this.map.setView([this.latitudeValue, this.longitudeValue], this.zoomValue)

    // Add tile layer
    L.tileLayer(this.tileUrlValue, {
      attribution: this.attributionValue,
      maxZoom: this.maxZoomValue
    }).addTo(this.map)

    // Add marker at the location
    this.addMarker()
  }

  fixIconPaths() {
    delete L.Icon.Default.prototype._getIconUrl
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
      iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
      shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png"
    })
  }

  addMarker() {
    const marker = L.marker([this.latitudeValue, this.longitudeValue]).addTo(this.map)

    // Add popup if title is provided
    if (this.markerTitleValue) {
      marker.bindPopup(`<div class="text-center font-medium">${this.escapeHtml(this.markerTitleValue)}</div>`)
    }

    this.marker = marker
  }

  /**
   * Update the map location dynamically
   */
  updateLocation(lat, lng, title = null) {
    if (!this.map) return

    this.latitudeValue = lat
    this.longitudeValue = lng

    this.map.setView([lat, lng], this.zoomValue)

    if (this.marker) {
      this.marker.setLatLng([lat, lng])
      if (title) {
        this.marker.setPopupContent(`<div class="text-center font-medium">${this.escapeHtml(title)}</div>`)
      }
    }
  }

  /**
   * Refresh map size (useful after container resize or visibility change)
   */
  refresh() {
    if (this.map) {
      this.map.invalidateSize()
    }
  }

  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
