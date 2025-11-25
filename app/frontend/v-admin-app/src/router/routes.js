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
            component: () => import("../components/website/EditAgencyGeneral.vue"),
          },
        ]
      },
      {
        path: '/pages/:pageName',
        name: "rPagesEdit",
        component: () => import("../pages/PagesEdit.vue"),
        children: [
          {
            path: ':pageTabName',
            name: "rPagesEditTab",
            component: () => import("../components/pages/EditPageTab.vue"),
          },
          // {
          //   path: '',
          //   name: "rPagesEditSingle",
          //   component: () => import("../components/translations/EditTranslationBatch.vue"),
          //   children: [
          //   ]
          // },
        ]
      },
      {
        path: '/translations',
        name: "rTranslationsEdit",
        component: () => import("../pages/TranslationsEdit.vue"),
        children: [
          {
            path: ':tBatchId',
            name: "rTranslationsEditBatch",
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
            component: () => import("../components/website/EditWebsiteAppearance.vue"),
          },
          {
            path: 'navigation',
            name: "rWebsiteEditNavigation",
            component: () => import("../components/website/EditWebsiteNavigation.vue"),
          },
          {
            path: 'home',
            name: "rWebsiteEditHome",
            component: () => import("../components/website/EditHomeSettings.vue"),
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
            path: ':editTabName',
            name: "rPropertyEditTab",
            component: () => import("../components/properties/EditPropertyGeneral.vue"),
          },
        ]
      },
      {
        path: '/import',
        name: "rPropertiesImport",
        component: () => import("../pages/PropertiesImport.vue"),
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
