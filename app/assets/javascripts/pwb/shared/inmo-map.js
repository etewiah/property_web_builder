Vue.component('inmo-map', {
  template: '<gmap-map style="min-height: 600px;"' +
    ':zoom="15" :center="center" ref="mmm">' +
    '<gmap-info-window ref="infwin" :options="infoOptions" :position="infoWindowPos"' +
    ':opened="infoWinOpen" @closeclick="infoWinOpen=false">' +
    '</gmap-info-window>' +
    '<gmap-marker  v-for="(m,i) in mapkers"  :key="m.id" :position="m.position" ' +
    '@mouseover="toggleInfoWindow(m,i)" @mouseout="statusText = null"' +
    ':clickable="true" :draggable="true" @click=""></gmap-marker>' +
    '</gmap-map>',
  data() {
    return {
      newMarkers: [],
      useNewMarkers: false,
      infoContent: '',
      statusText: '',
      infoWindowPos: {
        lat: 0,
        lng: 0
      },
      infoWinOpen: false,
      currentMidx: null,
      //optional: offset infowindow so it visually sits nicely on top of our marker
      infoOptions: {
        content: "hey",
        pixelOffset: {
          width: 0,
          height: -35
        }
      }
    };
  },
  // created() {
  // },
  mounted: function() {
    this.$refs.mmm.$mapCreated.then(() => {
      if (this.mapkers.length > 1) {
        const bounds = new google.maps.LatLngBounds();
        for (let m of this.mapkers) {
          bounds.extend(m.position)
        }
        this.$refs.mmm.$mapObject.fitBounds(bounds);
        // where markers are too close together, I need below
        // to ensure they are not too zoomed in
        this.$refs.mmm.$mapObject.setOptions({ maxZoom: this.$refs.mmm.$mapObject.getZoom() });
      }
    })
  },
  methods: {
    resetMarkers: function(newMarkers) {
      this.newMarkers = newMarkers;
      this.useNewMarkers = true;
    },
    toggleInfoWindow: function(marker, idx) {
      this.infoWindowPos = marker.position;
      var display_price_html = "";
      if (marker.display_price) {
        display_price_html = '<div class="iw-subTitle">' + marker.display_price + '</div>';
      }
      var image_html = "";
      if (marker.image_url) {
        image_html = '<img src="' + marker.image_url + '" alt="" width="225">';
      }

      var infoWindowContent = '<div id="iw-container">' +
        '<a href="' + marker.show_url + '" class="">' +
        '<div class="iw-title">' + marker.title + '</div>' +
        '<div class="iw-content">' +
        display_price_html +
        image_html +
        '</div></a>' +
        '</div>';

      this.infoOptions.content = infoWindowContent;
      //check if its the same marker that was selected if yes toggle
      if (this.currentMidx == idx) {
        this.infoWinOpen = !this.infoWinOpen;
      }
      //if different marker set infowindow to open and reset current marker index
      else {
        this.infoWinOpen = true;
        this.currentMidx = idx;
      }
    }
  },
  // watch: {
  //   mapkers(mapkers) {
  //   }
  // },
  computed: {
    mapkers: function() {
      if (this.useNewMarkers) {
        return this.newMarkers;
      } else {
        return this.markers;
      }
    },
    center: function() {
      if (this.markers) {
        var lat = this.markers[0].position.lat;
        var lng = this.markers[0].position.lng;
        return { lat: lat, lng: lng };

        // if (this.mapkers.length < 2) {
        // } else {
        //   // const bounds = new google.maps.LatLngBounds()
        //   // for (let m of mapkers) {
        //   //   bounds.extend(m.latLng)
        //   // }
        //   // this.$refs.map.$mapObject.fitBounds(bounds)
        // }
      }
      // `this` points to the vm instance
    }
  },
  props: ['markers'],
});
