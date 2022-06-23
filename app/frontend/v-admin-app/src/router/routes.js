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
        path: '/agency',
        name: "rAgencyEdit",
        component: () => import("../pages/AgencyEdit.vue"),
        children: [
          {
            path: 'general',
            name: "rAgencyEditGeneral",
            component: () => import("../components/website/EditAgencyGeneral.vue"),
          },
          {
            path: 'location',
            name: "rAgencyEditLocation",
            component: () => import("../components/website/EditWebsiteGeneral.vue"),
          },
        ]
      },
      {
        path: '/translations',
        name: "rTranslationsEdit",
        component: () => import("../pages/TranslationsEdit.vue"),
        children: [
          {
            path: 'features',
            name: "rTranslationsEditFeatures",
            component: () => import("../components/translations/EditTranslationBatch.vue"),
          },
          {
            path: 'property-types',
            name: "rTranslationsEditPropTypes",
            component: () => import("../components/translations/EditTranslationBatch.vue"),
          },
        ]
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
        path: '/properties/list/all',
        name: "rPropertiesList",
        component: () => import("../pages/PropertiesList.vue"),
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
