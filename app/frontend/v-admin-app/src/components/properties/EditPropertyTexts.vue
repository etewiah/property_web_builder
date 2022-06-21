<template>
  <div>
    <div class="q-pa-md">
      <div>Texts</div>
      <div class="row">
        <div class="col-6">
          <EditLocaleTextsSubForm
            :cancelPendingChanges="cancelPendingChanges"
            :currentProperty="currentProperty"
            contentLocale="en"
            v-on:updatePendingChanges="updatePendingChanges"
          ></EditLocaleTextsSubForm>
        </div>
        <div class="col-6">
          <EditLocaleTextsSubForm
            :cancelPendingChanges="cancelPendingChanges"
            :currentProperty="currentProperty"
            contentLocale="es"
            v-on:updatePendingChanges="updatePendingChanges"
          ></EditLocaleTextsSubForm>
        </div>
        <div class="col-12">
          <PropertySubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="currentProperty"
            submitObjectType="realtyAssetPlusListing"
            @changesCanceled="changesCanceled"
          ></PropertySubmitter>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
// import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
import EditLocaleTextsSubForm from "~/v-admin-app/src/components/editor-forms/EditLocaleTextsSubForm.vue"
import PropertySubmitter from "~/v-admin-app/src/components/editor-forms-parts/PropertySubmitter.vue"
export default {
  components: {
    // TextField,
    EditLocaleTextsSubForm,
    PropertySubmitter,
  },
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      fieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = fieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
  },
  mounted: function () {},
  setup(props) {},
  data() {
    return {
      cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        lastUpdateStamp: "",
      },
      titleFieldDetails: {
        labelEn: "Title",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "title",
        fieldType: "simpleInput",
        qInputType: "string",
        constraints: {
          inputValue: {},
        },
      },
    }
  },
}
</script>
<style></style>
