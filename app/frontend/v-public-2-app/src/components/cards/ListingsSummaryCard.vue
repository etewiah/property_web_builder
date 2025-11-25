<template>
  <div>
    <q-card class="listings-summary-card">
      <q-card-section horizontal>
        <q-responsive
          class="col"
          :ratio="16 / 9"
          style="max-width: 100%; min-height: 30vh"
        >
          <q-carousel animated v-model="slideModel" arrows infinite>
            <q-carousel-slide
              v-for="image in carouselSlides"
              :name="image.src"
              :key="image.src"
              :img-src="image.src"
            >
              <q-scroll-area class="fit"> </q-scroll-area>
            </q-carousel-slide>
          </q-carousel>
        </q-responsive>
        <!-- <q-img class="" :ratio="16 / 9" :src="summaryImageUrl" /> -->
      </q-card-section>

      <q-separator />
      <router-link style="text-decoration: none" :to="currentListingRoute">
        <div class="q-pa-md">
            <q-item-section>
              <router-link
                style="text-decoration: none"
                :to="currentListingRoute"
              >
                <!-- <q-item-label overline>OVERLINE</q-item-label> -->
                <q-item-label>{{ currentListing.title }}</q-item-label>
                <q-item-label caption>
                  <ConvertableCurrencyDisplay
                    :priceInCents="priceInCents"
                    :originalCurrency="currentListing.currency || 'GBP'"
                    class="property-price"
                  ></ConvertableCurrencyDisplay>
                </q-item-label>
                <q-item-label caption v-if="currentListing.reference" class="property-reference">
                  Ref: {{ currentListing.reference }}
                </q-item-label>
              </router-link>
            </q-item-section>
        </div>
        <q-card-actions class="w-full">
          <div>
            <div class="q-pa-md row no-wrap items-center justify-around">
              <div class="flex-1 inline-flex items-center q-pr-sm property-bedrooms">
                <q-icon size="1rem">
                  <svg
                    class="h-6 w-6 text-gray-600 fill-current mr-3"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                  >
                    <path
                      d="M0 16L3 5V1a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v4l3 11v5a1 1 0 0 1-1 1v2h-1v-2H2v2H1v-2a1 1 0 0 1-1-1v-5zM19 5h1V1H4v4h1V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1h2V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v1zm0 1v2a1 1 0 0 1-1 1h-4a1 1 0 0 1-1-1V6h-2v2a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6H3.76L1.04 16h21.92L20.24 6H19zM1 17v4h22v-4H1zM6 4v4h4V4H6zm8 0v4h4V4h-4z"
                    ></path>
                  </svg>
                </q-icon>
                <div style="display: inline; margin-left: 8px">
                  <span class="text-gray-900 text-weight-bold">
                    {{ currentListing.countBedrooms }}
                  </span>
                  Bedrooms
                </div>
              </div>
              <div class="flex-1 inline-flex items-center q-pl-sm property-bathrooms">
                <q-icon size="1rem">
                  <svg
                    class="h-6 w-6 text-gray-600 fill-current mr-3"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M17.03 21H7.97a4 4 0 0 1-1.3-.22l-1.22 2.44-.9-.44 1.22-2.44a4 4 0 0 1-1.38-1.55L.5 11h7.56a4 4 0 0 1 1.78.42l2.32 1.16a4 4 0 0 0 1.78.42h9.56l-2.9 5.79a4 4 0 0 1-1.37 1.55l1.22 2.44-.9.44-1.22-2.44a4 4 0 0 1-1.3.22zM21 11h2.5a.5.5 0 1 1 0 1h-9.06a4.5 4.5 0 0 1-2-.48l-2.32-1.15A3.5 3.5 0 0 0 8.56 10H.5a.5.5 0 0 1 0-1h8.06c.7 0 1.38.16 2 .48l2.32 1.15a3.5 3.5 0 0 0 1.56.37H20V2a1 1 0 0 0-1.74-.67c.64.97.53 2.29-.32 3.14l-.35.36-3.54-3.54.35-.35a2.5 2.5 0 0 1 3.15-.32A2 2 0 0 1 21 2v9zm-5.48-9.65l2 2a1.5 1.5 0 0 0-2-2zm-10.23 17A3 3 0 0 0 7.97 20h9.06a3 3 0 0 0 2.68-1.66L21.88 14h-7.94a5 5 0 0 1-2.23-.53L9.4 12.32A3 3 0 0 0 8.06 12H2.12l3.17 6.34z"
                    ></path>
                  </svg>
                </q-icon>
                <div style="display: inline; margin-left: 8px">
                  <span class="text-gray-900 text-weight-bold">
                    {{ currentListing.countBathrooms }}
                  </span>
                  Bathrooms
                </div>
              </div>
              <div class="flex-1 inline-flex items-center q-pl-sm property-area" v-if="currentListing.constructedArea">
                <q-icon name="aspect_ratio" size="1rem" class="text-gray-600 mr-3" />
                <div style="display: inline; margin-left: 8px">
                  <span class="text-gray-900 text-weight-bold">
                    {{ currentListing.constructedArea }}
                  </span>
                  m²
                </div>
              </div>
              <div class="flex-1 inline-flex items-center q-pl-sm property-garages" v-if="currentListing.countGarages">
                <q-icon name="garage" size="1rem" class="text-gray-600 mr-3" />
                <div style="display: inline; margin-left: 8px">
                  <span class="text-gray-900 text-weight-bold">
                    {{ currentListing.countGarages }}
                  </span>
                  Garages
                </div>
              </div>
            </div>
          </div>
        </q-card-actions>
      </router-link>
    </q-card>
  </div>
