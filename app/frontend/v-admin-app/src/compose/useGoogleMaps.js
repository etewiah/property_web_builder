import lodashEach from "lodash/each"

export default function () {
  // function gPlaceFromLocation(gLocation) {
  //   var geocoder = new google.maps.Geocoder()
  //   // var that = this
  //   let gPlace = {}
  //   geocoder.geocode(
  //     {
  //       latLng: gLocation.latLng,
  //     },
  //     function (results, status) {
  //       if (status === google.maps.GeocoderStatus.OK) {
  //         if (results[0]) {
  //           gPlace = results[0]
  //           // let newAddressDetails = that.getAddressFromPlaceDetails(
  //           //   results[0]
  //           // )
  //           // that.$emit("updatePropAddress", newAddressDetails)
  //         } else {
  //           // alert("No results found");
  //         }
  //       } else {
  //         // alert("Geocoder failed due to: " + status);
  //       }
  //     }
  //   )
  //   return gPlace
  // }
  function getAddressFromPlaceDetails(gPlaceDetails) {
    let newAddressFromMap = {}
    if (gPlaceDetails.geometry) {
      newAddressFromMap["street_address"] = gPlaceDetails.formatted_address
      // this.agencyAddress.google_place_id = gPlaceDetails.place_id
      // this.agencyAddress.latitude = gPlaceDetails.geometry.location.lat()
      // this.agencyAddress.longitude = gPlaceDetails.geometry.location.lng()
      newAddressFromMap.google_place_id = gPlaceDetails.place_id
      newAddressFromMap.latitude = gPlaceDetails.geometry.location.lat()
      newAddressFromMap.longitude = gPlaceDetails.geometry.location.lng()
      lodashEach(
        gPlaceDetails.address_components,
        function (address_component, i) {
          // iterate through address_component array
          console.log("address_component:" + i)
          console.log(newAddressFromMap)
          if (address_component.types[0] === "route") {
            // console.log(i + ": route:" + address_component.long_name)
            newAddressFromMap.street_name = address_component.long_name
          }
          if (address_component.types[0] === "locality") {
            // console.log("town:" + address_component.long_name)
            newAddressFromMap.city = address_component.long_name
          }
          if (address_component.types[0] === "country") {
            // console.log("country:" + address_component.long_name)
            newAddressFromMap.country = address_component.long_name
          }
          if (address_component.types[0] === "postal_code_prefix") {
            // console.log("pc:" + address_component.long_name)
            // newAddress.postalCode = address_component.long_name
          }
          if (address_component.types[0] === "postal_code") {
            // console.log("pc:" + address_component.long_name)
            newAddressFromMap["postal_code"] = address_component.long_name
          }
          if (address_component.types[0] === "street_number") {
            // console.log("street_number:" + address_component.long_name)
            newAddressFromMap["street_number"] = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_1") {
            // eg: andalucia
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.province = address_component.long_name
            newAddressFromMap.region = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_2") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal2 = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_3") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal3 = address_component.long_name
          }
          if (address_component.types[0] === "administrative_area_level_4") {
            console.log(
              "administrative_area_level_1:" + address_component.long_name
            )
            // newAddress.aal4 = address_component.long_name
          }
          //return false // break the loop
        }
      )
    }
    return newAddressFromMap
  }

  return {
    // gPlaceFromLocation,
    getAddressFromPlaceDetails,
  }
}