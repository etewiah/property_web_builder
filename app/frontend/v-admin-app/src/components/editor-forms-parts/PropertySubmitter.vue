<template>
  <div
    v-if="hasPendingChanges"
    class="q-gutter-md spp-loc-submit-cont"
    xs12
    sm12
    offset-sm0
  >
    <q-btn @click="runPropertyUpdate" color="primary" type="submit">
      Save
    </q-btn>
    <q-btn @click="runCancelListingChanges">Cancel</q-btn>
  </div>
</template>
<script>
import useProperties from "~/v-admin-app/src/compose/useProperties.js"
export default {
  // inject: ["listingsEditProvider"],
  components: {},
  props: {
    currentModelForEditing: {
      type: Object,
      default() {
        return {}
      },
    },
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
        let fieldHasChanged = false
        let newValue = changedFieldDetails.newValue
        if (changedFieldDetails.fieldDbType === "int") {
          newValue = parseInt(changedFieldDetails.newValue)
          // fieldHasChanged = (parseInt(changedFieldDetails.newValue) !== state.currentModelForEditing[changedFieldDetails.fieldName])
        }
        var originalValue =
          this.currentModelForEditing[changedFieldDetails.fieldName]
        fieldHasChanged = newValue !== originalValue
        let changedFieldName = changedFieldDetails.fieldName
        // if (to.fieldClass === "aFeatureField") {
        //   changedFieldName = "features"
        //   // Features are handled differently - The page component
        //   // keeps track of all the changes together so I only need
        //   // to check if the featureChanges field has any values
        //   fieldHasChanged = Object.keys(to.featureChanges).length > 0
        // }
        if (fieldHasChanged) {
          this.currPendingChanges[changedFieldName] = newValue
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
  setup() {
    const { updateProperty } = useProperties()
    return { updateProperty }
  },
  methods: {
    runCancelListingChanges() {
      this.currPendingChanges = {}
      this.$emit("changesCanceled")
    },
    runPropertyUpdate() {
      this.updateProperty(this.currentModelForEditing, this.currPendingChanges)
        .then((response) => {
          // location.reload()
          this.currPendingChanges = {}
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Updated successfully",
          })
        })
        .catch((error) => {
          let errorMessage = error.message || "Sorry, unable to update"
          if (
            error.response.data.errors[0] &&
            error.response.data.errors[0].detail
          ) {
            errorMessage = error.response.data.errors[0].detail
          }
          this.$q.notify({
            color: "red-4",
            textColor: "white",
            icon: "error",
            message: errorMessage,
          })
        })
    },
  },
}
</script>
