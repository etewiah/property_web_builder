<template>
  <div class="row q-col-gutter-sm">
    <div class="col-sm-12">
      <h3 class="text-gray text-center">
        {{ currentListing.title }}
      </h3>
    </div>
    <div class="col-sm-12 col-md-9">
      <div v-scroll="onScroll" class="">
        <ListingCarousel
          :showThumbnails="listingScrolled"
          :currentListing="currentListing"
        ></ListingCarousel>
      </div>
    </div>
    <div class="col-sm-12 col-md-3">
      <ListingEnquiry :currentListing="currentListing"></ListingEnquiry>
    </div>
    <div class="col-sm-12">
      <div class="text-h6">
        <ConvertableCurrencyDisplay
          :priceInCents="priceInCents"
          :originalCurrency="currentListing.currency || 'GBP'"
        ></ConvertableCurrencyDisplay>
      </div>
      <q-separator />
      <div class="q-py-md row no-wrap items-center justify-arou">
        <div class="flex-1 inline-flex items-center q-pr-sm">
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
        <div class="flex-1 inline-flex items-center q-pl-sm">
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
      </div>

      <div class="text-gray text-body1 q-py-lg">
        {{ currentListing.description }}
      </div>

      <div
        v-if="currentListing.extrasForDisplay.length > 0"
        class="text-gray text-body1 q-py-lg"
      >
        <div class="text-h6">Features</div>
        <div>
          <q-item
            v-for="feature in currentListing.extrasForDisplay"
            :key="feature"
            class="q-pl-none q-mb-sm border-gray-800 bg-gray-200 border-2"
          >
            <q-item-section side>
              <q-icon color="green" name="done" />
            </q-item-section>
            <q-item-section class="q-mr-sm">
              <q-item-label class="text-weight-medium text-h6"> </q-item-label>
              {{ feature }}
            </q-item-section>
          </q-item>
        </div>
      </div>
    </div>
    <div class="col-sm-12">
      <div class="col-12">
        <MapViewContainer :singleLatLngDetails="currentListing">
        </MapViewContainer>
      </div>
    </div>
  </div>
</template>
<script>
import { ref } from "vue"
import { debounce } from "quasar"
import ListingCarousel from "~/v-public-app/src/components/listings/ListingCarousel.vue"
import ListingEnquiry from "~/v-public-app/src/components/listings/ListingEnquiry.vue"
import ConvertableCurrencyDisplay from "~/v-public-app/src/components/widgets/ConvertableCurrencyDisplay.vue"
import MapViewContainer from "~/v-public-app/src/components/widgets/MapViewContainer.vue"
export default {
  components: {
    MapViewContainer,
    ConvertableCurrencyDisplay,
    ListingCarousel,
    ListingEnquiry,
  },
  setup() {
    let listingScrolled = ref(false)
    function onScroll(position) {
      listingScrolled.value = true
      // when this method is invoked then it means user
      // has scrolled the page to `position`
      //
      // `position` is an Integer designating the current
      // scroll position in pixels.
    }

    return {
      listingScrolled,
      onScroll: debounce(onScroll, 200), // debounce for 200ms
    }
  },
  props: {
    cardIndex: {
      type: Number,
    },
    currentListing: {
      type: Object,
      default() {
        return {}
      },
    },
  },
  data: () => ({
    slideModel: 1,
  }),
  methods: {
    // stopExpandDetails(event) {
    //   if (event) {
    //     event.preventDefault()
    //   }
    // },
  },
  watch: {
    // carouselSlides: {
    //   deep: true,
    //   immediate: true,
    //   handler: function (newVal) {
    //     // needed to set initial image
    //     if (newVal[0]) {
    //       this.slideModel = newVal[0].src
    //     }
    //   },
    // },
  },
  computed: {
    priceInCents() {
      if (this.$route.name === "rForRentListing") {
        return this.currentListing.priceRentalMonthlyCurrentCents
      } else {
        return this.currentListing.priceSaleCurrentCents
      }
    },
    // carouselSlides() {},
    // summaryImageUrl() {
    //   return this.currentListing.preview_url
    // },
  },
  mounted: function () {},
}
</script>
<style></style>
