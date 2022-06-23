<template>
  <div>
    <div>{{ fieldDetails.sortKey }}</div>
    <div>
      <div
        v-for="translationInstance in fieldDetails.translationsForKey"
        :key="translationInstance.key"
      >
        <div v-if="['es', 'en'].includes(translationInstance.locale)">
          {{ translationInstance.locale }} :
          <TextField
            :cancelPendingChanges="cancelPendingChanges"
            :fieldDetails="translationInstance"
            :currentFieldValue="translationInstance.i18n_value"
            v-on:updatePendingChanges="updatePendingChanges"
          ></TextField>
        </div>
      </div>
    </div>
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
      // localFieldValue: "",
      // originalValue: "",
    }
  },
  // watch: {
  //   cancelPendingChanges(newValue, oldValue) {
  //     if (oldValue === false) {
  //       this.localFieldValue = this.originalValue
  //     }
  //   },
  // },
  computed: {},
  methods: {
    updatePendingChanges(newValue) {
      this.$emit("updatePendingChanges", {
        fieldDetails: this.fieldDetails,
        newValue: newValue,
      })
    },
  },
}
</script>
