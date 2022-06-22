import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getLinks() {
    let apiUrl = `${dataApiBase}/api/v1/links`
    return axios.get(apiUrl, {}, {
      // headers: {
      //   "X-Requested-With": "XMLHttpRequest"
      // }
    })
  }
  function updateLinks(link_changes) {
    let apiUrl = `${dataApiBase}/api/v1/links`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      linkGroups: link_changes
    }, {
      headers: {
        // 'Content-Type': 'application/vnd.api+json',
        'X-CSRF-Token': csrfToken
      }
      // headers: authHeader()
    })
  }

  return {
    getLinks,
    updateLinks
  }
}