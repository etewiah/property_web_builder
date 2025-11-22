<template>
  <q-layout view="lHh Lpr lFf">
    <q-header elevated>
      <div
        class="row q-toolbar"
        style="min-height: 10px; border-bottom: 1px solid white"
      >
        <div class="col-md-12">
          <div class="aa-header-area max-ctr">
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
                      {{ sitedetailsProvider.state.agency.phoneNumberPrimary }}
                    </div>
                  </div>
                  <div class="aa-email hidden-xs float-left">
                    <q-icon
                      class="q-pb-xs q-pr-xs q-pl-md"
                      color="white"
                      name="email"
                    />
                    <div class="q-pt-xs" style="display: inline-flex">
                      {{ sitedetailsProvider.state.agency.emailPrimary }}
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
                        active-class="selected"
                        :to="langNav.route"
                        custom
                        v-slot="{ href, navigate, isActive, isExactActive }"
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
      <q-toolbar class="max-ctr">
        <q-toolbar-title>
          <strong>{{ sitedetailsProvider.state.agency.displayName }}</strong>
          <!-- <span style="color: black">Web</span
          ><strong class="navy--text text--darken-1">Builder</strong> -->
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
    <PwbFooter></PwbFooter>
  </q-layout>
</template>
<script>
import { defineComponent } from "vue"
import PwbFooter from "~/v-public-app/src/components/widgets/PwbFooter.vue"
export default defineComponent({
  name: "PublicLayout",
  inject: ["localiseProvider", "sitedetailsProvider"],
  components: { PwbFooter },
  computed: {
    langNavs() {
      let supportedLocales =
        this.sitedetailsProvider.state.supportedLocales || []
      // ["en", "es"]
      let langNavs = []
      supportedLocales.forEach((supportedLocale) => {
        let shortLocale = supportedLocale.split("-")[0]
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
      return this.sitedetailsProvider.state.topNavLinkItems
    },
  },
  watch: {},
  mounted: function () {},
  data() {
    return {}
  },
  setup() {},
})
</script>
