import axios from "axios"

export default function () {
  let dataApiBase = ""
  function createContentWithPhoto(tag, file) {
    let apiUrl = `${dataApiBase}/api/v1/web_contents/create_content_with_photo`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    let formData = new FormData()
    formData.append('file', file)
    formData.append('tag', tag)

    return axios.post(apiUrl, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
        'X-CSRF-Token': csrfToken
      }
    })
  }
  
  function deleteContent(contentId) {
    // Note: Standard JSONAPI delete usually requires ID. 
    // Checking routes, resources usually map to /api/v1/web_contents/:id
    let apiUrl = `${dataApiBase}/api/v1/web_contents/${contentId}`
    let csrfToken = document.head.querySelector("[name='csrf-token']").content
    return axios.delete(apiUrl, {
      headers: {
        'X-CSRF-Token': csrfToken
      }
    })
  }

  function getContents(tag) {
    // Assuming we can filter by tag or just get all and filter client side if needed
    // But usually we might need a specific endpoint or filter param
    // For now, let's assume we can fetch by tag if supported, or just get all
    // Checking web_contents_controller, it inherits from JSONAPI::ResourceController
    // So it should support filtering if configured.
    // Let's try basic index.
    let apiUrl = `${dataApiBase}/api/v1/web_contents`
    return axios.get(apiUrl, {
      params: {
        'filter[tag]': tag
      }
    })
  }

  return {
    createContentWithPhoto,
    deleteContent,
    getContents
  }
}
