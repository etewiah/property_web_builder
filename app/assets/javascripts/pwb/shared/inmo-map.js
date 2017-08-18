Vue.component('inmo-map', {
  template: '<gmap-map style="min-height: 600px;"' +
    ':zoom="15" :center="center" ref="mmm">' +
    '<gmap-marker  v-for="m in mapkers"  :key="m.id" :position="m.position" :clickable="true"' +
    ':draggable="true" @click="center=m.position"></gmap-marker></gmap-map>',
  data() {
    return {
      newMarkers: [],
      useNewMarkers: false
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
        this.$refs.mmm.$mapObject.setOptions({maxZoom: this.$refs.mmm.$mapObject.getZoom()});
      }
    })
  },
  methods: {
    resetMarkers: function(newMarkers) {
      this.newMarkers = newMarkers;
      this.useNewMarkers = true;
      // return 'Got it!'
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
