<template>
  <router-view />
</template>
<script>
import { defineComponent } from "vue"
import { websiteProvider } from "~/v-admin-app/src/compose/website-provider.js"
export default defineComponent({
  name: "App",
  provide: {
    websiteProvider,
  },
})
</script>
