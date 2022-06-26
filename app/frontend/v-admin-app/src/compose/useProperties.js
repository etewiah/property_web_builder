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

  function deletePropertyPhoto(photoModel) {
    let apiUrl =
      `${dataApiBase}/api/v1/properties/photos/${photoModel.id}/${photoModel.prop_id}`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.delete(apiUrl, {
      headers: {
        'X-CSRF-Token': csrfToken
      }
    })
  }

  function getProperties() {
    let apiUrl = `${dataApiBase}/api/v1/lite-properties`
    return axios.get(apiUrl, {}, {})
  }
  function getProperty(propertyId) {
    let apiUrl = `${dataApiBase}/api/v1/properties/${propertyId}`
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
    deletePropertyPhoto,
    updateProperty,
    getProperties,
    getOrCreateProperty,
    getProperty
  }
}