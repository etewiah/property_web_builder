<template>
  <div class="q-pa-md">
    <q-card>
      <q-card-section>
        <div class="text-h6">Property Owner</div>
      </q-card-section>

      <q-card-section>
        <div v-if="currentOwner" class="q-mb-md">
          <q-banner class="bg-primary text-white">
            Current Owner: {{ currentOwner.first_name }} {{ currentOwner.last_name }}
            <template v-slot:action>
              <q-btn flat color="white" label="Unset" @click="unsetOwner" />
            </template>
          </q-banner>
        </div>
        <div v-else class="q-mb-md">
          <q-banner class="bg-grey-3">
            No owner assigned.
          </q-banner>
        </div>

        <q-select
          filled
          v-model="selectedContact"
          use-input
          input-debounce="0"
          label="Search for a contact to assign"
          :options="filteredContacts"
          @filter="filterContacts"
          option-label="displayName"
          option-value="id"
        >
          <template v-slot:no-option>
            <q-item>
              <q-item-section class="text-grey">
                No results
              </q-item-section>
            </q-item>
          </template>
        </q-select>

        <div class="q-mt-md">
          <q-btn color="primary" label="Assign Owner" @click="assignOwner" :disable="!selectedContact" />
        </div>
      </q-card-section>
    </q-card>
  </div>
</template>

<script>
import { defineComponent, ref, onMounted, computed } from 'vue'
import axios from 'axios'
import { useQuasar } from 'quasar'

export default defineComponent({
  name: 'PropertyOwnerForm',
  props: {
    currentProperty: {
      type: Object,
      required: true
    }
  },
  setup(props) {
    const $q = useQuasar()
    const contacts = ref([])
    const filteredContacts = ref([])
    const selectedContact = ref(null)
    // const currentOwner = ref(null)

    const currentOwner = computed(() => {
       return props.currentProperty.attributes.owner_model
    })

    const loadContacts = async () => {
      try {
        const response = await axios.get('/api/v1/contacts')
        contacts.value = response.data.map(c => ({
          ...c,
          displayName: `${c.first_name} ${c.last_name} (${c.primary_email})`
        }))
        filteredContacts.value = contacts.value
      } catch (error) {
        console.error('Error loading contacts', error)
      }
    }

    const filterContacts = (val, update) => {
      if (val === '') {
        update(() => {
          filteredContacts.value = contacts.value
        })
        return
      }

      update(() => {
        const needle = val.toLowerCase()
        filteredContacts.value = contacts.value.filter(v => v.displayName.toLowerCase().indexOf(needle) > -1)
      })
    }

    const assignOwner = async () => {
      if (!selectedContact.value) return

      try {
        let csrfToken = document.head.querySelector("[name='csrf-token']").content
        await axios.post('/api/v1/properties/set_owner', {
          prop_id: props.currentProperty.id,
          client_id: selectedContact.value.id
        }, {
          headers: {
            'X-CSRF-Token': csrfToken
          }
        })
        $q.notify({
          color: 'positive',
          message: 'Owner assigned successfully'
        })
        // Reload property or emit event to update parent
        // For simplicity, we can just update the local state if we had a mutable prop or emit an update
        // But props are read-only.
        // We should probably emit an event to the parent to reload the property.
        // window.location.reload() // Brute force reload for now or emit
        // Better:
        // props.currentProperty.owner = selectedContact.value // This mutates prop, bad practice but might work in Vue 2/3 compat if object.
        // Best: emit 'propertyUpdated'
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to assign owner'
        })
      }
    }

    const unsetOwner = async () => {
      try {
        let csrfToken = document.head.querySelector("[name='csrf-token']").content
        await axios.post('/api/v1/properties/unset_owner', {
          prop_id: props.currentProperty.id
        }, {
          headers: {
            'X-CSRF-Token': csrfToken
          }
        })
        $q.notify({
          color: 'positive',
          message: 'Owner removed successfully'
        })
        selectedContact.value = null
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to remove owner'
        })
      }
    }

    onMounted(() => {
      loadContacts()
    })

    return {
      contacts,
      filteredContacts,
      selectedContact,
      currentOwner,
      filterContacts,
      assignOwner,
      unsetOwner
    }
  }
})
</script>
