<template>
  <div
    v-if="hasPendingChanges"
    class="q-gutter-md spp-loc-submit-cont"
    xs12
    sm12
    offset-sm0
  >
    <q-btn @click="runModelUpdate" color="primary" type="submit"> Save </q-btn>
    <q-btn @click="runCancelPendingChanges">Cancel</q-btn>
  </div>
</template>
<script>
export default {
  components: {},
  props: {
    lastChangedField: {
      type: Object,
      default() {
        return {}
      },
    },
    cancelPendingChanges: {
      type: Boolean,
      default: false,
    },
  },
  watch: {
    lastChangedField: {
      handler(to, from) {
        let changedFieldDetails = to.fieldDetails
        // For translations I will save a pending change per locale:
        let changedFieldName = changedFieldDetails.locale
        let fieldHasChanged = false
        let newValue = changedFieldDetails.newValue
        var originalValue = changedFieldDetails.i18n_value
        // this.currentModelForEditing[changedFieldName]
        fieldHasChanged = newValue !== originalValue
        if (fieldHasChanged) {
          this.currPendingChanges[changedFieldName] = changedFieldDetails
        } else {
          delete this.currPendingChanges[changedFieldName]
        }
      },
      deep: true,
      immediate: false,
    },
  },
  data() {
    return {
      currPendingChanges: {},
    }
  },
  computed: {
    hasPendingChanges() {
      return Object.keys(this.currPendingChanges).length > 0
    },
  },
  setup() {},
  methods: {
    runCancelPendingChanges() {
      this.currPendingChanges = {}
      this.$emit("changesCanceled")
    },
    runModelUpdate() {
      this.$emit("runModelUpdate", this.currPendingChanges)
      this.currPendingChanges = {}
    },
  },
}
</script>
