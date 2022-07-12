<template>
  <div>
    <div
      class="map-regular-section"
      v-if="listingMapMarkers.length > 0"
      style="height: 900px"
    >
      <!-- <EditMapForm :currentPropForEditing="currentListingData"></EditMapForm> -->
      <!-- <EditLocFromAutoCompleteForm :locationResourceModel="currentListingData"></EditLocFromAutoCompleteForm> -->
      <!-- <GMapAutocomplete
      placeholder="This is a placeholder"
      @place_changed="setPlace"
      :options="{
        bounds: { north: 1.4, south: 1.2, east: 104, west: 102 },
        strictBounds: true,
      }"
    /> -->
      <q-no-ssr>
        <GMapMap
          :center="mapCenter"
          :zoom="15"
          map-type-id="roadmap"
          style="height: 900px"
          ref="myMapRef"
          :click="true"
          @click="handleMapClick"
        >
          <GMapMarker
            :icon="listingMarkerIcon"
            :key="index"
            v-for="(m, index) in listingMapMarkers"
            :position="m.position"
            :clickable="true"
            :draggable="isMapDraggable"
            @click="openMarker(m.id)"
          >
            <GMapInfoWindow
              :closeclick="true"
              @closeclick="closeMarker(m.id)"
              :opened="openedMarkerIds[m.id] === 1"
            >
              <div>{{ m.infoWindowText }}</div>
            </GMapInfoWindow>
          </GMapMarker>
        </GMapMap>
      </q-no-ssr>
    </div>
  </div>
</template>
<script>
import { ref, onMounted } from "vue"
//import {setupContainsLatLng} from '../util/is-point-within-polygon.js'
import useGoogleMaps from "~/v-admin-app/src/compose/useGoogleMaps.js"
export default {
  setup(props) {
    const { getAddressFromPlaceDetails } = useGoogleMaps()
    // const myMapRef = ref()
    // const mapPolygon = ref()
    onMounted(() => {
      // myMapRef.value.$mapPromise.then(() => {
      //   // setupContainsLatLng()
      // })
    })
    return {
      getAddressFromPlaceDetails,
    }
  },
  props: {
    singleLatLngDetails: {
      type: Object,
      default: () => {},
    },
  },
  data() {
    return {
      openedMarkerIds: {},
      listingMarkerIcon: {
        url: "http://maps.google.com/mapfiles/ms/icons/purple-dot.png",
        scaledSize: { width: 40, height: 40 },
        labelOrigin: { x: 0, y: 0 },
      },
    }
  },
  watch: {},
  computed: {
    isMapDraggable() {
      return true
    },
    mapCenter() {
      let mapCenter = { lat: 0, lng: 9 }
      if (this.listingMapMarkers[0] && this.listingMapMarkers[0].position) {
        mapCenter = this.listingMapMarkers[0].position
      }
      return mapCenter
    },
    listingMapMarkers() {
      let listingMapMarkers = []
      if (
        this.singleLatLngDetails.latitude &&
        this.singleLatLngDetails.longitude
      ) {
        let infoWindowText =
          this.singleLatLngDetails.street_address ||
          this.singleLatLngDetails["street-address"]
        listingMapMarkers.push({
          id: this.singleLatLngDetails.id,
          position: {
            lat: parseFloat(this.singleLatLngDetails.latitude),
            lng: parseFloat(this.singleLatLngDetails.longitude),
          },
          infoWindowText: infoWindowText,
        })
        // below ensures that info window for each marker is opened
        // this.openedMarkerIds[this.singleLatLngDetails.listing_uuid] = 1
      }
      return listingMapMarkers
    },
  },
  methods: {
    handleMapClick(gLocation) {
      let newAddressDetails = {}
      if (gLocation.latLng?.lat) {
        var geocoder = new google.maps.Geocoder()
        var that = this
        let gPlace = {}
        geocoder.geocode(
          {
            latLng: gLocation.latLng,
          },
          function (results, status) {
            let errorMessage = false
            if (status === google.maps.GeocoderStatus.OK) {
              if (results[0]) {
                gPlace = results[0]
                newAddressDetails = that.getAddressFromPlaceDetails(gPlace)

                that.$emit("setFieldsFromAddressDetails", newAddressDetails)
              } else {
                errorMessage = "No results found"
              }
            } else {
              errorMessage = "Geocoder failed due to: " + status
            }
            if (errorMessage) {
              this.$q.notify({
                color: "red-4",
                textColor: "white",
                icon: "error",
                message: errorMessage,
              })
            }
          }
        )
        // newAddressDetails = this.getAddressFromPlaceDetails(gPlace)
        // mapPolygon.value.$polygonPromise.then((res) => {
        //   let isWithinPolygon = res.containsLatLng(
        //     gLocation.latLng.lat(),
        //     gLocation.latLng.lng()
        //   )
        //   console.log({ isWithinPolygon })
        // })
      }
    },

    closeMarker(id) {
      this.openedMarkerIds[id] = 0
    },
    openMarker(id) {
      this.openedMarkerIds[id] = 1
    },
  },
}
</script>
