const routes = [

  {
    path: '/',
    component: () => import('~/v-public-app/src/layouts/PublicLayout.vue'),
    // path: '/', component: () => import("~/v-admin-app/src/components/AdminIntro.vue"),
    children: [
      {
        path: '/page1',
        component: () => import("~/v-admin-app/src/components/AdminIntro.vue"),
      },
      {
        path: '/agency',
        name: "rAgencyEdit",
        component: () => import("~/v-admin-app/src/pages/AgencyEdit.vue"),
        children: [
          {
            path: 'general',
            name: "rAgencyEditGeneral",
            component: () => import("~/v-admin-app/src/components/website/EditAgencyGeneral.vue"),
          },
          {
            path: 'location',
            name: "rAgencyEditLocation",
            component: () => import("~/v-admin-app/src/components/website/EditAgencyGeneral.vue"),
          },
        ]
      },
      {
        path: '/pages/:pageName',
        name: "rPagesEdit",
        component: () => import("~/v-admin-app/src/pages/PagesEdit.vue"),
        children: [
          {
            path: ':pageTabName',
            name: "rPagesEditTab",
            component: () => import("~/v-admin-app/src/components/pages/EditPageTab.vue"),
          },
          // {
          //   path: '',
          //   name: "rPagesEditSingle",
          //   component: () => import("~/v-admin-app/src/components/translations/EditTranslationBatch.vue"),
          //   children: [
          //   ]
          // },
        ]
      },
      {
        path: '/translations',
        name: "rTranslationsEdit",
        component: () => import("~/v-admin-app/src/pages/TranslationsEdit.vue"),
        children: [
          {
            path: ':tBatchId',
            name: "rTranslationsEditBatch",
            component: () => import("~/v-admin-app/src/components/translations/EditTranslationBatch.vue"),
          },
        ]
      },
      {
        path: '/website/footer',
        name: "rWebsiteEditFooter",
        component: () => import("~/v-admin-app/src/pages/WebsiteEdit.vue"),
      },
      {
        path: '/website/settings',
        name: "rWebsiteEdit",
        component: () => import("~/v-admin-app/src/pages/WebsiteEdit.vue"),
        children: [
          {
            path: 'general',
            name: "rWebsiteEditGeneral",
            component: () => import("~/v-admin-app/src/components/website/EditWebsiteGeneral.vue"),
          },
          {
            path: 'appearance',
            name: "rWebsiteEditAppearance",
            component: () => import("~/v-admin-app/src/components/website/EditWebsiteGeneral.vue"),
          },
          {
            path: 'navigation',
            name: "rWebsiteEditNavigation",
            component: () => import("~/v-admin-app/src/components/website/EditWebsiteNavigation.vue"),
          }

        ]
      },
      {
        path: '/properties/list/all',
        name: "rPropertiesList",
        component: () => import("~/v-admin-app/src/pages/PropertiesList.vue"),
      },
      {
        path: '/properties/s/:prop_id',
        name: "rPropertyEdit",
        component: () => import("~/v-admin-app/src/pages/PropertyEdit.vue"),
        children: [
          {
            path: ':editTabName',
            name: "rPropertyEditTab",
            component: () => import("~/v-admin-app/src/components/properties/EditPropertyGeneral.vue"),
          },
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
