var INMOAPP = INMOAPP || {};
window.onload = function() {
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
      markers: markers
    }
  });
  // INMOAPP.pwbVue.$data.markers = [{
  //   position: {
  //     lat: 36.73234,
  //     lng: -4.52615000000003
  //   }
  // }]

}
