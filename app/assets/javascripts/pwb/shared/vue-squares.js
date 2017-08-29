var INMOAPP = INMOAPP || {};


window.onload = function() {

  // var pwbSC = Vue.component('squares-container', SquaresContainer);
  // var pwbGM = Vue.component('gmap-map', VueGoogleMaps);
  Vue.use(VueRouter);
  // Vue.use(VueGoogleMaps, {
  //   load: {
  //     key: 'AIzaSyCPorm8YzIaUGhKfe5cvpgofZ_gdT8hdZw'
  //     // v: '3.26', // Google Maps API version
  //     // libraries: 'places',   // If you want to use places input
  //   }
  // });

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
    { path: '/bar', component: INMOAPP.TabableSection },
    { path: '/tabs/:id', component: INMOAPP.TabableSection },
    // { path: '/tabs/', component: INMOAPP.TabableSection }
  ]

  // 3. Create the router instance and pass the `routes` option
  // You can pass in additional options here, but let's
  // keep it simple for now.
  const router = new VueRouter({
    routes // short for `routes: routes`
  })
  // var VueMaterial = Vue.component('vue-material');
  Vue.use(VueMaterial);
  // Vue.use(VueMaterial.mdCore) //Required to boot vue material
  // Vue.use(VueMaterial.mdButton)
  // Vue.use(VueMaterial.mdIcon)
  // Vue.use(VueMaterial.mdSidenav)
  // Vue.use(VueMaterial.mdToolbar)

  var firebaseApp = firebase.initializeApp({
    // apiKey: process.env.FIREBASE_API,
    authDomain: 'real-estate-data-40611.firebaseapp.com',
    databaseURL: 'https://real-estate-data-40611.firebaseio.com',
    projectId: 'real-estate-data-40611',
    storageBucket: ''
    // messagingSenderId: process.env.FIREBASE_SENDER
  }) 
  INMOAPP.fbDb = firebaseApp.database()


  INMOAPP.pwbVue = new Vue({
    el: '#squares-vue',
    data: {},
    router
    // firebase: {
    //   // simple syntax, bind as an array by default
    //   anArray: INMOAPP.fbDb.ref('props'),
    //   // can also bind to a query
    //   // anArray: INMOAPP.fbDb.ref('url/to/my/collection').limitToLast(25)
    //   // full syntax
    //   anObject: {
    //     source: INMOAPP.fbDb.ref('url/to/my/object'),
    //     // optionally bind as an object
    //     asObject: true,
    //     // optionally provide the cancelCallback
    //     cancelCallback: function() {},
    //     // this is called once the data has been retrieved from firebase
    //     readyCallback: function() {}
    //   }
    // }
  });

}
