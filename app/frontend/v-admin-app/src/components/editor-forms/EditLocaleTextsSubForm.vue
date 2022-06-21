<template>
  <div class="row edit-locale-texts-row">
    <div class="col-12 q-py-lg q-pr-md">
      <div>
        <TextField
          :cancelPendingChanges="cancelPendingChanges"
          :fieldDetails="localeTitleFieldDetails"
          :currentFieldValue="titleContentValue"
          v-on:updatePendingChanges="updatePendingChanges"
        ></TextField>
      </div>
      <div>
        <TextField
          :cancelPendingChanges="cancelPendingChanges"
          :fieldDetails="localeDescFieldDetails"
          :currentFieldValue="descContentValue"
          v-on:updatePendingChanges="updatePendingChanges"
        ></TextField>
      </div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
export default defineComponent({
  name: "EditLocaleTextsSubForm",
  components: {
    TextField,
  },
  props: {
    currentProperty: {
      type: Object,
      default: () => {},
    },
    cancelPendingChanges: {
      type: Boolean,
      default: false,
    },
    contentLocale: {
      type: String,
      default: "en",
    },
  },
  computed: {
    fullLocaleName() {
      if (this.contentLocale === "es") {
        return "Spanish"
      } else {
        return "English"
      }
    },
    localeTitleFieldDetails() {
      this.titleFieldDetails.labelEn = `Title (${this.fullLocaleName})`
      this.titleFieldDetails.fieldName = `title-${this.contentLocale}`
      return this.titleFieldDetails
    },
    titleContentValue() {
      let titleContentValue =
        this.currentProperty.attributes[`title-${this.contentLocale}`]
      return titleContentValue
    },
    localeDescFieldDetails() {
      this.descFieldDetails.labelEn = `Description (${this.fullLocaleName})`
      this.descFieldDetails.fieldName = `description-${this.contentLocale}`
      return this.descFieldDetails
    },
    descContentValue() {
      let descContentValue =
        this.currentProperty.attributes[`description-${this.contentLocale}`]
      return descContentValue
    },
  },
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      this.$emit("updatePendingChanges", {
        fieldDetails: fieldDetails,
        newValue: newValue,
      })
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  data() {
    return {
      descFieldDetails: {
        labelEn: "Description",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "description",
        fieldType: "simpleInput",
        qInputType: "string",
        constraints: {
          inputValue: {},
        },
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
      // cancelPendingChanges: false,
      // lastChangedField: {
      //   fieldDetails: {},
      //   lastUpdateStamp: "",
      // },
    }
  },
})
</script>
<style>
/* .edit-attr-row .q-field__native {
  font-size: larger;
} */
</style>
