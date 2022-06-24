import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getPage(pageName) {
    let apiUrl = `${dataApiBase}/api/v1/pages/${pageName}`
    return axios.get(apiUrl, {}, {
      // headers: {
      //   "X-Requested-With": "XMLHttpRequest"
      // }
    })
  }
  function updateTranslations(translation_changes) {
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    Object.keys(translation_changes).forEach(change_locale => {
      let tc = translation_changes[change_locale]
      let apiUrl = `${dataApiBase}/api/v1/translations/${tc.id}/update_for_locale`
      let translation_change = {
        i18n_value: tc.newValue,
        id: tc.id
        // batch_key: tc.batch_key
      }
      axios.put(apiUrl, translation_change, {
        headers: {
          // 'Content-Type': 'application/vnd.api+json',
          'X-CSRF-Token': csrfToken
        }
      })
    })
  }
  return {
    updateTranslations,
    getPage
  }
}