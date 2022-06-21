import axios from "axios"
// import authHeader from "src/services/auth/auth-header"
// import { Cookies, useQuasar } from "quasar"
// // const cookies = Cookies

export default function () {
  let dataApiBase = ""
  function updateProperty(propertyModel, changes) {
    let apiUrl =
      `${dataApiBase}/api/v1/properties/${propertyModel.id}`
    return axios.put(apiUrl, {
      data: {
        attributes: changes,
        // attributes: {
        //   "count-bathrooms": propertyModel.attributes["count-bathrooms"]
        // },
        type: propertyModel.type,
        id: propertyModel.id
      }
    }, {
      headers: {
        'Content-Type': 'application/vnd.api+json'
      }
      // headers: authHeader()
    })
  }

  function getProperties() {
    let apiUrl = `${dataApiBase}/api/v1/lite-properties`
    return axios.get(apiUrl, {}, {})
  }
  function getProperty(propertyId) {
    let apiUrl = `${dataApiBase}/api/v1/properties/${propertyId}`
    return axios.get(apiUrl, {}, {})
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
    getProperty
  }
}