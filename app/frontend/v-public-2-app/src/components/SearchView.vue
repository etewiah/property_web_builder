<template>
  <div class="q-ma-md">
    <h3 class="text-center">
      {{ localiseProvider.$ft(searchHeaderText) }}
    </h3>
    <div v-for="pageContent in pageContents" :key="pageContent.id">
      <div v-html="pageContent"></div>
    </div>
    <div class="row q-col-gutter-md">
      <div class="col-sm-12 col-md-4 col-lg-3">
        <h6>
          {{ localiseProvider.$ft("searchForProperties") }}
        </h6>
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
import { defineComponent, ref, watch } from "vue"
import { useRoute } from "vue-router"
import axios from "axios"

export default defineComponent({
  inject: ["localiseProvider"],
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
    const route = useRoute()
    let saleOrRental = "rental"
    if (route.name === "rForSaleSearch") {
      saleOrRental = "sale"
    }
    const forSalePriceTill = ref("none")
    const forSalePriceFrom = ref("none")
    const forRentPriceTill = ref("none")
    const forRentPriceFrom = ref("none")
    const bedroomsFrom = ref("none")
    const bathroomsFrom = ref("none")
    const propertyType = ref("none")
    
    const loading = ref(false)
    const error = ref(null)
    const propertiesData = ref([])

    const fetchProperties = async () => {
      loading.value = true
      error.value = null
      try {
        const params = {
          sale_or_rental: saleOrRental,
          for_sale_price_from: forSalePriceFrom.value,
          for_sale_price_till: forSalePriceTill.value,
          for_rent_price_from: forRentPriceFrom.value,
          for_rent_price_till: forRentPriceTill.value,
          bathrooms_from: bathroomsFrom.value,
          bedrooms_from: bedroomsFrom.value,
          property_type: propertyType.value,
        }
        const response = await axios.get('/api_public/v1/properties', { params })
        propertiesData.value = response.data
      } catch (err) {
        error.value = err
        console.error("Error fetching properties:", err)
      } finally {
        loading.value = false
      }
    }

    // Watch for changes in search parameters
    watch(
      [forSalePriceTill, forSalePriceFrom, forRentPriceTill, forRentPriceFrom, bedroomsFrom, bathroomsFrom, propertyType],
      () => {
        fetchProperties()
      },
      { immediate: true }
    )

    return {
      bathroomsFrom,
      bedroomsFrom,
      forSalePriceFrom,
      forSalePriceTill,
      forRentPriceFrom,
      forRentPriceTill,
      propertyType,
      saleOrRental,
      loading,
      propertiesData,
      error,
    }
  },
  computed: {
    searchHeaderText() {
      if (this.$route.name === "rForSaleSearch") {
        return "forSale"
      } else {
        return "forRent"
      }
    },
    properties() {
      return this.propertiesData
    },
    pageContents() {
      let pageContents = []
      // Currently no page specific to searches
      return pageContents
    },
  },
  mounted: function () {},
  data() {
    return {}
  },
})
</script>
