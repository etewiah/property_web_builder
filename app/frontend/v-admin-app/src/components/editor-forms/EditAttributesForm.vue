<template>
  <div class="q-pa-md">
    <div class="row edit-attr-row">
      <div class="col-12 q-py-lg">
        <q-item
          style="max-height: 100px"
          class="q-mr-lg q-mb-sm border-gray-800 bg-gray-200 border-2 float-left"
        >
          <q-item-section side>
            <q-icon color="blue" name="bathtub" />
          </q-item-section>
          <q-item-section class="q-mr-sm">
            <q-item-label class="text-weight-medium text-h6"> </q-item-label>
            <TextField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="bathroomFieldDetails"
              :currentFieldValue="bathroomContentValue"
              v-on:updatePendingChanges="updatePendingChanges"
            ></TextField>
          </q-item-section>
        </q-item>
        <q-item
          class="q-mr-lg q-mb-sm border-gray-800 bg-gray-200 border-2 float-left"
        >
          <q-item-section side>
            <q-icon color="blue" name="hotel" />
          </q-item-section>
          <q-item-section class="q-mr-sm">
            <q-item-label class="text-weight-medium text-h6"> </q-item-label>
            <TextField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="bedroomsFieldDetails"
              :currentFieldValue="bedroomsContentValue"
              v-on:updatePendingChanges="updatePendingChanges"
            ></TextField>
          </q-item-section>
        </q-item>
        <q-item
          style="max-height: 100px"
          class="q-mr-lg q-mb-sm border-gray-800 bg-gray-200 border-2 float-left"
        >
          <q-item-section side>
            <q-icon color="blue" :name="mdiAspectRatio" />
          </q-item-section>
          <q-item-section class="q-mr-sm">
            <q-item-label class="text-weight-medium text-h6"> </q-item-label>
            <TextField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="areaFieldDetails"
              :currentFieldValue="areaContentValue"
              v-on:updatePendingChanges="updatePendingChanges"
            ></TextField>
          </q-item-section>
        </q-item>
        <q-item
          style="max-height: 100px"
          class="q-mr-lg q-mb-sm border-gray-800 bg-gray-200 border-2 float-left"
        >
          <q-item-section side>
            <q-icon color="blue" :name="mdiCashMultiple" />
          </q-item-section>
          <q-item-section class="q-mr-sm">
            <q-item-label class="text-weight-medium text-h6"> </q-item-label>
            <!-- <CurrencyField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="priceFieldDetails"
              :modelValue="priceContentValue"
              :currencyToUse="currentProperty.currency"
              v-on:updatePendingChanges="updatePendingChanges"
            ></CurrencyField> -->
          </q-item-section>
        </q-item>
      </div>
      <div class="col-12">
        <PropertySubmitter
          :cancelPendingChanges="cancelPendingChanges"
          :lastChangedField="lastChangedField"
          :currentModelForEditing="currentProperty"
          submitObjectType="realtyAssetPlusListing"
          @changesCanceled="changesCanceled"
        ></PropertySubmitter>
      </div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import PropertySubmitter from "~/v-admin-app/src/components/editor-forms-parts/PropertySubmitter.vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
// import CurrencyField from "src/components/editor-forms-parts/CurrencyField.vue"
import { mdiAspectRatio, mdiCashMultiple } from "@quasar/extras/mdi-v5"
export default defineComponent({
  created() {
    this.mdiAspectRatio = mdiAspectRatio
    this.mdiCashMultiple = mdiCashMultiple
  },
  // inject: ["listingsEditProvider"],
  name: "EditAttributesForm",
  components: {
    PropertySubmitter,
    TextField,
    // CurrencyField,
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
    // btnClass: {
    //   type: String,
    //   required: false,
    // },
  },
  computed: {
    areaContentValue() {
      let areaContentValue = this.currentProperty.attributes["constructed-area"]
      return areaContentValue
    },
    priceContentValue() {
      let priceContentValue =
        this.currentProperty.attributes["price-sale-current-cents"] || 0
      return priceContentValue / 100
    },
    bathroomContentValue() {
      let bathroomContentValue =
        this.currentProperty.attributes["count-bathrooms"]
      return bathroomContentValue
    },
    bedroomsContentValue() {
      let bedroomsContentValue =
        this.currentProperty.attributes["count-bedrooms"]
      return bedroomsContentValue
    },
  },
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = fieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  data() {
    return {
      areaFieldDetails: {
        labelEn: "Area",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "constructed_area",
        fieldType: "simpleInput",
        qInputType: "number",
        constraints: {
          inputValue: {},
        },
      },
      priceFieldDetails: {
        labelEn: "price",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "price_sale_current",
        fieldType: "simpleInput",
        qInputType: "number",
        constraints: {
          inputValue: {},
        },
      },
      bathroomFieldDetails: {
        labelEn: "Bathrooms",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "count-bathrooms",
        fieldType: "simpleInput",
        qInputType: "number",
        constraints: {
          inputValue: {},
        },
      },
      bedroomsFieldDetails: {
        labelEn: "Bedrooms",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "count-bedrooms",
        fieldType: "simpleInput",
        qInputType: "number",
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
<style>
.edit-attr-row .q-field__native {
  font-size: larger;
}
</style>
