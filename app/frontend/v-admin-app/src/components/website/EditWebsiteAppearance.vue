<template>
  <div>
    <div class="q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6">Theme</div>
            </q-card-section>
            <q-card-section>
              <q-select
                filled
                v-model="currentWebsite.theme_name"
                :options="themeOptions"
                label="Select Theme"
                emit-value
                map-options
              />
            </q-card-section>
          </q-card>

          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6">Colors</div>
            </q-card-section>
            <q-card-section>
              <div v-if="currentWebsite.style_variables">
                <q-input
                  filled
                  v-model="currentWebsite.style_variables.primary_color"
                  label="Primary Color"
                  class="q-mb-md"
                >
                  <template v-slot:append>
                    <q-icon name="colorize" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="currentWebsite.style_variables.primary_color" />
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
                <q-input
                  filled
                  v-model="currentWebsite.style_variables.secondary_color"
                  label="Secondary Color"
                  class="q-mb-md"
                >
                  <template v-slot:append>
                    <q-icon name="colorize" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="currentWebsite.style_variables.secondary_color" />
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
                 <q-input
                  filled
                  v-model="currentWebsite.style_variables.action_color"
                  label="Action Color"
                  class="q-mb-md"
                >
                  <template v-slot:append>
                    <q-icon name="colorize" class="cursor-pointer">
                      <q-popup-proxy cover transition-show="scale" transition-hide="scale">
                        <q-color v-model="currentWebsite.style_variables.action_color" />
                      </q-popup-proxy>
                    </q-icon>
                  </template>
                </q-input>
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-md-6">
          <q-card class="q-mb-md">
            <q-card-section>
              <div class="text-h6">Custom CSS</div>
            </q-card-section>
            <q-card-section>
              <q-input
                v-model="currentWebsite.raw_css"
                filled
                type="textarea"
                label="Raw CSS"
                rows="15"
              />
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="row">
        <div class="col-12">
          <q-btn color="primary" label="Save Changes" @click="saveChanges" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { defineComponent, ref, onMounted } from 'vue'
import axios from 'axios'
import { useQuasar } from 'quasar'
import useWebsite from "~/v-admin-app/src/compose/useWebsite.js"

export default defineComponent({
  name: 'EditWebsiteAppearance',
  props: {
    currentWebsite: {
      type: Object,
      required: true
    }
  },
  setup(props) {
    const $q = useQuasar()
    const themeOptions = ref([])
    const { updateWebsite } = useWebsite()

    const loadThemes = async () => {
      try {
        const response = await axios.get('/api/v1/themes')
        themeOptions.value = response.data.map(t => ({
          label: t.friendly_name || t.name,
          value: t.name
        }))
      } catch (error) {
        console.error('Error loading themes', error)
      }
    }

    const saveChanges = async () => {
      try {
        await updateWebsite(props.currentWebsite)
        $q.notify({
          color: 'positive',
          message: 'Appearance settings updated successfully'
        })
      } catch (error) {
        $q.notify({
          color: 'negative',
          message: 'Failed to update settings'
        })
      }
    }

    onMounted(() => {
      loadThemes()
    })

    return {
      themeOptions,
      saveChanges
    }
  }
})
</script>
