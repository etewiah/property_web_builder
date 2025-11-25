import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getWebsite() {
    let apiUrl = `${dataApiBase}/api/v1/website`
    return axios.get(apiUrl, {}, {
    })
  }
  function updateWebsite(website_changes) {
    let apiUrl = `${dataApiBase}/api/v1/website`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      website: website_changes
    }, {
      headers: {
        'X-CSRF-Token': csrfToken
      }
    })
  }
  return {
    updateWebsite,
    getWebsite
  }
}
