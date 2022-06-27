<template>
  <div>
    <div class="q-pa-md">
      <component
        :key="currentAgency.email_primary"
        :is="editTabComponent"
        @updatePendingChanges="updatePendingChanges"
        :cancelPendingChanges="cancelPendingChanges"
        :currentAgency="currentAgency"
      ></component>
      <div class="row">
        <div class="col-12">
          <GenericSubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentAgency"
            @changesCanceled="changesCanceled"
            @runModelUpdate="runModelUpdate"
          ></GenericSubmitter>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import useAgency from "~/v-admin-app/src/compose/useAgency.js"
import GenericSubmitter from "~/v-admin-app/src/components/editor-forms-parts/GenericSubmitter.vue"
import AgencyGeneralForm from "~/v-admin-app/src/components/editor-forms/AgencyGeneralForm.vue"
import AgencyLocationForm from "~/v-admin-app/src/components/editor-forms/AgencyLocationForm.vue"
export default {
  components: {
    AgencyLocationForm,
    AgencyGeneralForm,
    GenericSubmitter,
  },
  computed: {
    editTabComponent() {
      let editTabComponent = "AgencyGeneralForm"
      if (this.$route.name === "rAgencyEditLocation") {
        editTabComponent = "AgencyLocationForm"
      }
      return editTabComponent
    },
  },
  methods: {
    runModelUpdate(currPendingChanges) {
      this.updateAgency(currPendingChanges)
        .then((response) => {
          // location.reload()
          // this.currPendingChanges = {}
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
            error.response.data.errors[0].meta.exception
          ) {
            errorMessage = error.response.data.errors[0].meta.exception
          }
          this.$q.notify({
            color: "red-4",
            textColor: "white",
            icon: "error",
            message: errorMessage,
          })
        })
    },
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = fieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      // this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {
    currentAgency: {
      type: Object,
      default: () => {},
    },
  },
  mounted: function () {},
  setup(props) {
    const { updateAgency } = useAgency()
    return {
      updateAgency,
    }
  },
  data() {
    return {
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
      },
    }
  },
}
</script>
<style></style>
