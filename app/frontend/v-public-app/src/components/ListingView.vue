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
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "ListingView",
  components: {
    ViewContainer,
  },
  computed: {
    currentListing() {
      let currentListing = {}
      if (this.gqlError) {
        this.$q.notify({
          color: "negative",
          position: "top",
          message: this.gqlError.message,
          icon: "report_problem",
        })
      } else {
        currentListing = this.gqlData ? this.gqlData.findProperty : []
      }
      return currentListing
    },
  },
  setup() {
    const route = useRoute()
    let listingSlug = route.params.listingSlug
    const publicLocale = ref(route.params.publicLocale)
    const result = useQuery({
      variables: {
        publicLocale,
      },
      query: `
        query ($publicLocale: String! ) {
          findProperty(id: "${listingSlug}", locale: $publicLocale) {
            id,
            propPhotos {
              createdAt
              image
            },
            extrasForDisplay,
            plotArea,
            priceSaleCurrentCents,
            priceRentalMonthlyCurrentCents,
            countBathrooms,
            countBedrooms,
            streetAddress,
            latitude,
            longitude,
            title,
            description
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
