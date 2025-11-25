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
          :currentFilterValues="currentFilterValues"
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
import VerticalSearchForm from "~/v-public-2-app/src/components/widgets/VerticalSearchForm.vue"
import { defineComponent, ref, watch, computed } from "vue"
import { useRoute, useRouter } from "vue-router"
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
    const router = useRouter()
    
    let saleOrRental = "rental"
    if (route.name === "rForSaleSearch") {
      saleOrRental = "sale"
    }
    
    // Helper to format price for display (add commas)
    const formatPriceForDisplay = (value) => {
      if (!value || value === "none") return "none"
      // Remove any existing commas and format with commas
      const num = value.replace(/,/g, '')
      if (num && !isNaN(num)) {
        return parseInt(num).toLocaleString('en-US')
      }
      return value
    }
    
    // Helper to format price for API (remove commas)
    const formatPriceForAPI = (value) => {
      if (!value || value === "none") return "none"
      return value.replace(/,/g, '')
    }
    
    // Initialize from URL query params or use reasonable defaults
    // Keep values as-is from URL (no comma formatting) so SelectField can match them
    // Only initialize the relevant price fields based on saleOrRental
    const forSalePriceTill = ref(saleOrRental === 'sale' ? (route.query.price_max || "none") : "none")
    const forSalePriceFrom = ref(saleOrRental === 'sale' ? (route.query.price_min || "none") : "none")
    const forRentPriceTill = ref(saleOrRental === 'rental' ? (route.query.price_max || "none") : "none")
    const forRentPriceFrom = ref(saleOrRental === 'rental' ? (route.query.price_min || "none") : "none")
    const bedroomsFrom = ref(route.query.bedrooms_min || "none")
    const bathroomsFrom = ref(route.query.bathrooms_min || "none")
    const propertyType = ref(route.query.property_type || "none")
    
    const currentFilterValues = computed(() => ({
      price_min: forSalePriceFrom.value,
      price_max: forSalePriceTill.value,
      bedrooms_min: bedroomsFrom.value,
      bathrooms_min: bathroomsFrom.value,
      property_type: propertyType.value
    }))

    const loading = ref(false)
    const error = ref(null)
    const propertiesData = ref([])

    // Transform snake_case API response to camelCase for Vue components
    const transformProperty = (prop) => {
      return {
        id: prop.id,
        title: prop.title,
        countBedrooms: prop.count_bedrooms,
        countBathrooms: prop.count_bathrooms,
        priceSaleCurrentCents: prop.price_sale_current_cents,
        priceRentalMonthlyCurrentCents: prop.price_rental_monthly_current_cents,
        currency: prop.currency,
        propPhotos: prop.prop_photos || [],
        reference: prop.reference,
        constructedArea: prop.constructed_area,
        countGarages: prop.count_garages,
        // Add other fields as needed
      }
    }

    const fetchProperties = async () => {
      loading.value = true
      error.value = null
      try {
        const params = {
          sale_or_rental: saleOrRental,
          for_sale_price_from: formatPriceForAPI(forSalePriceFrom.value),
          for_sale_price_till: formatPriceForAPI(forSalePriceTill.value),
          for_rent_price_from: formatPriceForAPI(forRentPriceFrom.value),
          for_rent_price_till: formatPriceForAPI(forRentPriceTill.value),
          bathrooms_from: bathroomsFrom.value,
          bedrooms_from: bedroomsFrom.value,
          property_type: propertyType.value,
        }
        const response = await axios.get('/api_public/v1/properties', { params })
        
        // Transform API response to camelCase
        propertiesData.value = response.data.map(transformProperty)
      } catch (err) {
        error.value = err
        console.error("Error fetching properties:", err)
      } finally {
        loading.value = false
      }
    }

    // Update URL when search parameters change
    const updateURL = () => {
      const query = {}
      
      // Only add non-default values to query params
      // Strip commas from prices for clean URLs
      if (forSalePriceFrom.value !== "none" && forSalePriceFrom.value) {
        query.price_min = formatPriceForAPI(forSalePriceFrom.value)
      }
      if (forSalePriceTill.value !== "none" && forSalePriceTill.value) {
        query.price_max = formatPriceForAPI(forSalePriceTill.value)
      }
      if (bedroomsFrom.value !== "none" && bedroomsFrom.value && bedroomsFrom.value !== "0") {
        query.bedrooms_min = bedroomsFrom.value
      }
      if (bathroomsFrom.value !== "none" && bathroomsFrom.value && bathroomsFrom.value !== "0") {
        query.bathrooms_min = bathroomsFrom.value
      }
      if (propertyType.value !== "none" && propertyType.value) {
        query.property_type = propertyType.value
      }
      
      // Update URL without reloading the page
      router.push({ query }).catch(() => {})
    }

    // Watch for changes in search parameters
    watch(
      [forSalePriceTill, forSalePriceFrom, forRentPriceTill, forRentPriceFrom, bedroomsFrom, bathroomsFrom, propertyType],
      () => {
        updateURL()
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
      currentFilterValues,
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
