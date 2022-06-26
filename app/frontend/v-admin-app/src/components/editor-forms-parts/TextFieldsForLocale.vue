<template>
  <div>
    <TextField
      :cancelPendingChanges="cancelPendingChanges"
      :fieldDetails="fieldDetails"
      :currentFieldValue="currentFieldValue"
      v-on:updatePendingChanges="updatePendingChanges"
    ></TextField>
  </div>
</template>
<script>
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
export default {
  components: {
    TextField,
  },
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
  computed: {},
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      this.$emit("updatePendingChanges", {
        fieldDetails: fieldDetails,
        newValue: newValue,
      })
    },
  },
}
</script>
