// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

// console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'
import '~/v-public-app/src/v-public.css'

// import '~/styles/background.css'
import { createApp } from 'vue'
import App from '~/v-public-app/src/VPublicApp.vue'
import {
  Quasar, AppFullscreen, Notify
} from 'quasar'

// Import icon libraries
import '@quasar/extras/material-icons/material-icons.css'

// Import Quasar css
import 'quasar/src/css/index.sass'

// // import { Component, createApp } from 'vue'
// // import { Router } from 'vue-router'
// import { createRouter, createWebHistory } from 'vue-router'
// // import { VueQueryPlugin } from 'vue-query'
// // import { globalProperties } from './globalProperties'
// // import { pinia } from '@/stores'
// // import { setHTTPHeader } from '@/services/http.service'
// // import AuthService from '@/services/auth.service'

import route from "../v-public-app/src/router/index"
import VueGoogleMaps from '@fawmi/vue-google-maps'
import urql from '@urql/vue';

const myApp = createApp(App)

myApp.use(urql, {
  url: '/graphql',
})



const gak = import.meta.env.VITE_GMAPS_API_KEY
// process.env.GMAPS_API_KEY
// import.meta.env.BASE_URL
myApp.use(VueGoogleMaps, {
  load: {
    key: gak,
    libraries: "places"
  },
})

myApp.use(Quasar, {
  plugins: {
    AppFullscreen, Notify
  }, // import Quasar plugins and add here
  // plugins: ["LocalStorage", "Notify", "Meta", "Cookies"],
})

myApp.use(route)
// myApp.use(pinia)
// myApp.use(VueQueryPlugin)
// myApp.config.globalProperties = globalProperties

myApp.mount('#app')

// console.log('Vite ⚡️ Rails 7')