var INMOAPP = INMOAPP || {};


window.onload = function() {

  var pwbSS = Vue.component('social-sharing', SocialSharing);
  // var pwbGM = Vue.component('gmap-map', VueGoogleMaps);
  Vue.use(VueRouter);
  Vue.use(VueGoogleMaps, {
    load: {
      key: 'AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw'
      // v: '3.26', // Google Maps API version
      // libraries: 'places',   // If you want to use places input
    }
  });
  // var markers = INMOAPP.markers || [];

  // 1. Define route components.
  // These can be imported from other files
  const Foo = { template: '<div>foo</div>' }
  const Bar = { template: '<div>bar</div>' }

  // 2. Define some routes
  // Each route should map to a component. The "component" can
  // either be an actual component constructor created via
  // `Vue.extend()`, or just a component options object.
  // We'll talk about nested routes later.
  const routes = [
    { path: '/foo', component: Foo },
    { path: '/bar', component: Bar }
  ]

  // 3. Create the router instance and pass the `routes` option
  // You can pass in additional options here, but let's
  // keep it simple for now.
  const router = new VueRouter({
    routes // short for `routes: routes`
  })

  INMOAPP.pwbVue = new Vue({
    el: '#main-vue',
    data: {
      // markers: markers,
      // selected: 2,
      // selectoptions: [
      //   2, 3, 4
      // ],
      // options: [
      //   { id: 1, text: 'Hello' },
      //   { id: 2, text: 'World' }
      // ]
    }
  });

}
