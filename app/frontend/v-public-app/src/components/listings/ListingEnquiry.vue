<template>
  <q-card class="listing-enq-card full-height">
    <q-card-section>
      <div>
        <h4
          class="sm:text-2xl font-medium title-font text-gray-900 q-pb-md text-center"
        >
          Find out more about this listing:
        </h4>
      </div>
      <q-form @submit="onSubmitEnquiry" @reset="onReset" class="q-gutter-md">
        <template
          v-for="field in propertyEnquiryShortFields"
          :key="field.fieldName"
        >
          <div class="listing-enq-field">
            <q-input
              class="listing-enq-field-input"
              outlined
              v-model="enquiryContent.contact[field.fieldName]"
              :label="localiseProvider.$ft(field.labelTextTKey)"
              :hint="localiseProvider.$ft(field.hintTextTKey)"
              lazy-rules
              :rules="field.validationRules"
            />
          </div>
        </template>
        <!-- <q-toggle v-model="acceptTerms">
              <a v-on:click.stop class="" :href="tAndCLink">
                <span>
                  {{
                    localiseProvider.$ft("standard.forms.tAndCAcceptancePrefix")
                  }}
                </span>
                <span class="acceptance-link color-primary">
                  {{
                    localiseProvider.$ft(
                      "standard.forms.tAndCAcceptanceLinkText"
                    )
                  }}
                </span> </a
              >.
            </q-toggle> -->
        <div>
          <q-btn label="Submit" type="submit" color="primary" />
        </div>
        <div class="listing-form-results">
          <div class="w-full flex flex-col flex-grow flex-shrink pl-4">
            <div class="h-full ma-0 pa-0 v-card v-sheet theme--light">
              <div style="color: red">
                <div v-if="propertyEnquiryErrors.length">
                  <div>Sorry, there has been an error.</div>
                  <template v-for="error in propertyEnquiryErrors" :key="error">
                    <div>
                      {{ error }}
                    </div>
                  </template>
                </div>
              </div>
            </div>
          </div>
        </div>
      </q-form>
    </q-card-section>
  </q-card>
</template>
<script>
import { useMutation } from "@urql/vue"
import { ref } from "vue"
export default {
  inject: ["localiseProvider"],
  setup() {
    const acceptTerms = ref(false)
    const submitEnquiryResult = useMutation(`
      mutation ($propertyId: String!, $contact: JSON!) {
        submitListingEnquiry (
          input: { propertyId: $propertyId, contact: $contact }
        )
      }
    `)
    return {
      submitEnquiryResult,
      acceptTerms,
      onReset() {
        acceptTerms.value = false
      },
    }
  },
  methods: {
    onSubmitEnquiry() {
      let propertyId = this.currentListing.id
      let contact = this.enquiryContent.contact
      propertyId = propertyId.toString() || ""
      const variables = { propertyId, contact: contact || contact }
      this.submitEnquiryResult.executeMutation(variables).then((result) => {
        // console.log(result)
        if (result.error && result.error.message) {
          this.propertyEnquiryErrors.push(result.error.message)
        } else {
          this.$q.notify({
            color: "green-4",
            textColor: "white",
            icon: "cloud_done",
            message: "Submitted",
          })
        }
        // The result is almost identical to `submitEnquiryResult` with the exception
        // of `result.fetching` not being set and its properties not being reactive.
        // It is an OperationResult.
      })
    },
  },
  props: {
    currentListing: {
      type: Object,
      default: () => {},
    },
  },
  data() {
    return {
      // acceptTerms: false,
      // ask_types: ["Ask for more information", "Ask for a visit", "Ask to be called back",
      //   "Ask for more photos"
      // ],
      // promptTandC: false,
      // tandcAccepted: true,
      propertyEnquiryErrors: [],
      formValid: false,
      propertyEnquiryShortFields: [
        {
          labelTextTKey: "standard.forms.nameLabel",
          hintTextTKey: "standard.forms.nameHint",
          fieldName: "name",
          inputType: "text",
          validationRules: [(v) => !!v || "Name is required"],
        },
        {
          labelTextTKey: "standard.forms.emailLabel",
          hintTextTKey: "standard.forms.emailHint",
          fieldName: "email",
          inputType: "text",
          required: true,
          validationRules: [
            (v) => !!v || "E-mail is required",
            (v) =>
              /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/.test(v) ||
              "E-mail must be valid",
          ],
        },
        {
          labelTextTKey: "standard.forms.telLabel",
          hintTextTKey: "standard.forms.telHint",
          fieldName: "tel",
          inputType: "text",
          validationRules: [],
        },
      ],
      enquiryContent: {
        contact: {
          pref_lang: "",
          ask_type: "",
          name: "",
          // message: "Hi, I'm interested in your property and I want more information about it. Thanks.."
        },
      },
    }
  },
  computed: {
    // tAndCLink() {
    //   let tAndCLink = ""
    //   return tAndCLink
    // },
  },
  watch: {
    // tandcAccepted(newValue, oldValue) {
    //   if (newValue === true) {
    //     this.promptTandC = false
    //   }
    // },
  },
}
</script>
<style></style>
