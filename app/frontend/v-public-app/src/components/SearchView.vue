<template>
  <div class="q-ma-md">
    <h3 class="text-center">{{ searchHeaderText }}</h3>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
    <div class="row q-col-gutter-md">
      <div class="col-sm-12 col-md-4 col-lg-3">
        <h6>Search For Properties</h6>
        <VerticalSearchForm
          @triggerSearchUpdate="triggerSearchUpdate"
        ></VerticalSearchForm>
      </div>
      <div class="col-sm-12 col-md-8 col-lg-9">
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
    </div>
  </div>
</template>
<script>
import ListingsSummaryCard from "~/v-public-app/src/components/cards/ListingsSummaryCard.vue"
import VerticalSearchForm from "~/v-public-app/src/components/widgets/VerticalSearchForm.vue"
import { defineComponent, ref } from "vue"
import { useQuery } from "@urql/vue"
import { useRouter, useRoute } from "vue-router"
export default defineComponent({
  name: "SearchView",
  components: {
    ListingsSummaryCard,
    VerticalSearchForm,
  },
  methods: {
    triggerSearchUpdate(fieldDetails) {
      this[fieldDetails.fieldName] = fieldDetails.newValue
    },
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
    const forSalePriceTill = ref("200000")
    const forSalePriceFrom = ref("1000")
    const bedroomsFrom = ref("none")
    const bathroomsFrom = ref("none")
    const result = useQuery({
      variables: {
        forSalePriceTill,
        forSalePriceFrom,
        bathroomsFrom,
        bedroomsFrom,
      },
      query: `
        query ($forSalePriceTill: String!, $forSalePriceFrom: String!,
          $bedroomsFrom: String!, $bathroomsFrom: String! ) {
          searchProperties(saleOrRental: "${saleOrRental}",
          forSalePriceFrom: $forSalePriceFrom,
          forSalePriceTill: $forSalePriceTill,
          bathroomsFrom: $bathroomsFrom,
          bedroomsFrom: $bedroomsFrom) {
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
      bathroomsFrom,
      bedroomsFrom,
      forSalePriceFrom,
      forSalePriceTill,
      saleOrRental,
      fetching: result.fetching,
      data: result.data,
      error: result.error,
    }
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
})
</script>
