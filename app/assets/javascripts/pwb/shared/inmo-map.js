Vue.component('inmo-map', {
  template: '<div id="inmo-map-canvas" style="min-height: 600px; width: 100%;"></div>',
  data: function() {
    return {
      map: null,
      markersLayer: null,
      internalMarkers: []
    };
  },
  mounted: function() {
    this.initMap();
  },
  methods: {
    initMap: function() {
      // Default center (will be updated by bounds)
      this.map = L.map('inmo-map-canvas').setView([0, 0], 2);

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(this.map);

      this.markersLayer = L.layerGroup().addTo(this.map);

      if (this.markers && this.markers.length > 0) {
        this.addMarkers(this.markers);
      }
    },
    addMarkers: function(markersData) {
      this.markersLayer.clearLayers();
      var bounds = L.latLngBounds();

      markersData.forEach(function(markerData) {
        var lat = markerData.position.lat;
        var lng = markerData.position.lng;
        
        if (lat && lng) {
          var marker = L.marker([lat, lng]);
          
          var popupContent = '<div id="iw-container">' +
            '<a href="' + markerData.show_url + '">' +
            '<div class="iw-title">' + markerData.title + '</div>';
            
          if (markerData.display_price) {
            popupContent += '<div class="iw-subTitle">' + markerData.display_price + '</div>';
          }
          
          if (markerData.image_url) {
            popupContent += '<div class="iw-content"><img src="' + markerData.image_url + '" alt="" width="225"></div>';
          }
          
          popupContent += '</a></div>';
          
          marker.bindPopup(popupContent);
          this.markersLayer.addLayer(marker);
          bounds.extend([lat, lng]);
        }
      }, this);

      if (markersData.length > 0) {
        this.map.fitBounds(bounds, { padding: [50, 50] });
      }
    },
    resetMarkers: function(newMarkers) {
      this.internalMarkers = newMarkers;
      this.addMarkers(newMarkers);
    }
  },
  props: ['markers'],
  watch: {
    markers: function(newVal) {
      this.addMarkers(newVal);
    }
  }
});
