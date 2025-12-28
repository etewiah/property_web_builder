import { Controller } from "@hotwired/stimulus"

/**
 * LocationPickerController
 *
 * Interactive map for selecting property locations with geocoding.
 * Uses Leaflet.js for maps and Nominatim (OpenStreetMap) for geocoding.
 *
 * Usage:
 *   <div data-controller="location-picker"
 *        data-location-picker-lat-value="41.40338"
 *        data-location-picker-lng-value="2.17403">
 *     <input data-location-picker-target="latitude" ...>
 *     <input data-location-picker-target="longitude" ...>
 *     <input data-location-picker-target="searchInput" ...>
 *     <div data-location-picker-target="map" style="height: 400px;"></div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "map",
    "latitude",
    "longitude",
    "searchInput",
    "streetName",
    "streetNumber",
    "city",
    "region",
    "postalCode",
    "country",
    "status"
  ]

  static values = {
    lat: { type: Number, default: 0 },
    lng: { type: Number, default: 0 },
    zoom: { type: Number, default: 13 },
    defaultLat: { type: Number, default: 40.4168 },  // Madrid as default
    defaultLng: { type: Number, default: -3.7038 }
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
    if (!this.hasMapTarget) {
      console.error("LocationPicker requires a map target element")
      return
    }

    // Fix for Leaflet default icon path issues
    this.fixIconPaths()

    // Determine initial position
    const hasCoordinates = this.latValue !== 0 || this.lngValue !== 0
    const initialLat = hasCoordinates ? this.latValue : this.defaultLatValue
    const initialLng = hasCoordinates ? this.lngValue : this.defaultLngValue
    const initialZoom = hasCoordinates ? this.zoomValue : 4

    // Initialize the map
    this.map = L.map(this.mapTarget, {
      scrollWheelZoom: true
    }).setView([initialLat, initialLng], initialZoom)

    // Add tile layer (OpenStreetMap)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19
    }).addTo(this.map)

    // Create draggable marker
    this.marker = L.marker([initialLat, initialLng], {
      draggable: true
    }).addTo(this.map)

    // Marker drag event
    this.marker.on("dragend", () => {
      const position = this.marker.getLatLng()
      this.updateCoordinateFields(position.lat, position.lng)
    })

    // Map click event - move marker to clicked location
    this.map.on("click", (e) => {
      this.marker.setLatLng(e.latlng)
      this.updateCoordinateFields(e.latlng.lat, e.latlng.lng)
    })

    // If no coordinates, hide marker initially
    if (!hasCoordinates) {
      this.marker.setOpacity(0)
      this.showStatus("Click on the map or search for an address to set the location", "info")
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

  // Update lat/lng input fields and show marker
  updateCoordinateFields(lat, lng) {
    if (this.hasLatitudeTarget) {
      this.latitudeTarget.value = lat.toFixed(7)
    }
    if (this.hasLongitudeTarget) {
      this.longitudeTarget.value = lng.toFixed(7)
    }
    // Show marker if it was hidden
    this.marker.setOpacity(1)
  }

  // Called when lat/lng fields are manually edited
  updateFromCoordinates() {
    const lat = parseFloat(this.latitudeTarget.value)
    const lng = parseFloat(this.longitudeTarget.value)

    if (isNaN(lat) || isNaN(lng)) {
      return
    }

    // Validate coordinates
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      this.showStatus("Invalid coordinates. Latitude: -90 to 90, Longitude: -180 to 180", "error")
      return
    }

    this.marker.setLatLng([lat, lng])
    this.marker.setOpacity(1)
    this.map.setView([lat, lng], this.zoomValue)
    this.clearStatus()
  }

  // Search for an address using Nominatim
  async search(event) {
    event.preventDefault()

    if (!this.hasSearchInputTarget) return

    const query = this.searchInputTarget.value.trim()
    if (!query) {
      this.showStatus("Please enter an address to search", "error")
      return
    }

    this.showStatus("Searching...", "info")

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&addressdetails=1&limit=1`,
        {
          headers: {
            "Accept-Language": "en",
            "User-Agent": "PropertyWebBuilder/1.0"
          }
        }
      )

      if (!response.ok) {
        throw new Error("Search request failed")
      }

      const results = await response.json()

      if (results.length === 0) {
        this.showStatus("No results found. Try a different search term.", "error")
        return
      }

      const result = results[0]
      const lat = parseFloat(result.lat)
      const lng = parseFloat(result.lon)

      // Update map and marker
      this.marker.setLatLng([lat, lng])
      this.marker.setOpacity(1)
      this.map.setView([lat, lng], 16)

      // Update coordinate fields
      this.updateCoordinateFields(lat, lng)

      // Populate address fields from result
      this.populateAddressFields(result.address)

      this.showStatus(`Found: ${result.display_name}`, "success")

    } catch (error) {
      console.error("Geocoding error:", error)
      this.showStatus("Search failed. Please try again.", "error")
    }
  }

  // Reverse geocode current marker position to get address
  async reverseGeocode() {
    const position = this.marker.getLatLng()

    if (this.marker.options.opacity === 0) {
      this.showStatus("Please set a location on the map first", "error")
      return
    }

    this.showStatus("Looking up address...", "info")

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.lat}&lon=${position.lng}&addressdetails=1`,
        {
          headers: {
            "Accept-Language": "en",
            "User-Agent": "PropertyWebBuilder/1.0"
          }
        }
      )

      if (!response.ok) {
        throw new Error("Reverse geocoding request failed")
      }

      const result = await response.json()

      if (result.error) {
        this.showStatus("Could not find address for this location", "error")
        return
      }

      // Populate address fields
      this.populateAddressFields(result.address)

      this.showStatus("Address fields updated from map location", "success")

    } catch (error) {
      console.error("Reverse geocoding error:", error)
      this.showStatus("Could not look up address. Please try again.", "error")
    }
  }

  // Populate address fields from Nominatim response
  populateAddressFields(address) {
    if (!address) return

    if (this.hasStreetNameTarget) {
      this.streetNameTarget.value = address.road || address.street || ""
    }

    if (this.hasStreetNumberTarget) {
      this.streetNumberTarget.value = address.house_number || ""
    }

    if (this.hasCityTarget) {
      this.cityTarget.value = address.city || address.town || address.village || address.municipality || ""
    }

    if (this.hasRegionTarget) {
      this.regionTarget.value = address.state || address.province || address.region || ""
    }

    if (this.hasPostalCodeTarget) {
      this.postalCodeTarget.value = address.postcode || ""
    }

    if (this.hasCountryTarget) {
      this.countryTarget.value = address.country || ""
    }
  }

  // Geocode the current address fields and show on map
  async geocodeAddress() {
    const parts = []

    if (this.hasStreetNumberTarget && this.streetNumberTarget.value) {
      parts.push(this.streetNumberTarget.value)
    }
    if (this.hasStreetNameTarget && this.streetNameTarget.value) {
      parts.push(this.streetNameTarget.value)
    }
    if (this.hasCityTarget && this.cityTarget.value) {
      parts.push(this.cityTarget.value)
    }
    if (this.hasRegionTarget && this.regionTarget.value) {
      parts.push(this.regionTarget.value)
    }
    if (this.hasPostalCodeTarget && this.postalCodeTarget.value) {
      parts.push(this.postalCodeTarget.value)
    }
    if (this.hasCountryTarget && this.countryTarget.value) {
      parts.push(this.countryTarget.value)
    }

    if (parts.length === 0) {
      this.showStatus("Please enter an address first", "error")
      return
    }

    const query = parts.join(", ")
    this.showStatus("Finding location...", "info")

    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1`,
        {
          headers: {
            "Accept-Language": "en",
            "User-Agent": "PropertyWebBuilder/1.0"
          }
        }
      )

      if (!response.ok) {
        throw new Error("Geocoding request failed")
      }

      const results = await response.json()

      if (results.length === 0) {
        this.showStatus("Could not find this address on the map", "error")
        return
      }

      const result = results[0]
      const lat = parseFloat(result.lat)
      const lng = parseFloat(result.lon)

      // Update map and marker
      this.marker.setLatLng([lat, lng])
      this.marker.setOpacity(1)
      this.map.setView([lat, lng], 16)

      // Update coordinate fields
      this.updateCoordinateFields(lat, lng)

      this.showStatus("Location found and marked on map", "success")

    } catch (error) {
      console.error("Geocoding error:", error)
      this.showStatus("Could not find location. Please try again.", "error")
    }
  }

  // Center map on current marker
  centerOnMarker() {
    if (this.marker && this.marker.options.opacity > 0) {
      this.map.setView(this.marker.getLatLng(), this.zoomValue)
    }
  }

  // Show status message
  showStatus(message, type = "info") {
    if (!this.hasStatusTarget) return

    const colors = {
      info: "text-blue-600 bg-blue-50",
      success: "text-green-600 bg-green-50",
      error: "text-red-600 bg-red-50"
    }

    this.statusTarget.textContent = message
    this.statusTarget.className = `text-sm p-2 rounded ${colors[type] || colors.info}`
    this.statusTarget.style.display = "block"

    // Auto-hide success messages
    if (type === "success") {
      setTimeout(() => this.clearStatus(), 5000)
    }
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.style.display = "none"
    }
  }
}
