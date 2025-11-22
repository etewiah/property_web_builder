import axios from "axios"
import { ref } from "vue"

export default function () {
  const propertyTypes = ref([])
  const loading = ref(false)
  const error = ref(null)

  const fetchPropertyTypes = async () => {
    loading.value = true
    error.value = null
    try {
      const response = await axios.get('/api_public/v1/select_values', {
        params: { field_names: 'property-types' }
      })
      
      // Convert from API format {value, label} to options format
      if (response.data && response.data['property-types']) {
        propertyTypes.value = response.data['property-types'].map(item => ({
          value: item.value,
          label: item.label
        }))
      }
    } catch (err) {
      error.value = err
      console.error("Error fetching property types:", err)
    } finally {
      loading.value = false
    }
  }

  // Fetch immediately
  fetchPropertyTypes()

  return {
    propertyTypes,
    loading,
    error,
    fetchPropertyTypes
  }
}
