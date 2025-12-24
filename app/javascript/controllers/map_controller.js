import { Controller } from "@hotwired/stimulus"

/**
 * MapController
 * 
 * Handles Leaflet map initialization with property markers.
 * Replaces inline JavaScript for map rendering.
 * 
 * Usage:
 *   <div data-controller="map"
 *        data-map-markers-value='[{"id":"1","title":"Property","position":{"lat":40.4,"lng":-74.5}}]'
 *        data-map-target="canvas"
 *        style="height: 400px;">
 *   </div>
 */
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    markers: { type: Array, default: [] },
    zoom: { type: Number, default: 13 },
    maxZoom: { type: Number, default: 18 },
    scrollWheelZoom: { type: Boolean, default: false },
    tileUrl: { type: String, default: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" },
    attribution: { type: String, default: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' }
  }

  connect() {
    // Wait for Leaflet to be available
    if (typeof L === "undefined") {
      console.warn("Leaflet not loaded yet, waiting...")
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
    if (!this.hasCanvasTarget && !this.element.id) {
      console.error("Map controller requires a canvas target or element with ID")
      return
    }

    const mapElement = this.hasCanvasTarget ? this.canvasTarget : this.element

    // Fix for Leaflet default icon path issues
    this.fixIconPaths()

    // Initialize the map with scroll wheel zoom disabled by default
    // This prevents the map from hijacking page scroll
    this.map = L.map(mapElement, {
      scrollWheelZoom: this.scrollWheelZoomValue
    })

    // Add tile layer
    L.tileLayer(this.tileUrlValue, {
      attribution: this.attributionValue,
      maxZoom: this.maxZoomValue
    }).addTo(this.map)

    // Add markers if available
    if (this.markersValue && this.markersValue.length > 0) {
      this.addMarkers()
    } else {
      // Default center if no markers
      this.map.setView([40.4, -74.5], this.zoomValue)
    }
  }

  fixIconPaths() {
    delete L.Icon.Default.prototype._getIconUrl
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
      iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
      shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png"
    })
  }

  addMarkers() {
    const bounds = []
    this.markerObjects = []

    this.markersValue.forEach(markerData => {
      if (!markerData.position || !markerData.position.lat || !markerData.position.lng) {
        return
      }

      const lat = parseFloat(markerData.position.lat)
      const lng = parseFloat(markerData.position.lng)
      
      if (isNaN(lat) || isNaN(lng)) return

      bounds.push([lat, lng])

      const marker = L.marker([lat, lng]).addTo(this.map)
      
      // Create popup content
      const popupContent = this.createPopupContent(markerData)
      marker.bindPopup(popupContent)

      // Store marker reference
      marker.propertyId = markerData.id
      this.markerObjects.push(marker)
    })

    // Fit map to show all markers
    if (bounds.length > 0) {
      this.map.fitBounds(bounds, { padding: [50, 50] })

      // Don't zoom in too much for single or close markers
      if (this.map.getZoom() > 15) {
        this.map.setZoom(15)
      }
    }
  }

  createPopupContent(marker) {
    let html = '<div class="text-center">'
    
    if (marker.show_url) {
      html += `<a href="${this.escapeHtml(marker.show_url)}" class="font-bold text-blue-600 hover:underline">${this.escapeHtml(marker.title || "View Property")}</a>`
    } else {
      html += `<span class="font-bold">${this.escapeHtml(marker.title || "Property")}</span>`
    }
    
    if (marker.display_price) {
      html += `<div class="text-gray-600">${this.escapeHtml(marker.display_price)}</div>`
    }
    
    if (marker.image_url) {
      html += `<img src="${this.escapeHtml(marker.image_url)}" class="mt-2 w-32 h-24 object-cover mx-auto rounded" alt="${this.escapeHtml(marker.title || "Property")}">`
    }
    
    html += '</div>'
    return html
  }

  /**
   * Highlight a specific marker (useful when hovering over property cards)
   */
  highlightMarker(event) {
    const propertyId = event.currentTarget.dataset.propertyId
    if (!propertyId || !this.markerObjects) return

    const marker = this.markerObjects.find(m => m.propertyId === propertyId)
    if (marker) {
      marker.openPopup()
      this.map.panTo(marker.getLatLng())
    }
  }

  /**
   * Update markers dynamically (e.g., after AJAX search)
   */
  updateMarkers(newMarkers) {
    // Remove existing markers
    if (this.markerObjects) {
      this.markerObjects.forEach(marker => marker.remove())
    }

    // Add new markers
    this.markersValue = newMarkers
    this.addMarkers()
  }

  /**
   * Refresh map size (useful after container resize)
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
