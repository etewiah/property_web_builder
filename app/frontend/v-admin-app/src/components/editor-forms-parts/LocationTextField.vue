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
      type="textarea"
      autogrow
    />
  </div>
</template>
<script>
export default {
  props: {
    locationResourceModel: {
      type: Object,
      default: () => {},
    },
    fieldDetails: {
      type: Object,
    },
    cancelPendingChanges: {
      type: Boolean,
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
    "fieldDetails.newValFromMap"(newValue, oldValue) {
      // toString below for fields like latitude that might not be a string
      if (newValue && newValue.toString().length > 0) {
        // This triggers when map marker is dragged and dropped
        // or autocomplete changes
        this.localFieldValue = newValue.toString()
      }
    },
    fieldDetails: {
      handler(newValue, oldVal) {
        if (newValue) {
          this.localFieldValue =
            this.locationResourceModel[this.fieldDetails.fieldName]
          this.originalValue =
            this.locationResourceModel[this.fieldDetails.fieldName]
        }
      },
      // deep: true,
      immediate: true,
    },
  },
  computed: {
    fieldLabel() {
      return this.fieldDetails.labelEn
    },
    // not going to use mask prop for textfield
    // cos it conflicts with an input type of number
  },
  methods: {
    fieldChangeHandler(event) {
      let newValue = event.currentTarget.value
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: newValue,
      })
    },
  },
}
</script>
