<template>
  <div>
    <q-input
      v-if="textFieldType === 'number'"
      :autofocus="autofocus"
      :hide-bottom-space="true"
      class="regular-textfield-input"
      outlined
      v-on:keyup="fieldChangeHandler"
      v-model.number="localFieldValue"
      :label="fieldLabel"
      hint=""
      lazy-rules
      :type="textFieldType"
    />
    <q-input
      v-else
      :autofocus="autofocus"
      :hide-bottom-space="true"
      class="regular-textfield-input"
      outlined
      v-on:keyup="fieldChangeHandler"
      v-model="localFieldValue"
      :label="fieldLabel"
      hint=""
      lazy-rules
      :type="textFieldType"
      autogrow
    />
  </div>
</template>
<script>
export default {
  props: {
    fieldDetails: {},
    currentFieldValue: {},
    cancelPendingChanges: {},
    autofocus: {},
  },
  // props: ["fieldDetails", "currentFieldValue", "cancelPendingChanges"],
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
        debugger
        this.localFieldValue = this.originalValue
      }
    },
    "fieldDetails.newValFromMap"(newValue, oldValue) {
      if (newValue && newValue.length > 0) {
        // This triggers when map marker is dragged and dropped
        this.localFieldValue = newValue
        // this.fieldDetails.newValue = newValue
        this.$emit("updatePendingChanges", this.fieldDetails)
      }
    },
    currentFieldValue: {
      handler(newValue, oldVal) {
        // This is effectively an initializer
        // that will not change as a result of typing
        // Will retrigger though when an update is pushed
        // to the server
        if (newValue) {
          if (this.fieldDetails.fieldType === "localesHash") {
            newValue = newValue[this.fieldDetails.activeLocale]
          }
          if (this.fieldDetails.inputType === "moneyField") {
            newValue = newValue / 100
          }
        }
        this.localFieldValue = newValue
        this.originalValue = newValue
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
    textFieldType() {
      return this.fieldDetails.qInputType || "text"
      // Acceptable values for qInputType:
      // text password textarea email search tel file number url time date
    },
  },
  methods: {
    fieldChangeHandler(event) {
      let newValue = event.currentTarget.value
      if (this.fieldDetails.inputType === "moneyField") {
        newValue = newValue * 100
      }
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: newValue,
      })
    },
  },
}
</script>
