// import { Cookies } from "quasar"
// import { route } from 'quasar/wrappers'import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'
// import Home from '/src/components/Home.vue'
// const routes = [
//   {
//     path: '/',
//     name: 'Home',
//     component: () => import("../components/AdminIntro.vue"),
//   },
// ]
const router = createRouter({
  history: createWebHistory('/v-admin/'),
  routes,
})
export default router