</template>
<script>
import ConvertableCurrencyDisplay from "~/v-public-app/src/components/widgets/ConvertableCurrencyDisplay.vue"
export default {
  components: {
    ConvertableCurrencyDisplay,
  },
  props: {
    saleOrRental: {
      type: String,
      default: "sale",
    },
    currentListing: {
      type: Object,
      default() {
        return {}
      },
    },
    // currentListingContainer: {
    //   type: Object,
    //   default() {
    //     return {}
    //   },
    // },
  },
  data: () => ({
    // cardExpansionState: false,
    slideModel: 1,
  }),
  methods: {
    startExpandDetails(event) {
      if (event) {
        event.preventDefault()
      }
    },
    stopExpandDetails(event) {
      if (event) {
        event.preventDefault()
      }
    },
  },
  watch: {
    carouselSlides: {
      deep: true,
      immediate: true,
      handler: function (newVal) {
        // needed to set initial image
        if (newVal[0]) {
          this.slideModel = newVal[0].src
        }
      },
    },
  },
  computed: {
    carouselSlides() {
      var carouselSlides = []
      var picsColl = this.currentListing.propPhotos || []
      picsColl.forEach(function (picObject, index) {
        let imageUrl = picObject.image
        if (imageUrl[0] === "/") {
          // imageUrl = `${dataApiBase}${picObject.image_details.url}`
        }
        carouselSlides.push({
          thumb: imageUrl,
          src: imageUrl,
          alt_text: "",
        })
      })
      return carouselSlides
    },
    // featuresChecklist() {
    //   return (
    //     this.currentListingContainer.item.checklist_values_for_features || {}
    //   )
    // },
    summaryImageUrl() {
      return this.currentListing.preview_url
    },
    priceInCents() {
      if (this.saleOrRental === "rental") {
        return this.currentListing.priceRentalMonthlyCurrentCents
      } else {
        return this.currentListing.priceSaleCurrentCents
      }
    },
    currentListingRoute() {
      let listingSlug = this.currentListing.id || "1"
      let routeName = "rForSaleListing"
      if (this.saleOrRental === "rental") {
        routeName = "rForRentListing"
      }
      return {
        name: routeName,
        params: {
          listingSlug: listingSlug,
          // listings_grouping: "for-sale",
        },
      }
    },
  },
  mounted: function () {},
}
</script>
<style></style>
