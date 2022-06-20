const routes = [

  {
    path: '/', component: () => import("../components/AdminIntro.vue"),
    children: [
      // {
      //   path: "",
      //   name: "rHomePage",
      //   component: () => import("src/pages/HomeHunterHomePage.vue"),
      //   children: [
      //   ]
      // },
    ]
  },
  {
    path: '/page1',
    component: () => import("../components/AdminIntro.vue"),
  }, {
    path: '/page2',
    component: () => import("../components/AdminIntro.vue"),
  }
  // { path: '/about', component: About },
  // // Always leave this as last one,
  // // but you can also remove it
  // {
  //   path: "/:catchAll(.*)*",
  //   component: () => import("pages/Error404.vue"),
  // },
]

export default routes
