<template>
  <div class="q-pa-md">
    <div class="text-h5 q-mb-md">Import Properties</div>

    <div v-if="!previewProperties.length">
      <q-card class="q-mb-md">
        <q-card-section>
          <div class="text-h6">Upload CSV</div>
        </q-card-section>
        <q-card-section>
          <q-file
            v-model="file"
            label="Select CSV File"
            filled
            accept=".csv, .txt, .tsv"
          >
            <template v-slot:prepend>
              <q-icon name="attach_file" />
            </template>
          </q-file>
        </q-card-section>
        <q-card-actions>
          <q-btn label="Preview PWB CSV" color="primary" @click="uploadFile('pwb')" :disable="!file" />
          <q-btn label="Preview MLS CSV" color="secondary" @click="uploadFile('mls')" :disable="!file" />
        </q-card-actions>
      </q-card>
    </div>

    <ImportPreview
      v-else
      :properties="previewProperties"
      @cancel="reset"
      @saved="onSaved"
    />
  </div>
</template>

<script>
import { defineComponent, ref } from 'vue'
import axios from 'axios'
import { useQuasar } from 'quasar'
import ImportPreview from '../components/import/ImportPreview.vue'

export default defineComponent({
  name: 'PropertiesImport',
  components: {
    ImportPreview
  },
  setup() {
    const $q = useQuasar()
    const file = ref(null)
    const previewProperties = ref([])

    const uploadFile = async (type) => {
      if (!file.value) return

      const formData = new FormData()
      formData.append('file', file.value)
      const csrfToken = document.head.querySelector("[name='csrf-token']").content

      const endpoint = type === 'mls' 
        ? '/import/Properties/retrieve_from_mls' 
        : '/import/Properties/retrieve_from_pwb'

      try {
        $q.loading.show()
        const response = await axios.post(endpoint, formData, {
          headers: {
            'Content-Type': 'multipart/form-data',
            'X-CSRF-Token': csrfToken
          }
        })
        previewProperties.value = response.data.retrieved_items
      } catch (error) {
        console.error(error)
        $q.notify({
          color: 'negative',
          message: 'Failed to parse file'
        })
      } finally {
        $q.loading.hide()
      }
    }

    const reset = () => {
      previewProperties.value = []
      file.value = null
    }

    const onSaved = () => {
      reset()
    }

    return {
      file,
      previewProperties,
      uploadFile,
      reset,
      onSaved
    }
  }
})
</script>
