<template>
  <div>
    <div class="q-pa-md">
      <div>Translations</div>
      <div class="row q-col-gutter-md">
        <div
          class="col-4"
          v-for="translationItem in groupedTranslations"
          :key="translationItem.sortKey"
        >
          <q-card class="translation-item-card">
            <q-card-section>
              <div>
                <TranslationInput
                  :cancelPendingChanges="cancelPendingChanges"
                  :fieldDetails="translationItem"
                  v-on:updatePendingChanges="updatePendingChanges"
                ></TranslationInput>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>
      <div class="row">
        <div class="col-12">
          <LinksSubmitter
            :cancelPendingChanges="cancelPendingChanges"
            :lastChangedField="lastChangedField"
            :currentModelForEditing="translationsBatch"
            @changesCanceled="changesCanceled"
            @runModelUpdate="runModelUpdate"
          ></LinksSubmitter>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
// import { defineComponent, ref } from "vue"
import TranslationInput from "~/v-admin-app/src/components/editor-forms-parts/TranslationInput.vue"
import LinksSubmitter from "~/v-admin-app/src/components/editor-forms-parts/LinksSubmitter.vue"
import useLinks from "~/v-admin-app/src/compose/useLinks.js"
import { filter, find } from "lodash"
import sortBy from "lodash/sortBy"
// import pluck from "lodash/pluck"
import uniq from "lodash/uniq"
export default {
  components: {
    LinksSubmitter,
    TranslationInput,
  },
  computed: {
    groupedTranslations() {
      var allAdminTranslations = this.translationsBatch // this.get("adminTranslations.translations")
      var currentLocale = "en" // this.get("i18n.locale")
      let uniqueKeys = uniq(allAdminTranslations.map((tr) => tr.i18n_key))
      // var uniqueKeys = ["extras.piscinaClimatizada", "extras.parque"]
      // var uniqueKeys = this.get("adminTranslations.translations")
      //   .getEach("i18n_key")
      //   .uniq()
      var groupedTranslations1 = []
      // var supportedLocales = this.get("locales")
      var supportedLocales = ["en", "es"]
      uniqueKeys.forEach(function (translateItemKey) {
        let translationsForKey = filter(
          allAdminTranslations,
          function (adminTranslation) {
            return adminTranslation["i18n_key"] === translateItemKey
          }
        )
        // var translationsForKey = allAdminTranslations.filterBy(
        //   "i18n_key",
        //   translateItemKey
        // )
        // supportedLocales.forEach(function (lang) {
        //   // console.log(translationsForKey);
        //   // below adds an empty new admintranslation in case a
        //   // supported lang does not have a translation on the server
        //   if (!translationsForKey.findBy("locale", lang)) {
        //     var newTranslation = AdminTranslations.create({
        //       locale: lang,
        //       i18n_value: "",
        //       i18n_key: translateItemKey,
        //     })
        //     translationsForKey.pushObject(newTranslation)
        //   }
        // })
        // for sorting:
        var sortKey = ""
        // var currentLocaleTranslation = translationsForKey.findBy(
        //   "locale",
        //   currentLocale
        // )
        let currentLocaleTranslation = find(translationsForKey, function (tr) {
          return tr["locale"] === currentLocale
        })
        if (currentLocaleTranslation) {
          sortKey = currentLocaleTranslation.i18n_value
        }
        groupedTranslations1.push({
          sortKey: sortKey,
          translationsForKey: translationsForKey,
        })
      })
      return sortBy(groupedTranslations1, "sortKey")
      // return groupedTranslations1.sortBy("sortKey")
    },
  },
  methods: {
    runModelUpdate(currPendingChanges) {
      this.updateLinks(this.translationsBatch)
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
    updatePendingChanges({ fieldDetails, newValue, navGroup }) {
      let newFieldDetails = {
        fieldName: fieldDetails.slug,
        navGroup: navGroup,
      }
      newFieldDetails.newValue = newValue
      this.lastChangedField.fieldDetails = newFieldDetails
      // this.lastChangedField.lastUpdateStamp = Date.now()
      this.cancelPendingChanges = false
    },
    changesCanceled() {
      this.$emit("changesCanceled")
      this.cancelPendingChanges = true
    },
  },
  props: {
    translationsBatch: {
      type: Object,
      default: () => {},
    },
  },
  mounted: function () {},
  setup(props) {
    const { getLinks, updateLinks } = useLinks()
    return {
      getLinks,
      updateLinks,
    }
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
}
</script>
<style></style>
