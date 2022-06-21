<template>
  <div>
    <q-input
      :hide-bottom-space="true"
      class="regular-textfield-input"
      outlined
      v-on:keyup="fieldChangeHandler"
      v-model="localFieldValue"
      :label="fieldLabel"
      hint=""
      lazy-rules
      ref="inputRef"
    />
  </div>
</template>
<script>
// import { watch } from "vue"
import { useCurrencyInput, parse } from "vue-currency-input"
export default {
  setup(props) {
    let currencyOptions = {
      currency: props.currencyToUse,
      currencyDisplay: "symbol",
      hideCurrencySymbolOnFocus: false,
      hideGroupingSeparatorOnFocus: false,
      hideNegligibleDecimalDigitsOnFocus: true,
      autoDecimalDigits: false,
      autoSign: false,
      useGrouping: true,
      accountingSign: false,
    }
    // currencyOptions.currency = props.currencyToUse
    // const { inputRef } = useCurrencyInput(    props.options)
    const { inputRef, formattedValue, setOptions, setValue } =
      useCurrencyInput(currencyOptions)

    return { inputRef, formattedValue, parse, currencyOptions }
  },
  props: {
    modelValue: {
      type: Number,
      default: null,
    },
    currencyToUse: {
      type: String,
      default: "GBP",
    },
    cancelPendingChanges: {
      type: Boolean,
      default: false,
    },
    fieldDetails: {
      type: Object,
      default: () => {},
    },
  },
  data() {
    return {
      localFieldValue: "",
      originalValue: "",
    }
  },
  watch: {
    cancelPendingChanges(newValue, oldValue) {
      if (oldValue === false) {
        // when cancelPendingChanges on parent changes from
        // false to true
        // reset model to its original value
        this.localFieldValue = this.originalValue
      }
    },
    modelValue: {
      handler(newValue, oldVal) {
        // This is effectively an initializer
        // that will not change as a result of typing
        // Will retrigger though when an update is pushed
        // to the server
        this.localFieldValue = newValue.toString()
        this.originalValue = newValue.toString()
      },
      // deep: true,
      immediate: true,
    },
  },
  computed: {
    fieldLabel() {
      if (this.fieldDetails.labelEn) {
        return this.fieldDetails.labelEn
      } else {
        return ""
      }
    },
    // not going to use mask prop for textfield
    // cos it conflicts with an input type of number
    // mask() {
    //   return "#"
    // },
  },
  methods: {
    fieldChangeHandler(event) {
      let newValue = this.parse(event.currentTarget.value, this.currencyOptions)
      let currencyValueInCents = newValue * 100
      //  event.currentTarget.value
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: currencyValueInCents,
      })
    },
  },
}
</script>
