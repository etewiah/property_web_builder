<template>
  <div>
    <q-toggle
      :label="fieldDetails.visible ? 'Visible' : 'Hidden'"
      v-model="fieldDetails.visible"
      color="green"
      @update:model-value="updatePendingChanges"
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
    // navGroup: {},
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
  },
  computed: {},
  methods: {
    updatePendingChanges(newValue) {
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: newValue,
        // navGroup: "top_nav_links",
      })
    },
  },
}
</script>
