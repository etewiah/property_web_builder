import axios from "axios"
// import authHeader from "src/services/auth/auth-header"
// import { Cookies, useQuasar } from "quasar"
// // const cookies = Cookies

export default function () {
  let dataApiBase = ""
  function updateProperty(propertyModel, changes) {
    let apiUrl =
      `${dataApiBase}/api/v1/properties/${propertyModel.id}`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.put(apiUrl, {
      data: {
        attributes: changes,
        type: propertyModel.type,
        id: propertyModel.id
      }
    }, {
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'X-CSRF-Token': csrfToken
      }
      // headers: authHeader()
    })
  }

  function getProperties() {
    let apiUrl = `${dataApiBase}/api/v1/lite-properties`
    return axios.get(apiUrl, {}, {})
  }
  function getAgency() {
    let apiUrl = `${dataApiBase}/api/v1/agency`
    return axios.get(apiUrl, {}, {
      // headers: {
      //   "X-Requested-With": "XMLHttpRequest"
      // }
    })
  }
  function getOrCreateProperty(leftListingUuid, rightListingUuid) {
    let apiUrl = `${dataApiBase}/api/v1/properties`
    return axios.put(apiUrl, {
      top_listing_uuid: leftListingUuid,
      bottom_listing_uuid: rightListingUuid
    }, {
      // headers: authHeader()
    })
  }
  return {
    updateProperty,
    getProperties,
    getOrCreateProperty,
    getAgency
  }
}