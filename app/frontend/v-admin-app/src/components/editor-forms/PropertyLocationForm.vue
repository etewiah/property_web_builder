<template>
  <div>
    <q-card class="prop-loc-edit-card">
      <q-card-section>
        <div>
          <div class="text-subtitle1 form-label-head"></div>

          <GMapAutocomplete
            autofocus="true"
            placeholder="Type here to find a new address"
            @place_changed="setPlace"
            :options="autoCompleteOptions"
            class="gmap-ac-input"
            style="margin-bottom: 40px"
            @focus="onFocus()"
            @blur="onBlur()"
          />
          <div class="row q-col-gutter-sm">
            <div class="col-xs-12 col-sm-12 col-md-6">
              <div v-for="fieldDetails in locationFields.mainInputFields1">
                <LocationTextField
                  :key="fieldDetails.fieldName"
                  v-on:updatePendingChanges="updatePendingChanges"
                  :fieldDetails="fieldDetails"
                  :fieldOptions="{}"
                  :cancelPendingChanges="cancelPendingChanges"
                  v-bind:locationResourceModel="currentPropertyAttributes"
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
                  v-bind:locationResourceModel="currentPropertyAttributes"
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
                  v-bind:locationResourceModel="currentPropertyAttributes"
                ></LocationTextField>
              </div>
            </div>
          </div>
        </div>
        <div>
          <PropertySubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentProperty"
            @changesCanceled="changesCanceled"
          ></PropertySubmitter>
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import lodashEach from "lodash/each"
import PropertySubmitter from "~/v-admin-app/src/components/editor-forms-parts/PropertySubmitter.vue"
import LocationTextField from "~/v-admin-app/src/components/editor-forms-parts//LocationTextField.vue"
export default defineComponent({
  name: "PropertyLocationForm",
  components: {
    PropertySubmitter,
    LocationTextField,
  },
  watch: {},
  props: {
    currentProperty: {
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
    currentPropertyAttributes() {
      return this.currentProperty.attributes || {}
    },
  },
  methods: {
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
      let lastChangedField = this.lastChangedField
      // addressData is less detailed than placeResultData
      let newAddressDetails = this.getAddressFromGoogleResult(placeResultData)
      // this.$emit("updatePropAddress", newAddressDetails)
      this.locationFields.mainInputFields1.forEach(function (fieldDetails) {
        fieldDetails.newValFromMap = newAddressDetails[fieldDetails.fieldName]
        fieldDetails.newValue = newAddressDetails[fieldDetails.fieldName]
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
        }, 10)
      })
    },
    getAddressFromGoogleResult(googleAddress) {
      let newAddressFromMap = {}
      // genius json-api for rails insists on street-address instead of street_address
      newAddressFromMap["street-address"] = googleAddress.formatted_address
      // this.agencyAddress.google_place_id = googleAddress.place_id
      // this.agencyAddress.latitude = googleAddress.geometry.location.lat()
      // this.agencyAddress.longitude = googleAddress.geometry.location.lng()
      newAddressFromMap.google_place_id = googleAddress.place_id
      newAddressFromMap.latitude = googleAddress.geometry.location.lat()
      newAddressFromMap.longitude = googleAddress.geometry.location.lng()
      lodashEach(
        googleAddress.address_components,
        function (address_component, i) {
          // iterate through address_component array
          console.log("address_component:" + i)
          console.log(newAddressFromMap)
          if (address_component.types[0] === "route") {
            // console.log(i + ": route:" + address_component.long_name)
            newAddressFromMap.street_name = address_component.long_name
          }
          if (address_component.types[0] === "locality") {
            // console.log("town:" + address_component.long_name)
            newAddressFromMap.city = address_component.long_name
          }
          if (address_component.types[0] === "country") {
            // console.log("country:" + address_component.long_name)
            newAddressFromMap.country = address_component.long_name
          }
          if (address_component.types[0] === "postal_code_prefix") {
            // console.log("pc:" + address_component.long_name)
            // newAddress.postalCode = address_component.long_name
          }
          if (address_component.types[0] === "postal_code") {
            // console.log("pc:" + address_component.long_name)
            newAddressFromMap["postal-code"] = address_component.long_name
          }
          if (address_component.types[0] === "street_number") {
            // console.log("street_number:" + address_component.long_name)
            newAddressFromMap["street-number"] = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_1") {
            // eg: andalucia
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.province = address_component.long_name
            newAddressFromMap.region = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_2") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal2 = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_3") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal3 = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_4") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal4 = address_component.long_name
          }
          //return false // break the loop
        }
      )
      return newAddressFromMap
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
            fieldName: "street-address",
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
            fieldName: "postal-code",
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
            fieldName: "street-number",
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
      cityFieldDetails: {
        labelEn: "City",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "city",
        fieldType: "simpleInput",
        inputType: "text",
        constraints: {
          inputValue: {},
        },
      },
      countryFieldDetails: {
        labelEn: "Country",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "country",
        fieldType: "simpleInput",
        inputType: "text",
        constraints: {
          inputValue: {},
        },
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
