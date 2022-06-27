import axios from "axios"

export default function () {
  let dataApiBase = ""
  function getAgency() {
    let apiUrl = `${dataApiBase}/api/v1/agency`
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
  function updateAgencyAddress(address_changes) {
    let apiUrl = `${dataApiBase}/api/v1/master_address`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      address: address_changes
    }, {
      headers: {
        // 'Content-Type': 'application/vnd.api+json',
        'X-CSRF-Token': csrfToken
      }
      // headers: authHeader()
    })
  }
  return {
    updateAgencyAddress,
    updateAgency,
    getAgency
  }
}