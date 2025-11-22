<template>
  <div class>
    <div class="text-xs-left"></div>
    <q-select
      color="gray"
      bg-color="white"
      :options="selectItems"
      v-model="localFieldValue"
      :label="localiseProvider.$ft(fieldDetails.labelTextTKey)"
      @update:model-value="fieldChangeHandler"
      option-label="name"
      option-value="value"
      outlined
    ></q-select>
  </div>
</template>
<script>
// import _ from "lodash"
export default {
  inject: ["localiseProvider"],
  props: ["fieldDetails", "currentFieldValue", "fieldOptions"],
  data() {
    return {
      localFieldValue: "",
    }
  },
  watch: {
    currentFieldValue: {
      handler(newValue, oldVal) {
        if (newValue) {
          // Normalize currency values by stripping commas
          // This allows matching with selectItems which have values without commas
          if (this.isCurrencyField && typeof newValue === 'string') {
            this.localFieldValue = newValue.replace(/,/g, '')
          } else {
            this.localFieldValue = newValue
          }
        } else {
          this.localFieldValue = this.fieldDetails.defaultValue
        }
        // if (["city", "maxPrice"].includes(this.fieldDetails.fieldName)) {
        //   this.localFieldValue = newValue
        // } else {
        //   this.localFieldValue = this.fieldDetails.optionsKey + "." + newValue
        // }
      },
      // deep: true,
      immediate: true,
    },
  },
  computed: {
    isCurrencyField() {
      return [
        "forRentPriceFrom",
        "forRentPriceTill",
        "forSalePriceFrom",
        "forSalePriceTill",
      ].includes(this.fieldDetails.fieldName)
    },
    selectItems() {
      let rawVals = []
      let optionsType = "simple_list"
      if (this.fieldDetails.optionsValues) {
        rawVals = this.fieldDetails.optionsValues
        // } else {
        //   optionsType = "object_list"
        //   rawVals = this.fieldOptions[this.fieldDetails.optionsKey] || []
      }
      let selectItems = [{ name: "", value: "" }]
      // let i18n = this.$i18n
      // let fieldName = this.fieldDetails.fieldName
      
      // Check if we have separate labels (e.g., for property types)
      const hasLabels = this.fieldDetails.optionsLabels && this.fieldDetails.optionsLabels.length > 0
      
      rawVals.forEach((optionKey, index) => {
        let name = optionKey
        let val = optionKey
        if (this.isCurrencyField) {
          // name = $n(optionKey, "currency", "EUR")
          // don't think I have $i18n setup for above
          name = "€" + optionKey
          // below removes comma
          val = optionKey.replace(/,/g, "")
        } else if (hasLabels) {
          // For fields with separate labels (like property types)
          const labelObj = this.fieldDetails.optionsLabels.find(l => l.value === optionKey)
          if (labelObj) {
            name = labelObj.label
            val = labelObj.value
          }
        } else {
          if (optionsType === "object_list") {
            // name = _.startCase(optionKey.label)
            val = optionKey.global_key
          }
        }
        selectItems.push({
          name: name,
          value: val,
        })
      })
      return selectItems
      // if (isCurrency) {
      //   return selectItems
      // } else {
      //   return _.sortBy(selectItems, "name")
      // }
    },
  },
  methods: {
    fieldChangeHandler(selectItem) {
      this.fieldDetails.newValue = selectItem.value
      this.$emit("selectChanged", this.fieldDetails)
    },
  },
}
</script>
