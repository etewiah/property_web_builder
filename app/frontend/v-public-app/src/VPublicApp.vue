<template>
  <router-view />
</template>
<script>
import { defineComponent, ref, computed } from "vue"
import { useRoute } from "vue-router"
import { useQuery } from "@urql/vue"
import { localiseProvider } from "~/v-public-app/src/compose/localise-provider.js"
import { sitedetailsProvider } from "~/v-public-app/src/compose/sitedetails-provider.js"
export default defineComponent({
  name: "App",
  provide: {
    localiseProvider,
    sitedetailsProvider,
  },
  // inject: ["sitedetailsProvider"],
  watch: {
    "$route.params": {
      handler(newValue, oldVal) {
        this.publicLocale = newValue.publicLocale
        // console.log(this.publicLocale)
      },
    },
    gqlError: {
      handler(newError) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: newError.message,
          icon: "report_problem",
        })
      },
    },
    gqlData: {
      handler(newValue, oldVal) {
        this.localiseProvider.setLocaleMessages(
          newValue.getTranslations.result,
          newValue.getTranslations.locale
        )
        let topNavDisplayLinks =
          newValue.getSiteDetails.topNavDisplayLinks || []
        this.sitedetailsProvider.setTopNavItems(
          this.publicLocale,
          topNavDisplayLinks
        )
        let footerDisplayLinks =
          newValue.getSiteDetails.footerDisplayLinks || []
        this.sitedetailsProvider.setFooterNavItems(
          this.publicLocale,
          footerDisplayLinks
        )
        this.sitedetailsProvider.setAgency(
          newValue.getSiteDetails.agency,
          newValue.getSiteDetails.supportedLocales
        )
      },
    },
  },
  mounted() {},
  setup() {
    const route = useRoute()
    const publicLocale = ref(route.params.publicLocale)
    const result = useQuery({
      pause: computed(() => !publicLocale.value),
      variables: {
        publicLocale,
      },
      query: `
        query ($publicLocale: String! ) {
            getSiteDetails(locale: $publicLocale) {
                supportedLocales,
                styleVariables,
                supportedLocalesWithVariants,
                agency {
                  emailPrimary,
                  displayName,
                  phoneNumberPrimary
                }
                footerDisplayLinks {
                  sortOrder,
                  slug,
                  linkUrl,
                  linkPath,
                  linkTitle,
                  linkPathParams,
                }
                topNavDisplayLinks {
                  sortOrder,
                  slug,
                  linkUrl,
                  linkPath,
                  linkTitle,
                  linkPathParams,
                }
            }
            getTranslations(locale: $publicLocale) {
              locale,
              result
            }
        }
      `,
    })
    return {
      publicLocale,
      localiseProvider,
      sitedetailsProvider,
      gqlFetching: result.fetching,
      gqlData: result.data,
      gqlError: result.error,
    }
  },
})
</script>
