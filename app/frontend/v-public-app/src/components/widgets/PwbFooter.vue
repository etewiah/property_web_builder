<template>
  <q-footer v-if="timeToShowFooter" elevated class="bg-grey-8 text-white">
    <q-toolbar>
      <q-toolbar-title>
        <div class="text-center q-pa-sm text-body1">
          <router-link
            class="text-white q-px-lg"
            style="text-decoration: none"
            v-for="topNavLink in footerNavLinks"
            :key="topNavLink.linkTitle"
            :to="topNavLink.route"
            :exact="true"
          >
            {{ topNavLink.linkTitle }}
          </router-link>
          <a
            href="/v-admin"
            class="text-white q-px-lg"
            exact="true"
            style="text-decoration: none"
          >
            Admin
          </a>
        </div>
      </q-toolbar-title>
    </q-toolbar>
    <div class="q-pa-sm">
      <div class="copyright-foot width-full">
        <div :class="copywriteClass">
          Copyright © 2021 - 2022
          <a class="text-white" href="/">
            {{ configData.whitelabelNameDisplay }}
          </a>
        </div>
      </div>
    </div>
  </q-footer>
</template>
<script>
import { defineComponent, ref } from "vue"
// import { currentConfigData } from "src/utils/config-data"
export default defineComponent({
  name: "PwbFooter",
  inject: ["sitedetailsProvider"],
  mounted() {
    setTimeout(() => {
      // footer sometimes loading before rest of page
      // This avoids that
      this.timeToShowFooter = true
      // TODO - investigate if this is affecting pagespeed
      // might want to wrap in a q-no-ssr tag
    }, 500)
  },
  data() {
    return {
      timeToShowFooter: false,
    }
  },
  computed: {
    footerNavLinks() {
      return this.sitedetailsProvider.state.footerNavLinkItems
    },
    configData() {
      let configData = {} // currentConfigData()
      return configData
    },
    copywriteClass() {
      if (this.$q.screen.lt.md) {
        return "text-center"
      } else {
        return "float-right"
      }
    },
  },
})
</script>
