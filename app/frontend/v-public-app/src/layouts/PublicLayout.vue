<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <q-toolbar>
        <q-toolbar-title>
          <strong>Property</strong><span style="color: black">Web</span
          ><strong class="navy--text text--darken-1">Builder</strong>
        </q-toolbar-title>
        <q-space />
        <div class="q-gutter-sm row items-center no-wrap">
          <!-- <q-btn round flat>
            <q-avatar size="26px">
              <img src="https://cdn.quasar.dev/img/boy-avatar.png" />
            </q-avatar>
          </q-btn> -->
        </div>
        <q-tabs shrink>
          <q-route-tab
            v-for="topNavLink in topNavLinks"
            :key="topNavLink.id"
            :to="topNavLink.route"
            :label="topNavLink.linkTitle"
            :exact="true"
          />
        </q-tabs>
      </q-toolbar>
    </q-header>

    <q-page-container class="bg-grey-2">
      <q-page class="max-ctr">
        <router-view :key="$route" />
      </q-page>
    </q-page-container>
  </q-layout>
</template>
<script>
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
// import { useRoute } from "vue-router"
import loSortBy from "lodash/sortBy"
export default defineComponent({
  name: "PublicLayout",
  inject: ["localiseProvider"],
  components: {},
  computed: {
    topNavLinks() {
      let topNavLinks = []
      if (this.gqlError) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: this.gqlError.message,
          icon: "report_problem",
        })
      } else {
        if (this.gqlData && this.gqlData.getTopNavLinks) {
          let publicLocale = "en"
          this.gqlData.getTopNavLinks.forEach((navLink) => {
            if (navLink.linkPath === "buy_path") {
              navLink.route = {
                name: "rForSaleSearch",
                params: {
                  publicLocale: publicLocale,
                },
              }
            } else if (navLink.linkPath === "rent_path") {
              navLink.route = {
                name: "rForRentSearch",
                params: {
                  publicLocale: publicLocale,
                },
              }
            } else if (navLink.linkPath === "contact_us_path") {
              navLink.route = {
                name: "rContactUs",
                params: {
                  publicLocale: publicLocale,
                },
              }
            } else if (navLink.linkPath === "show_page_path") {
              navLink.route = {
                name: "rPublicPage",
                params: {
                  pageSlug: navLink.linkPathParams,
                  publicLocale: publicLocale,
                },
              }
            } else {
              navLink.route = {
                name: "rLocaleHomePage",
                params: {
                  pageSlug: navLink.linkPathParams,
                  publicLocale: publicLocale,
                },
              }
            }
            topNavLinks.push(navLink)
          })
        }
      }
      return loSortBy(topNavLinks, "sortOrder")
    },
  },
  mounted: function () {},
  data() {
    return {
      activeTab: null,
    }
  },
  setup() {
    const result = useQuery({
      query: `
        query {
        getTopNavLinks {
          sortOrder,
          slug,
          linkUrl,
          linkPath,
          linkTitle,
          linkPathParams,
          id,
          placement
        }
        getFooterLinks {
          sortOrder,
          slug,
          linkUrl,
          linkPath,
          linkTitle,
          linkPathParams,
          id,
          placement
        }
        }
      `,
    })
    return {
      gqlFetching: result.fetching,
      gqlData: result.data,
      gqlError: result.error,
    }
  },
})
</script>
