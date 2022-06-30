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
      </q-toolbar>
    </q-header>

    <q-page-container class="bg-grey-2">
      <router-view />
    </q-page-container>
  </q-layout>
</template>
<script>
import { defineComponent, ref } from "vue"
// import { useQuery } from "@urql/vue"
export default defineComponent({
  name: "PublicLayout",
  components: {},
  computed: {
    // supportedLocaleDetails() {
    //   let supportedLocales = this.currentWebsite.supported_locales || []
    //   let supportedLocaleDetails = []
    //   supportedLocales.forEach((localeWithVariant) => {
    //     let localeOnly = localeWithVariant.split("-")[0]
    //     supportedLocaleDetails.push({
    //       localeOnly: localeOnly,
    //       localeWithVariant: localeWithVariant,
    //       label: this.adminTranslations[localeOnly],
    //     })
    //   })
    //   return supportedLocaleDetails
    // },
  },
  mounted: function () {},
  data() {
    return {
      // adminTranslations: {},
      activeTab: null,
    }
  },
  setup() {
    // const result = useQuery({
    //   query: `
    //     query {
    //       findPage(slug: "home") {
    //         rawHtml,
    //         pageParts {
    //           blockContents
    //           createdAt
    //           pageSlug
    //         }
    //       }
    //     }
    //   `,
    // })

    // return {
    //   fetching: result.fetching,
    //   data: result.data,
    //   error: result.error,
    // }
  },
})
</script>
