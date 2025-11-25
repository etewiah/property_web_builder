import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getPage(pageName) {
    let apiUrl = `${dataApiBase}/api/v1/page/${pageName}`
    return axios.get(apiUrl, {}, {
    })
  }
  function updatePage(page_changes) {
    let apiUrl = `${dataApiBase}/api/v1/page`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      page: page_changes
    }, {
      headers: {
        'X-CSRF-Token': csrfToken
      }
    })
  }
  return {
    updatePage,
    getPage
  }
}
