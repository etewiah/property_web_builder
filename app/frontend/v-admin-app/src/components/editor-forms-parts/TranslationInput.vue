<template>
  <div>
    <div>{{ translationUnit.sortKey }}</div>
    <div>
      <div
        v-for="translationInstance in translationUnit.translationsForKey"
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
    <div class="row">
      <div class="col-12">
        <TranslationSubmitter
          :cancelPendingChanges="cancelPendingChanges"
          :lastChangedField="lastChangedField"
          @changesCanceled="changesCanceled"
          @runModelUpdate="runModelUpdate"
        ></TranslationSubmitter>
      </div>
    </div>
  </div>
</template>
<script>
import useTranslations from "~/v-admin-app/src/compose/useTranslations.js"
import TranslationSubmitter from "~/v-admin-app/src/components/editor-forms-parts/TranslationSubmitter.vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
export default {
  components: {
    TranslationSubmitter,
    TextField,
  },
  props: {
    translationUnit: {},
  },
  data() {
    return {
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        // lastUpdateStamp: "",
      },
    }
  },
  computed: {},
  setup(props) {
    const { updateTranslations } = useTranslations()
    return {
      updateTranslations,
    }
  },
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      fieldDetails.batch_key = "extras"
      this.lastChangedField.fieldDetails = fieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
    runModelUpdate(currPendingChanges) {
      this.updateTranslations(currPendingChanges)
      this.$q
        .notify({
          color: "green-4",
          textColor: "white",
          icon: "cloud_done",
          message: "Updated successfully",
        })

        // .then((response) => {
        //   this.$q.notify({
        //     color: "green-4",
        //     textColor: "white",
        //     icon: "cloud_done",
        //     message: "Updated successfully",
        //   })
        // })
        // .catch((error) => {
        //   let errorMessage = error.message || "Sorry, unable to update"
        //   if (
        //     error.response.data.errors[0] &&
        //     error.response.data.errors[0].meta.exception
        //   ) {
        //     errorMessage = error.response.data.errors[0].meta.exception
        //   }
        //   this.$q.notify({
        //     color: "red-4",
        //     textColor: "white",
        //     icon: "error",
        //     message: errorMessage,
        //   })
        // })
    },
  },
}
</script>
