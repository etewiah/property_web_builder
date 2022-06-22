const routes = [

  {
    path: '/',
    component: () => import('../layouts/MainLayout.vue'),
    // path: '/', component: () => import("../components/AdminIntro.vue"),
    children: [
      {
        path: '/page1',
        component: () => import("../components/AdminIntro.vue"),
      },
      {
        path: '/properties/list/all',
        name: "rPropertiesList",
        component: () => import("../pages/PropertiesList.vue"),
      },
      {
        path: '/website/footer',
        name: "rWebsiteEditFooter",
        component: () => import("../pages/WebsiteEdit.vue"),
      },
      {
        path: '/website/settings',
        name: "rWebsiteEdit",
        component: () => import("../pages/WebsiteEdit.vue"),
        children: [
          {
            path: 'general',
            name: "rWebsiteEditGeneral",
            component: () => import("../components/website/EditWebsiteGeneral.vue"),
          },
          {
            path: 'appearance',
            name: "rWebsiteEditAppearance",
            component: () => import("../components/website/EditWebsiteGeneral.vue"),
          },
          {
            path: 'navigation',
            name: "rWebsiteEditNavigation",
            component: () => import("../components/website/EditWebsiteNavigation.vue"),
          }

        ]
      },
      {
        path: '/properties/s/:prop_id',
        name: "rPropertyEdit",
        component: () => import("../pages/PropertyEdit.vue"),
        children: [
          {
            path: 'general',
            name: "rPropertyEditGeneral",
            component: () => import("../components/properties/EditPropertyGeneral.vue"),
          },
          {
            path: 'texts',
            name: "rPropertyEditTexts",
            component: () => import("../components/properties/EditPropertyTexts.vue"),
          },
          {
            path: 'location',
            name: "rPropertyEditLocation",
            component: () => import("../pages/PropertyEdit.vue"),
          }

        ]
      }
      // {
      //   path: "",
      //   name: "rHomePage",
      //   component: () => import("src/pages/HomeHunterHomePage.vue"),
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
