<template>
  <router-view />
</template>
<script>
import { defineComponent, ref, computed } from "vue"
import { useRoute } from "vue-router"
import { useQuery } from "@urql/vue"
import { localiseProvider } from "~/v-public-app/src/compose/localise-provider.js"
export default defineComponent({
  name: "App",
  provide: {
    localiseProvider,
  },
  watch: {
    "$route.params": {
      handler(newValue, oldVal) {
        this.messagesLocale = newValue.publicLocale
        // console.log(this.messagesLocale)
      },
    },
    gqlData: {
      handler(newValue, oldVal) {
        // console.log(this.localiseProvider)
        this.localiseProvider.setLocaleMessages(
          newValue.getTranslations.result,
          newValue.getTranslations.locale
        )
      },
    },
  },
  mounted() {},
  setup() {
    const route = useRoute()
    const messagesLocale = ref(route.params.publicLocale)
    const result = useQuery({
      pause: computed(() => !messagesLocale.value),
      variables: {
        messagesLocale,
      },
      query: `
        query ($messagesLocale: String! ) {
            getTranslations(locale: $messagesLocale) {
              locale,
              result
            }
        }
      `,
    })
    return {
      messagesLocale,
      localiseProvider,
      gqlFetching: result.fetching,
      gqlData: result.data,
      gqlError: result.error,
    }
  },
})
</script>
