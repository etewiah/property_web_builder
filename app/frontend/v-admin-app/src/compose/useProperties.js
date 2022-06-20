import axios from "axios"
// import authHeader from "src/services/auth/auth-header"
// import { Cookies, useQuasar } from "quasar"
// // const cookies = Cookies

export default function () {
  let dataApiBase = ""
  function updateProperty(comparisonUuid, updateParams) {
    let apiUrl = `${dataApiBase}/api/v1/property_sale_comparisons/${comparisonUuid}`
    return axios.put(apiUrl, updateParams, {
      // headers: authHeader()
    })
  }

  function getProperties() {
    let apiUrl = `${dataApiBase}/api/v1/lite-properties`
    return axios.get(apiUrl, {}, {})
  }
  function getProperty(comparisonUuid) {
    let apiUrl = `${dataApiBase}/api/v1/property_sale_comparisons/${comparisonUuid}`
    return axios.get(apiUrl, {}, {})
  }
  function getOrCreateProperty(leftListingUuid, rightListingUuid) {
    let apiUrl = `${dataApiBase}/api/v1/property_sale_comparisons`
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