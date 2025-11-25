<template>
  <div>
    <q-card v-if="properties.length > 0">
      <q-card-section>
        <div class="text-h6">Import Preview</div>
        <div class="text-subtitle2">{{ properties.length }} properties found</div>
      </q-card-section>

      <q-card-section>
        <q-table
          :rows="properties"
          :columns="columns"
          row-key="reference"
          :pagination="{ rowsPerPage: 10 }"
        />
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" color="negative" @click="$emit('cancel')" />
        <q-btn label="Confirm Import" color="primary" @click="confirmImport" :loading="saving" />
      </q-card-actions>
    </q-card>
  </div>
</template>

<script>
import { defineComponent, ref, computed } from 'vue'
import axios from 'axios'
import { useQuasar } from 'quasar'

export default defineComponent({
  name: 'ImportPreview',
  props: {
    properties: {
      type: Array,
      required: true
    }
  },
  emits: ['cancel', 'saved'],
  setup(props, { emit }) {
    const $q = useQuasar()
    const saving = ref(false)

    const columns = computed(() => {
      if (props.properties.length === 0) return []
      // Dynamically generate columns from the first property keys
      // Filtering out complex objects or long text if needed
      const firstProp = props.properties[0]
      return Object.keys(firstProp).map(key => ({
        name: key,
        label: key.charAt(0).toUpperCase() + key.slice(1).replace(/_/g, ' '),
        field: key,
        sortable: true,
        align: 'left'
      })).slice(0, 6) // Limit to first 6 columns for preview
    })

    const confirmImport = async () => {
      saving.value = true
      try {
        const csrfToken = document.head.querySelector("[name='csrf-token']").content
        const response = await axios.post('/import/Properties/save', {
          properties: props.properties
        }, {
          headers: {
            'X-CSRF-Token': csrfToken
          }
        })
        
        $q.notify({
          color: 'positive',
          message: `Successfully imported ${response.data.saved_count} properties`
        })
        emit('saved')
      } catch (error) {
        console.error(error)
        $q.notify({
          color: 'negative',
          message: 'Failed to save properties'
        })
      } finally {
        saving.value = false
      }
    }

    return {
      columns,
      confirmImport,
      saving
    }
  }
})
</script>
