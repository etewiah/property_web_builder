// https://markus.oberlehner.net/blog/vue-composition-api-composables/
import { reactive, computed, readonly } from "vue";
// import { useStore } from "vuex"
// import axios from "axios"
// import authHeader from "src/services/auth/auth-header"

const state = reactive({
  currentWebsite: {},
  adminTranslations: {}
})

// const next = computed(() => count.value + 1);
const supportedLocaleDetails = computed(() => {
  let supportedLocales = state.currentWebsite.supported_locales || []
  let supportedLocaleDetails = {
    full: {},
    localesOnly: []
  }
  supportedLocales.forEach((localeWithVariant) => {
    let localeOnly = localeWithVariant.split("-")[0]
    supportedLocaleDetails.full[localeOnly] = {
      localeOnly: localeOnly,
      localeWithVariant: localeWithVariant,
      label: state.adminTranslations[localeOnly],
    }
    supportedLocaleDetails.localesOnly.push(localeOnly)
  })
  return supportedLocaleDetails
})


function setCurrentWebsite(currentWebsite) {
  state.currentWebsite = currentWebsite
}
function setAdminTranslations(adminTranslations) {
  state.adminTranslations = adminTranslations
}


export const websiteProvider = readonly({
  supportedLocaleDetails,
  state,
  setCurrentWebsite,
  setAdminTranslations
})