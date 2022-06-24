<template>
  <div>
    <!-- <q-input
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
    /> -->
    <q-editor
      :autofocus="autofocus"
      :hide-bottom-space="true"
      class="regular-textfield-input"
      outlined
      v-on:keyup="fieldChangeHandler"
      v-model="localFieldValue"
      :label="fieldLabel"
      hint=""
      lazy-rules
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
    currentFieldValue: {
      handler(newValue, oldVal) {
        // This is effectively an initializer
        // that will not change as a result of typing
        // Will retrigger though when an update is pushed
        // to the server
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
    // textFieldType() {
    //   return this.fieldDetails.qInputType || "text"
    //   // Acceptable values for qInputType:
    //   // text password textarea email search tel file number url time date
    // },
  },
  methods: {
    fieldChangeHandler(event) {
      let newValue = event.currentTarget.innerHTML
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: newValue,
      })
    },
  },
}
</script>
