const routes = [

  {
    path: '/',
    component: () => import('../layouts/MainLayout.vue'),
    // path: '/', component: () => import("../components/AdminIntro.vue"),
    children: [
      {
        path: '/page1',
        component: () => import("../components/AdminIntro.vue"),
      }, {
        path: '/properties/list/all',
        name: "rPropertiesList",
        component: () => import("../pages/PropertiesList.vue"),
      }
      // {
      //   path: "",
      //   name: "rHomePage",
      //   component: () => import("src/pages/HomeHunterHomePage.vue"),
      //   children: [
      //   ]
      // },
    ]
  },

  // // Always leave this as last one,
  // // but you can also remove it
  // {
  //   path: "/:catchAll(.*)*",
  //   component: () => import("pages/Error404.vue"),
  // },
]

export default routes
