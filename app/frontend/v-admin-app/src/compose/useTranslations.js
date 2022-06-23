import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getTranslations(batchName) {
    let apiUrl = `${dataApiBase}/api/v1/translations/batch/${batchName}`
    return axios.get(apiUrl, {}, {
      // headers: {
      //   "X-Requested-With": "XMLHttpRequest"
      // }
    })
  }
  function updateAgency(agency_changes) {
    let apiUrl = `${dataApiBase}/api/v1/agency`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      agency: agency_changes
    }, {
      headers: {
        // 'Content-Type': 'application/vnd.api+json',
        'X-CSRF-Token': csrfToken
      }
      // headers: authHeader()
    })
  }
  return {
    updateAgency,
    getTranslations
  }
}