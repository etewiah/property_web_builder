<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <div class="row q-toolbar" style="min-height: 10px">
        <div class="col-md-12">
          <div class="aa-header-area">
            <div class="row">
              <div class="col-md-6 col-sm-6 col-xs-6">
                <div class="aa-header-left">
                  <div class="aa-telephone-no float-left">
                    <q-icon
                      class="q-pb-xs q-pr-xs"
                      color="white"
                      name="phone"
                    />
                    <div class="q-pt-xs" style="display: inline-flex">
                      +34 672 550 305 &nbsp;&nbsp;
                    </div>
                  </div>
                  <div class="aa-email hidden-xs float-left">
                    <q-icon
                      class="q-pb-xs q-pr-xs q-pl-md"
                      color="white"
                      name="email"
                    />
                    <div class="q-pt-xs" style="display: inline-flex">
                      contact@example.com
                    </div>
                  </div>
                </div>
              </div>
              <div class="col-md-6 col-sm-6 col-xs-6">
                <div class="aa-header-right">
                  <div class="contenedor_idiomas" style="">
                    <ul class="idiomas">
                      <router-link
                        v-for="langNav in langNavs"
                        :key="langNav.shortLocale"
                        :class="langNav.shortLocale"
                        active-class="selected"
                        style="text-decoration: none"
                        :to="langNav.route"
                        custom
                        v-slot="{
                          href,
                          route,
                          navigate,
                          isActive,
                          isExactActive,
                        }"
                      >
                        <li
                          :class="[
                            isActive && 'selected',
                            isExactActive && 'router-link-exact-active',
                          ]"
                        >
                          <a
                            :class="langNav.shortLocale"
                            :href="href"
                            @click="navigate"
                          ></a>
                        </li>
                      </router-link>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
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
    langNavs() {
      let shortLocales = ["en", "es"]
      let langNavs = []
      shortLocales.forEach((shortLocale) => {
        langNavs.push({
          shortLocale: shortLocale,
          route: {
            params: {
              publicLocale: shortLocale,
            },
          },
        })
      })
      return langNavs
    },
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
