<template>
  <div class="q-ma-md">
    <h3>{{ searchHeaderText }}</h3>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
    <div class="row q-col-gutter-md">
      <div
        class="col-sm-6 col-md-4"
        v-for="property in properties"
        :key="property.id"
      >
        <ListingsSummaryCard
          :saleOrRental="saleOrRental"
          :currentListing="property"
        ></ListingsSummaryCard>
      </div>
    </div>
  </div>
</template>
<script>
import ListingsSummaryCard from "~/v-public-app/src/components/cards/ListingsSummaryCard.vue"
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "SearchView",
  components: {
    ListingsSummaryCard,
  },
  computed: {
    searchHeaderText() {
      if (this.$route.name === "rForSaleSearch") {
        return "Properties for sale"
      } else {
        return "Properties for rent"
      }
    },
    properties() {
      let properties = this.data ? this.data.searchProperties : []
      return properties
    },
    pageContents() {
      let pageContents = []
      if (this.data && this.data.findPage.pageContents) {
        // pageContents[0].content.raw_en
        this.data.findPage.pageContents.forEach((pageContent) => {
          if (pageContent.content) {
            pageContents.push(pageContent.content.raw_en)
          }
        })
      }
      return pageContents
    },
  },
  mounted: function () {},
  data() {
    return {}
  },
  setup() {
    // const router = useRouter()
    const route = useRoute()
    let pageSlug = "rent"
    let saleOrRental = "rental"
    if (route.name === "rForSaleSearch") {
      pageSlug = "buy"
      saleOrRental = "sale"
    }
    const result = useQuery({
      query: `
        query {
          searchProperties(saleOrRental: "${saleOrRental}", forSalePriceTill: "500000") {
            id,
            propPhotos {
              image
            },
            currency,
            countBedrooms,
            countBathrooms,
            streetAddress,
            title,
            description,
            plotArea,
            priceSaleCurrentCents,
            priceRentalMonthlyCurrentCents,
            countBathrooms
          }
          findPage(slug: "${pageSlug}") {
            rawHtml,
            pageContents {
              content
            },
            pageParts {
              blockContents
              pageSlug
            }
          }
        }
      `,
    })

    return {
      saleOrRental,
      fetching: result.fetching,
      data: result.data,
      error: result.error,
    }
  },
})
</script>
