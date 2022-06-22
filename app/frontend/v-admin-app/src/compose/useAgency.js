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
  return {
    getAgency
  }
}