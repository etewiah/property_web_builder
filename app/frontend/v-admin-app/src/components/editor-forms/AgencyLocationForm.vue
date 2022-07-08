<template>
  <div>
    <q-card class="prop-loc-edit-card">
      <q-card-section>
        <div class="row">
          <div class="col-12">
            <MapAddressField
              @setFieldsFromAddressDetails="setFieldsFromAddressDetails"
              :singleLatLngDetails="currentAgencyAddress"
            >
            </MapAddressField>
          </div>
          <div class="col-12 q-pt-md">
            <GMapAutocomplete
              autofocus="true"
              placeholder="You can type here to find a new address"
              @place_changed="setPlace"
              :options="autoCompleteOptions"
              class="gmap-ac-input"
              style="margin-bottom: 40px"
              @focus="onFocus()"
              @blur="onBlur()"
            />
          </div>
          <div class="col-12">
            <div class="row q-col-gutter-sm">
              <div class="col-xs-12 col-sm-12 col-md-6">
                <div v-for="fieldDetails in locationFields.mainInputFields1">
                  <LocationTextField
                    :key="fieldDetails.fieldName"
                    v-on:updatePendingChanges="updatePendingChanges"
                    :fieldDetails="fieldDetails"
                    :fieldOptions="{}"
                    :cancelPendingChanges="cancelPendingChanges"
                    v-bind:locationResourceModel="currentAgencyAddress"
                  ></LocationTextField>
                </div>
              </div>
              <div class="col-xs-12 col-sm-12 col-md-6">
                <div v-for="fieldDetails in locationFields.mainInputFields2">
                  <LocationTextField
                    :key="fieldDetails.fieldName"
                    v-on:updatePendingChanges="updatePendingChanges"
                    :fieldDetails="fieldDetails"
                    :fieldOptions="{}"
                    :cancelPendingChanges="cancelPendingChanges"
                    v-bind:locationResourceModel="currentAgencyAddress"
                  ></LocationTextField>
                </div>
              </div>
              <div class="col-xs-12 col-sm-12 col-md-6">
                <div v-for="fieldDetails in locationFields.mainInputFields3">
                  <LocationTextField
                    :key="fieldDetails.fieldName"
                    v-on:updatePendingChanges="updatePendingChanges"
                    :fieldDetails="fieldDetails"
                    :fieldOptions="{}"
                    :cancelPendingChanges="cancelPendingChanges"
                    v-bind:locationResourceModel="currentAgencyAddress"
                  ></LocationTextField>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div>
          <GenericSubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentAgency"
            @changesCanceled="changesCanceled"
            @runModelUpdate="runModelUpdate"
          ></GenericSubmitter>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
