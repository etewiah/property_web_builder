<template>
  <div class="q-pa-md">
    <div class="row edit-attr-row">
      <div class="col-12 q-py-lg">
        <q-item
          class="q-mr-lg q-mb-sm border-gray-800 bg-gray-200 border-2 float-left"
        >
          <!-- <q-item-section side>
            <q-icon color="blue" name="hotel" />
          </q-item-section> -->
          <q-item-section class="q-mr-sm">
            <q-item-label class="text-weight-medium text-h6"> </q-item-label>
            <TextField
              :cancelPendingChanges="cancelPendingChanges"
              :fieldDetails="bedroomsFieldDetails"
              :currentFieldValue="bedroomsContentValue"
              v-on:updatePendingChanges="updatePendingChanges"
            ></TextField>
          </q-item-section>
        </q-item>
      </div>
      <div class="col-12"></div>
    </div>
  </div>
</template>
<script>
import { defineComponent, ref } from "vue"
import TextField from "~/v-admin-app/src/components/editor-forms-parts/TextField.vue"
// import { mdiAspectRatio, mdiCashMultiple } from "@quasar/extras/mdi-v5"
export default defineComponent({
  created() {},
  name: "AgencyGeneralForm",
  components: {
    TextField,
  },
  props: {
    cancelPendingChanges: {
      type: Boolean,
      default: false,
    },
    currentAgency: {
      type: Object,
      default: () => {},
    },
  },
  computed: {
    bedroomsContentValue() {
      let bedroomsContentValue = this.currentAgency["company_name"]
      return bedroomsContentValue
    },
  },
  methods: {
    updatePendingChanges({ fieldDetails, newValue }) {
      this.$emit("updatePendingChanges", {
        fieldDetails: fieldDetails,
        newValue: newValue,
      })
    },
  },
  data() {
    return {
      bedroomsFieldDetails: {
        labelEn: "Company Name",
        tooltipTextTKey: "",
        autofocus: false,
        fieldName: "company_name",
        fieldType: "simpleInput",
        qInputType: "text",
        constraints: {
          inputValue: {},
        },
      },
      // cancelPendingChanges: false,
      lastChangedField: {
        fieldDetails: {},
        lastUpdateStamp: "",
      },
    }
  },
})
</script>
<style>
/* .edit-attr-row .q-field__native {
  font-size: larger;
} */
</style>
