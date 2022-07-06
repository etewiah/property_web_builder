import { createRouter, createWebHistory } from 'vue-router'
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
  history: createWebHistory('/v-public/'),
  routes,
})

router.beforeEach((to, from, next) => {
  if (to.name === "rDefaultLocaleHomePage") {
    next({ name: 'rLocaleHomePage', params: { publicLocale: "en" }, replace: true })
  }
  else {
    next()
  }
})
export default router