// import lodashEach from "lodash/each"
import useGoogleMaps from "~/v-admin-app/src/compose/useGoogleMaps.js"
import useAgency from "~/v-admin-app/src/compose/useAgency.js"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
import LocationTextField from "~/v-admin-app/src/components/editor-forms-parts//LocationTextField.vue"
import MapAddressField from "~/v-admin-app/src/components/editor-forms-parts/MapAddressField.vue"
export default defineComponent({
  name: "AgencyLocationForm",
  components: {
    GenericSubmitter,
    LocationTextField,
    MapAddressField,
  },
  setup(props) {
    const { updateAgencyAddress } = useAgency()
    const { getAddressFromPlaceDetails } = useGoogleMaps()
    return {
      updateAgencyAddress,
      getAddressFromPlaceDetails,
    }
  },
  props: {
    currentAgency: {
      type: Object,
      default: () => {},
    },
  },
  computed: {
    autoCompleteOptions() {
      return {}
      // could be something like:
      // return {
      //   bounds: { north: 1.4, south: 1.2, east: 104, west: 102 },
      //   strictBounds: true,
      // }
    },
    currentAgencyAddress() {
      return this.currentAgency.primaryAddress || {}
    },
  },
  methods: {
    runModelUpdate(currPendingChanges) {
      this.updateAgencyAddress(currPendingChanges)
        .then((response) => {
          // location.reload()
          // this.currPendingChanges = {}
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Updated successfully",
          })
        })
        .catch((error) => {
          let errorMessage = error.message || "Sorry, unable to update"
          if (
            error.response.data.errors[0] &&
            error.response.data.errors[0].meta.exception
          ) {
            errorMessage = error.response.data.errors[0].meta.exception
          }
          this.$q.notify({
            color: "red-4",
            textColor: "white",
            icon: "error",
            message: errorMessage,
          })
        })
    },
    /**
     * When the input got changed
     */
    onChange() {
      // document.querySelector(".pac-container").style["display"] = "block"
      // document.querySelector(".pac-container").style["position"] =
      //   "fixed !important"
      document
        .querySelector(".pac-container")
        .setAttribute(
          "style",
          "display: block !important;position: fixed !important; z-index: 10000 !important;"
        )
      // this.$emit("change", this.autocompleteText)
    },

    /**
     * When a key gets pressed
     * @param  {Event} event A keypress event
     */
    onKeyPress(event) {
      document
        .querySelector(".pac-container")
        .setAttribute(
          "style",
          "display: block !important;position: fixed !important; z-index: 10000 !important;"
        )

      setTimeout(() => {
        document
          .querySelector(".pac-container")
          .setAttribute(
            "style",
            "display: block !important;position: fixed !important; z-index: 10000 !important;"
          )
      }, 1500)
      this.$emit("keypress", event)
    },

    /**
     * When a keyup occurs
     * @param  {Event} event A keyup event
     */
    onKeyUp(event) {
      document
        .querySelector(".pac-container")
        .setAttribute(
          "style",
          "display: block !important;position: fixed !important; z-index: 10000 !important;"
        )

      this.$emit("keyup", event)
    },
    /**
     * When the input gets focus
     */
    onFocus() {
      // document.querySelector(".pac-container").style["display"] = "block"
      // document.querySelector(".pac-container").style["position"] =
      //   "fixed !important"
      let pacContainer = document.querySelector(".pac-container")

      if (pacContainer) {
        pacContainer.setAttribute(
          "style",
          "display: block !important;position: fixed !important; z-index: 10000 !important;"
        )
      }
      // this.biasAutocompleteLocation()
      this.$emit("focus")
    },

    /**
     * When the input loses focus
     */
    onBlur() {
      document.querySelector(".pac-container").style["display"] = "none"
      // document.querySelector(".pac-container").style["position"] =
      //   "absolute !important"
      this.$emit("blur")
    },
    setPlace(placeResultData) {
      let newAddressDetails = this.getAddressFromPlaceDetails(placeResultData)
      // let newAddressDetails = this.getAddressFromGoogleResult(placeResultData)
      this.setFieldsFromAddressDetails(newAddressDetails)
    },
    setFieldsFromAddressDetails(newAddressDetails) {
      let lastChangedField = this.lastChangedField
      this.locationFields.mainInputFields1.forEach(function (fieldDetails) {
        fieldDetails.newValFromMap = newAddressDetails[fieldDetails.fieldName]
        fieldDetails.newValue = newAddressDetails[fieldDetails.fieldName]
        // below needed to ensure that observer in submitter container triggers for each field
        setTimeout(function () {
          lastChangedField.fieldDetails = fieldDetails
          lastChangedField.lastUpdateStamp = Date.now()
        }, 0)
      })
      this.locationFields.mainInputFields2.forEach(function (fieldDetails) {
        fieldDetails.newValFromMap = newAddressDetails[fieldDetails.fieldName]
        fieldDetails.newValue = newAddressDetails[fieldDetails.fieldName]
        setTimeout(function () {
          lastChangedField.fieldDetails = fieldDetails
          lastChangedField.lastUpdateStamp = Date.now()
        }, 0)
      })
      this.locationFields.mainInputFields3.forEach(function (fieldDetails) {
        fieldDetails.newValFromMap = newAddressDetails[fieldDetails.fieldName]
        fieldDetails.newValue = newAddressDetails[fieldDetails.fieldName]
        setTimeout(function () {
          lastChangedField.fieldDetails = fieldDetails
          lastChangedField.lastUpdateStamp = Date.now()
        }, 0)
      })
    },
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = fieldDetails
      this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.cancelPendingChanges = true
    },
  },
  data() {
    return {
      locationFields: {
        // from
        mainInputFields1: [
          {
            labelEn: "Street Address",
            labelTextTKey: "client_admin.fieldLabels.streetAddress",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "street_address",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
          {
            labelEn: "City",
            labelTextTKey: "client_admin.fieldLabels.city",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "city",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
          {
            labelEn: "Postal Code",
            labelTextTKey: "client_admin.fieldLabels.postalCode",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "postal_code",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
        ],
        mainInputFields2: [
          {
            labelEn: "Street Number",
            labelTextTKey: "client_admin.fieldLabels.streetNumber",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "street_number",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
          {
            labelEn: "Region",
            labelTextTKey: "client_admin.fieldLabels.region",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "region",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
          {
            labelEn: "Country",
            labelTextTKey: "client_admin.fieldLabels.country",
            // "tooltipTextTKey": "toolTips.ref",
            newValFromMap: "",
            fieldName: "country",
            fieldType: "simpleInput",
            inputType: "text",
            constraints: {
              inputValue: {},
            },
          },
        ],
        mainInputFields3: [
          {
            labelEn: "Latitude",
            newValFromMap: "",
            fieldName: "latitude",
            fieldType: "simpleInput",
            inputType: "text",
          },
          {
            labelEn: "Longitude",
            newValFromMap: "",
            fieldName: "longitude",
            fieldType: "simpleInput",
            inputType: "text",
          },
        ],
      },
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        lastUpdateStamp: "",
      },
    }
  },
})
</script>
<style scoped>
.pac-container {
  position: fixed !important;
  z-index: 10000 !important;
  display: block !important;
  /* width: auto !important;
  position: initial !important;
  left: 0 !important;
  right: 0 !important;
   */
}
.pac-target-input {
  min-height: 26px;
  padding-top: 1px;
  padding: 5px;
  font-size: large;
  min-width: 500px;
  border-radius: 6px;
  margin-bottom: 15px;
}

/* https://stackoverflow.com/questions/7893857/how-do-you-style-the-dropdown-on-google-places-autocomplete-api 
*/
</style>
