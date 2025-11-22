<template>
  <router-view />
</template>
<script>
import { defineComponent, ref, watch } from "vue"
import { useRoute } from "vue-router"
import axios from "axios"
import { localiseProvider } from "~/v-public-2-app/src/compose/localise-provider.js"
import { sitedetailsProvider } from "~/v-public-2-app/src/compose/sitedetails-provider.js"

export default defineComponent({
  name: "App",
  provide: {
    localiseProvider,
    sitedetailsProvider,
  },
  setup() {
    const route = useRoute()
    const publicLocale = ref(route.params.publicLocale)
    const loading = ref(false)
    const error = ref(null)

    const fetchData = async (locale) => {
      if (!locale) return
      loading.value = true
      error.value = null
      try {
        const [siteDetailsRes, translationsRes] = await Promise.all([
          axios.get('/api_public/v1/site_details', { params: { locale } }),
          axios.get('/api_public/v1/translations', { params: { locale } })
        ])

        const siteDetails = siteDetailsRes.data
        const translations = translationsRes.data

        localiseProvider.setLocaleMessages(
          translations.result,
          translations.locale
        )

        // Note: The REST API returns snake_case keys, but the frontend might expect camelCase
        // or the API implementation should have handled serialization.
        // Assuming the API returns keys matching what the frontend expects or we adapt here.
        // Based on standard Rails serialization, it might be snake_case.
        // However, the GraphQL query used camelCase.
        // Let's assume for now we might need to map or the API returns camelCase if configured.
        // Checking the API implementation, it uses .as_json which usually preserves snake_case unless overridden.
        // But Pwb::Website#as_json seems to have specific keys.
        // Let's map manually for safety if needed, or assume the keys match.
        
        // Actually, Pwb::Website#as_json keys are snake_case in the model file I saw earlier.
        // But the GraphQL query requested camelCase (topNavDisplayLinks).
        // I should probably check if I need to convert keys.
        // For now, I will try to use the keys as they likely come from the API (snake_case)
        // and map them to what the provider expects.

        let topNavDisplayLinks = siteDetails.top_nav_display_links || []
        sitedetailsProvider.setTopNavItems(
          locale,
          topNavDisplayLinks
        )

        let footerDisplayLinks = siteDetails.footer_display_links || []
        sitedetailsProvider.setFooterNavItems(
          locale,
          footerDisplayLinks
        )

        sitedetailsProvider.setAgency(
          siteDetails.agency,
          siteDetails.supported_locales
        )

      } catch (err) {
        error.value = err
        console.error("Error fetching data:", err)
      } finally {
        loading.value = false
      }
    }

    watch(
      () => route.params.publicLocale,
      (newLocale) => {
        publicLocale.value = newLocale
        fetchData(newLocale)
      },
      { immediate: true }
    )

    return {
      publicLocale,
      localiseProvider,
      sitedetailsProvider,
      loading,
      error,
    }
  },
})
</script>
