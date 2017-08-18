var INMOAPP = INMOAPP || {};


window.onload = function() {


  Vue.component('select-picker', {
    template: '<select class="" >' +
      '<option  v-for="option in selectOptions">{{ option }}</option>' +
      '</select>',
    mounted: function() {
      var vm = this;
      $(this.$el).selectpicker(this.selectPickerTexts);
        // .trigger('change')
        // // emit event on change.
        // .on('change', function() {
        //   vm.$emit('input', this.value)
        // });
    },
    props: ['selectOptions', 'selectPickerTexts', 'selected'],
  });



  var pwbSS = Vue.component('social-sharing', SocialSharing);
  // var pwbGM = Vue.component('gmap-map', VueGoogleMaps);
  Vue.use(VueGoogleMaps, {
    load: {
      key: 'AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw'
      // v: '3.26', // Google Maps API version
      // libraries: 'places',   // If you want to use places input
    }
  });
  var markers = INMOAPP.markers || [];
  INMOAPP.pwbVue = new Vue({
    el: '#main-vue',
    data: {
      markers: markers,
      selected: 2,
      selectoptions: [
        2, 3, 4
      ],
      options: [
        { id: 1, text: 'Hello' },
        { id: 2, text: 'World' }
      ]
    }
  });

}
