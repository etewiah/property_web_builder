<template>
  <div>
    <div class="text-center text-subtitle1 trl-input-item-head">{{ translationUnit.sortKey }}</div>
    <div>
      <div
        v-for="translationInstance in translationInstances"
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
import sortBy from "lodash/sortBy"
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
  computed: {
    translationInstances() {
      // debugger
      return sortBy(this.translationUnit.translationsForKey, "locale")
    },
  },
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
      // TODO - catch and handle errors from above
      this.$q.notify({
        color: "green-4",
        textColor: "white",
        icon: "cloud_done",
        message: "Updated successfully",
      })
    },
  },
}
</script>
