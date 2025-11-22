<template>
  <div class="q-ma-md">
    <div class="row">
      <div class="col-12">
        <ViewContainer :currentListing="currentListing"></ViewContainer>
      </div>
    </div>
  </div>
</template>
<script>
import ViewContainer from "~/v-public-app/src/components/listings/ViewContainer.vue"
import { defineComponent, ref, watch } from "vue"
import { useRoute } from "vue-router"
import axios from "axios"

export default defineComponent({
  name: "ListingView",
  components: {
    ViewContainer,
  },
  computed: {
    currentListing() {
      let currentListing = {}
      if (this.error) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: this.error.message,
          icon: "report_problem",
        })
      } else {
        currentListing = this.listingData || {}
      }
      return currentListing
    },
  },
  setup() {
    const route = useRoute()
    let listingSlug = route.params.listingSlug
    const publicLocale = ref(route.params.publicLocale)
    
    const loading = ref(false)
    const error = ref(null)
    const listingData = ref(null)

    const fetchProperty = async (locale) => {
      if (!locale) return
      loading.value = true
      error.value = null
      try {
        const response = await axios.get(`/api_public/v1/properties/${listingSlug}`, {
          params: { locale }
        })
        listingData.value = response.data
      } catch (err) {
        error.value = err
        console.error("Error fetching property:", err)
      } finally {
        loading.value = false
      }
    }

    watch(
      () => route.params.publicLocale,
      (newLocale) => {
        publicLocale.value = newLocale
        fetchProperty(newLocale)
      },
      { immediate: true }
    )

    return {
      loading,
      listingData,
      error,
    }
  },
})
</script>
