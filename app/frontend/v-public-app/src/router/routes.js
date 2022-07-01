const routes = [

  {
    path: '/',
    component: () => import('~/v-public-app/src/layouts/PublicLayout.vue'),
    children: [
      {
        path: '',
        name: 'rDefaultLocaleHomePage',
        component: () => import("~/v-public-app/src/components/PageContainer.vue"),
      },
      {
        path: '/:publicLocale',
        name: 'rLocaleHome',
        component: () => import("~/v-public-app/src/components/EmptyContainer.vue"),
        children: [
          {
            path: '',
            name: 'rLocaleHomePage',
            component: () => import("~/v-public-app/src/components/PageContainer.vue"),
          },
          {
            path: 'p/:pageSlug',
            name: "rPublicPage",
            component: () => import("~/v-public-app/src/components/PageContainer.vue"),
          },
          {
            path: 'contact-us',
            name: "rContactUs",
            component: () => import("~/v-public-app/src/components/SearchView.vue"),
          },
          {
            path: 'for-sale',
            name: "rForSaleSearch",
            component: () => import("~/v-public-app/src/components/SearchView.vue"),
          },
          {
            path: 'for-sale/:listingSlug',
            name: "rForSaleListing",
            component: () => import("~/v-public-app/src/components/ListingView.vue"),
          },
          {
            path: 'for-rent',
            name: "rForRentSearch",
            component: () => import("~/v-public-app/src/components/SearchView.vue"),
          },
          {
            path: 'for-rent/:listingSlug',
            name: "rForRentListing",
            component: () => import("~/v-public-app/src/components/ListingView.vue"),
          },
        ]
      },
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
