Vue.component('inmo-map', {
  template: '<gmap-map style="min-height: 600px;"' +
    ':zoom="15" :center="center">' +
    '<gmap-marker  v-for="m in markers"  :key="m.id" :position="m.position" :clickable="true"' +
    ':draggable="true" @click="center=m.position"></gmap-marker></gmap-map>',

  mounted: function() {
    // debugger;
    var vm = this;
    // $(this.$el).selectpicker(this.selectPickerTexts);
    // .trigger('change')
    // // emit event on change.
    // .on('change', function() {
    //   vm.$emit('input', this.value)
    // });
  },
  computed: {
    // markers: function() {
    //   var markers = [];
    //   if (this.props) {
    //     var lat = this.props.latitude;
    //     var lng = this.props.longitude;
    //     var marker = {
    //       position: {
    //         lat: lat,
    //         lng: lng
    //       }
    //     };
    //     markers.push(marker);
    //   }
    //   return markers;
    // },
    center: function() {
      // debugger;
      if (this.markers.length > 0) {
        var lat = this.markers[0].position.lat;
        var lng = this.markers[0].position.lng;
        return { lat: lat, lng: lng };
      } else {
        return { lat: 1, lng: 1 };
      }
      // `this` points to the vm instance
    }
  },
  props: ['markers'],
});
